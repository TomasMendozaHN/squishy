@file:OptIn(UnstableApi::class)

package com.squishy.nas

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode
import com.squishy.CompressionService
import com.squishy.JobManager
import com.squishy.MediaTools
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Compresses every video below a NAS folder, one file at a time, in place:
 * the new file replaces the original under the exact same name.
 *
 * Per file: probe → hardware-encode the video track (Media3, reading through
 * [SmbHttpBridge]) → FFmpeg stream-copies every other track from the original
 * → verify → upload as a hidden temp → delete original → rename temp.
 * Run state is saved after every step so a killed process resumes.
 */
object NasRunner {
    private val VIDEO_EXT = setOf("mkv", "mp4", "m4v", "mov")
    private val SKIP_EXT = setOf("avi", "wmv", "ts", "m2ts", "webm", "flv", "mpg", "mpeg", "vob", "iso")

    /** Files a NAS run looks at (the rest are ignored). */
    fun isCandidate(name: String) = name.substringAfterLast('.', "").lowercase().let { it in VIDEO_EXT || it in SKIP_EXT }

    private lateinit var appContext: Context
    private lateinit var stateFile: File
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { Thread(it, "squishy-nas") }
    private var wifiLock: WifiManager.WifiLock? = null

    @Volatile private var run: JSONObject? = null
    @Volatile private var working = false
    @Volatile private var cancelled = false

    // Live status (read by the UI and the notification).
    @Volatile var phase = ""
    @Volatile var currentName = ""
    @Volatile private var fileProgress = 0.0
    @Volatile private var lastError: String? = null

    /** The active video encode; polled for progress on the main thread. */
    @Volatile var transformer: Transformer? = null
    private val holder = ProgressHolder()
    @Volatile private var encodeWeight = 0.0

    val encoding get() = transformer != null
    val active get() = run?.optString("status") in setOf("scanning", "running")

    fun init(context: Context) {
        if (::appContext.isInitialized) return
        appContext = context.applicationContext
        stateFile = File(appContext.filesDir, "nas_run.json")
        run = stateFile.takeIf { it.exists() }?.let { runCatching { JSONObject(it.readText()) }.getOrNull() }
    }

    private fun save() { run?.let { stateFile.writeText(it.toString()) } }

    private fun changed() = main.post { JobManager.changed() }

    // ---- control -------------------------------------------------------------------

    /**
     * Starts a run over [root] (and all subfolders), or over exactly [files]
     * (path → size) when the user picked them from the scan list.
     */
    fun start(serverId: String, root: String, qualities: Map<String, Int>, mime: String, files: List<Pair<String, Long>>? = null): String? {
        if (active) return "A NAS run is already in progress"
        val nas = NasStore.get(appContext, serverId) ?: return "Unknown server"
        run = JSONObject().apply {
            put("serverId", serverId); put("serverName", nas.name); put("root", root.trim('/'))
            put("mime", mime); put("qualities", JSONObject(qualities as Map<*, *>))
            if (files == null) {
                put("status", "scanning"); put("files", JSONArray())
            } else {
                put("status", "running"); put("found", files.size)
                put("files", JSONArray().apply { files.forEach { (p, s) -> put(JSONObject().put("p", p).put("s", s)) } })
            }
            put("index", 0)
            put("done", 0); put("failed", 0); put("skipped", 0); put("saved", 0L)
            put("startedAt", System.currentTimeMillis())
        }
        cancelled = false
        lastError = null
        save()
        changed()
        return null
    }

    fun cancel() {
        cancelled = true
        main.post { transformer?.cancel() }
        FFmpegKit.cancel()
        run?.put("status", "cancelled")
        save()
        changed()
    }

    /** Continues a cancelled/interrupted run from the file it stopped at. */
    fun resume(): Boolean {
        val r = run ?: return false
        if (active) return true
        val hasFiles = (r.optJSONArray("files")?.length() ?: 0) > 0
        r.put("status", if (hasFiles) "running" else "scanning").remove("error")
        cancelled = false
        save()
        changed()
        return true
    }

    fun clear() {
        if (active) return
        run = null
        stateFile.delete()
        changed()
    }

    /** Called by [CompressionService.pump]; starts the worker if there is work. */
    fun kick() {
        if (!active || working) return
        working = true
        cancelled = false
        acquireWifi()
        worker.execute {
            try {
                loop()
            } catch (t: Throwable) {
                lastError = t.message ?: t.javaClass.simpleName
                run?.put("status", "failed")
                run?.put("error", lastError)
                save()
            } finally {
                working = false
                transformer = null
                phase = ""
                releaseWifi()
                changed()
                main.post { CompressionService.instance?.pump() }
            }
        }
    }

    // ---- the loop ------------------------------------------------------------------

    private fun loop() {
        val r = run ?: return
        val nas = NasStore.get(appContext, r.getString("serverId")) ?: error("Server was removed")
        val ledger = Ledger.load(nas)
        recoverPending(nas, ledger)

        if (r.getString("status") == "scanning") {
            phase = "Finding videos"
            currentName = r.getString("root").ifEmpty { "/" }
            val files = JSONArray()
            Smb.walk(nas, r.getString("root")) { e ->
                if (cancelled) return@walk
                val ext = e.name.substringAfterLast('.', "").lowercase()
                if (ext in VIDEO_EXT || ext in SKIP_EXT) {
                    files.put(JSONObject().put("p", e.path).put("s", e.size))
                    if (files.length() % 25 == 0) { r.put("found", files.length()); changed() }
                }
            }
            if (cancelled) return
            r.put("files", files).put("found", files.length()).put("status", "running")
            save()
            changed()
        }

        val files = r.getJSONArray("files")
        while (!cancelled && r.getInt("index") < files.length()) {
            val entry = files.getJSONObject(r.getInt("index"))
            val path = entry.getString("p")
            currentName = path.substringAfterLast('/')
            fileProgress = 0.0
            lastError = null
            changed()
            val started = System.currentTimeMillis()
            var attempt = 0
            var outcome: Outcome
            while (true) {
                outcome = try {
                    processFile(nas, ledger, path, r)
                } catch (t: Throwable) {
                    if (cancelled) return
                    if (!isNetwork(t)) Outcome.Failed(t.message ?: t.javaClass.simpleName)
                    else if (attempt < 3) Outcome.Failed(NETWORK)
                    else throw IllegalStateException("Lost connection to the NAS. Resume when it's reachable again.", t)
                } finally {
                    transformer = null
                    cleanWorkDir()
                }
                // A Wi-Fi blip shouldn't fail the rest of the library: wait and retry this file.
                val networkFailure = outcome is Outcome.Failed &&
                    (outcome.reason == NETWORK || outcome.reason.startsWith("ERROR_CODE_IO"))
                if (networkFailure && attempt < 3 && !cancelled) {
                    attempt++
                    Smb.forget(nas.id)
                    phase = "Reconnecting to the NAS (try $attempt of 3)"
                    changed()
                    Thread.sleep(30_000)
                    continue
                }
                break
            }
            if (cancelled) return
            val top = topFolder(path)
            when (outcome) {
                is Outcome.Done -> {
                    r.put("done", r.getInt("done") + 1)
                    r.put("saved", r.getLong("saved") + outcome.inSize - outcome.outSize)
                    log(nas, path, true, null, outcome.inSize, outcome.outSize, started, outcome.quality)
                }
                is Outcome.Skipped -> {
                    if (outcome.counted) {
                        r.put("skipped", r.getInt("skipped") + 1)
                        ledger.recordIssue(path, "skipped", outcome.reason)
                        log(nas, path, false, "Skipped: ${outcome.reason}", entry.optLong("s"), 0, started, "")
                    }
                }
                is Outcome.Failed -> {
                    r.put("failed", r.getInt("failed") + 1)
                    ledger.recordIssue(path, "failed", outcome.reason)
                    lastError = outcome.reason
                    log(nas, path, false, outcome.reason, entry.optLong("s"), 0, started, "")
                }
            }
            if (outcome !is Outcome.Done && !(outcome is Outcome.Skipped && !outcome.counted)) {
                runCatching { Ledger.save(nas, ledger) }
            }
            r.put("index", r.getInt("index") + 1)
            save()
            changed()
        }
        if (!cancelled) {
            r.put("status", "done").put("finishedAt", System.currentTimeMillis())
            save()
        }
    }

    private const val NETWORK = "Network error"

    private fun isNetwork(t: Throwable): Boolean {
        var c: Throwable? = t
        while (c != null) {
            if (c is java.io.IOException || c.javaClass.name.contains("Transport")) return true
            c = c.cause
        }
        return false
    }

    private sealed class Outcome {
        data class Done(val inSize: Long, val outSize: Long, val quality: String) : Outcome()
        data class Skipped(val reason: String, val counted: Boolean = true) : Outcome()
        data class Failed(val reason: String) : Outcome()
    }

    private fun topFolder(path: String) = path.substringBefore('/').takeIf { path.contains('/') } ?: "(share root)"

    private fun sibling(path: String, suffix: String): String {
        val dir = path.substringBeforeLast('/', "")
        val name = ".${path.substringAfterLast('/')}.$suffix"
        return if (dir.isEmpty()) name else "$dir/$name"
    }

    private fun tempPath(path: String) = sibling(path, "squishy-tmp")
    private fun backupPath(path: String) = sibling(path, "squishy-orig")

    private fun workDir(): File =
        File(appContext.getExternalFilesDir(null) ?: appContext.filesDir, "nas").apply { mkdirs() }

    private fun cleanWorkDir() { workDir().listFiles()?.forEach { it.delete() } }

    /**
     * Repairs a swap interrupted by a crash or power loss. The original is never
     * lost: if the new file didn't make it into place, the backup goes back.
     */
    private fun recoverPending(nas: NasServer, ledger: Ledger) {
        val p = ledger.pending ?: return
        val path = p.getString("path")
        val tmp = p.getString("tmp")
        val backup = p.optString("backup").ifEmpty { backupPath(path) }
        runCatching {
            val hasName = Smb.exists(nas, path)
            val hasBackup = Smb.exists(nas, backup)
            when {
                !hasName && hasBackup -> Smb.rename(nas, backup, path) // put the original back
                hasName && hasBackup -> Smb.delete(nas, backup)        // swap had finished
            }
            if (Smb.exists(nas, tmp)) Smb.delete(nas, tmp)
        }
        ledger.pending = null
        runCatching { Ledger.save(nas, ledger) }
    }

    private fun processFile(nas: NasServer, ledger: Ledger, path: String, r: JSONObject): Outcome {
        val size = Smb.size(nas, path)
        if (ledger.isDone(path, size)) return Outcome.Skipped("already squished", counted = false)
        val ext = path.substringAfterLast('.').lowercase()
        if (ext !in VIDEO_EXT) return Outcome.Skipped(".$ext files can't keep their name with a new codec")
        val top = topFolder(path)
        val height = r.getJSONObject("qualities").optInt(top, 1080)
        val hevc = r.getString("mime") == MimeTypes.VIDEO_H265 && MediaTools.hasHevcEncoder()
        val quality = "${height}p"
        val tmp = tempPath(path)
        if (Smb.exists(nas, tmp)) Smb.delete(nas, tmp)
        if (!Smb.exists(nas, path)) return Outcome.Skipped("file disappeared", counted = false)

        phase = "Reading"
        val url = SmbHttpBridge.url(nas, path)
        try {
            val info = Probe.run(url) ?: return Outcome.Failed("Couldn't read the file: ${Probe.lastError}")
            if (info.videoCount == 0) return Outcome.Skipped("no video track")
            if (NasPlan.alreadySmall(info, height, hevc)) {
                return Outcome.Skipped("already small (${info.videoBitrate / 1000} kbps at ${info.shortSide}p)")
            }
            val (w, h, bitrate) = NasPlan.video(info, height, hevc)

            // Peak local use: encoded video + remuxed file (video + copied tracks).
            val videoBytes = bitrate.toLong() * info.durationMs / 8000
            val otherBytes = if (info.videoBitrate > 0) maxOf(0, size - info.videoBitrate * info.durationMs / 8000) else size / 3
            val needed = videoBytes * 2 + otherBytes + 300L * 1024 * 1024
            val free = StatFs(workDir().path).availableBytes
            if (free < needed) {
                return Outcome.Failed("Not enough free space on the phone (needs ${MediaTools.formatBytes(needed)}, has ${MediaTools.formatBytes(free)})")
            }

            // 1. Video only, on the hardware encoder.
            waitForLocalJobs()
            val video = File(workDir(), "video.mp4")
            phase = "Compressing video"
            encodeWeight = 0.6
            var error = encode(url, video, w, h, bitrate, hevc, keepHdr = info.hdr)
            if (error != null && info.hdr && !cancelled) {
                error = encode(url, video, w, h, bitrate, hevc, keepHdr = false)
            }
            if (cancelled) return Outcome.Failed("Cancelled")
            if (error != null) return Outcome.Failed(error)

            // 2. Rebuild the original container around it, copying everything else as-is.
            phase = "Copying audio & subtitles"
            fileProgress = 0.6
            val out = File(workDir(), "out.$ext")
            remux(video, url, out, ext, info.durationMs, info.videoLanguage)?.let { return Outcome.Failed(it) }
            video.delete()
            if (cancelled) return Outcome.Failed("Cancelled")

            // 3. Verify before touching the NAS.
            phase = "Checking"
            val check = Probe.run(out.path) ?: return Outcome.Failed("Result unreadable: ${Probe.lastError}")
            when {
                !NasPlan.durationClose(info.durationMs, check.durationMs) ->
                    return Outcome.Failed("Verification failed: length ${check.durationMs / 1000}s vs ${info.durationMs / 1000}s")
                // Encoders can silently fall back to a lower resolution; never ship that.
                check.shortSide < minOf(height, info.shortSide) - 16 ->
                    return Outcome.Failed("The phone's encoder couldn't do ${w}×$h (gave ${check.width}×${check.height}). Original kept.")
                check.audioCount != info.audioCount || check.subtitleCount != info.subtitleCount ->
                    return Outcome.Failed("Verification failed: tracks changed (audio ${info.audioCount}→${check.audioCount}, subtitles ${info.subtitleCount}→${check.subtitleCount})")
                out.length() >= size ->
                    return Outcome.Skipped("no size gain (${MediaTools.formatBytes(out.length())} ≥ ${MediaTools.formatBytes(size)}); original kept")
            }

            // 4. Upload next to the original as a hidden temp file.
            phase = "Uploading"
            upload(nas, out, tmp)
            if (cancelled) { runCatching { Smb.delete(nas, tmp) }; return Outcome.Failed("Cancelled") }
            if (Smb.size(nas, tmp) != out.length()) {
                runCatching { Smb.delete(nas, tmp) }
                return Outcome.Failed("Upload incomplete")
            }

            // 5. Swap without ever leaving the name empty:
            //    original → hidden backup, new → original name, then drop the backup.
            phase = "Replacing original"
            val backup = backupPath(path)
            if (Smb.exists(nas, backup)) Smb.delete(nas, backup)
            ledger.pending = JSONObject().put("path", path).put("tmp", tmp).put("backup", backup)
            Ledger.save(nas, ledger)
            try {
                Smb.rename(nas, path, backup)
            } catch (e: Exception) {
                runCatching { Smb.delete(nas, tmp) }
                ledger.pending = null
                runCatching { Ledger.save(nas, ledger) }
                return Outcome.Failed("The NAS refused to rename the original (${e.message}). Nothing was changed.")
            }
            try {
                Smb.rename(nas, tmp, path)
            } catch (e: Exception) {
                runCatching { Smb.rename(nas, backup, path) }
                runCatching { Smb.delete(nas, tmp) }
                ledger.pending = null
                runCatching { Ledger.save(nas, ledger) }
                return Outcome.Failed("The NAS refused to rename the new file (${e.message}). Original restored.")
            }
            Smb.delete(nas, backup)
            ledger.pending = null
            ledger.recordDone(path, top, size, out.length(), quality)
            Ledger.save(nas, ledger)
            fileProgress = 1.0
            return Outcome.Done(size, out.length(), quality)
        } finally {
            SmbHttpBridge.release(url)
        }
    }

    private fun waitForLocalJobs() {
        while (!cancelled && CompressionService.active.isNotEmpty()) {
            phase = "Waiting for local videos"
            changed()
            Thread.sleep(2000)
        }
    }

    /** Returns an error message, or null on success. Blocks the worker thread. */
    private fun encode(url: String, out: File, w: Int, h: Int, bitrate: Int, hevc: Boolean, keepHdr: Boolean): String? {
        out.delete()
        val result = CompletableFuture<String?>()
        main.post {
            try {
                val t = Transformer.Builder(appContext)
                    .setVideoMimeType(if (hevc) MimeTypes.VIDEO_H265 else MimeTypes.VIDEO_H264)
                    .setEncoderFactory(
                        DefaultEncoderFactory.Builder(appContext)
                            .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate).build())
                            .setEnableFallback(true)
                            .build()
                    )
                    .setLooper(Looper.getMainLooper())
                    // Network reads can stall; don't let the muxer watchdog kill a long movie.
                    .setMaxDelayBetweenMuxerSamplesMs(300_000L)
                    .addListener(object : Transformer.Listener {
                        override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                            transformer = null; result.complete(null)
                        }

                        override fun onError(composition: Composition, exportResult: ExportResult, e: ExportException) {
                            transformer = null; result.complete("${e.errorCodeName}: ${e.message ?: "encode failed"}")
                        }
                    })
                    .build()
                val item = EditedMediaItem.Builder(MediaItem.fromUri(url))
                    .setRemoveAudio(true)
                    .setEffects(Effects(emptyList(), listOf(Presentation.createForWidthAndHeight(w, h, Presentation.LAYOUT_SCALE_TO_FIT))))
                    .build()
                val composition = Composition.Builder(EditedMediaItemSequence.Builder(listOf(item)).build())
                    .setHdrMode(if (keepHdr) Composition.HDR_MODE_KEEP_HDR else Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
                    .build()
                transformer = t
                t.start(composition, out.path)
            } catch (e: Throwable) {
                transformer = null
                result.complete(e.message ?: e.javaClass.simpleName)
            }
        }
        // Cancel unblocks via onError/null transformer; poll so a cancel can't hang us.
        while (true) {
            try {
                return result.get(2, TimeUnit.SECONDS)
            } catch (_: java.util.concurrent.TimeoutException) {
                if (cancelled && transformer == null && !result.isDone) return "Cancelled"
            }
        }
    }

    /** Main thread: copies the encoder's progress into the run status. */
    fun pollEncodeProgress() {
        val t = transformer ?: return
        if (t.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
            fileProgress = holder.progress / 100.0 * encodeWeight
        }
    }

    private fun remux(video: File, originalUrl: String, out: File, ext: String, durationMs: Long, videoLanguage: String): String? {
        out.delete()
        val args = mutableListOf(
            "-y", "-hide_banner", "-loglevel", "error",
            "-i", video.path,
            "-i", originalUrl,
            "-map", "0:v:0",
            "-map", "1", "-map", "-1:v", "-map", "-1:d",
            // Global tags and chapters from the original. Per-stream tags (language, track
            // names like "Commentary") follow each copied stream by default; adding any
            // per-stream -map_metadata would switch that off, so the video's language is set explicitly.
            "-map_metadata", "1", "-map_chapters", "1",
            "-c", "copy",
            "-disposition:v:0", "default",
            "-max_muxing_queue_size", "9999",
        )
        args += listOf("-metadata:s:v:0", "language=$videoLanguage")
        if (ext != "mkv") args += listOf("-movflags", "+faststart")
        args += out.path
        val session = FFmpegKit.executeWithArgumentsAsync(
            args.toTypedArray(),
            { },
            { },
            { stats -> if (durationMs > 0) fileProgress = 0.6 + 0.2 * (stats.time / durationMs).coerceIn(0.0, 1.0) },
        )
        while (!session.state.name.let { it == "COMPLETED" || it == "FAILED" }) {
            if (cancelled) { FFmpegKit.cancel(session.sessionId); return "Cancelled" }
            Thread.sleep(500)
            changed()
        }
        if (!ReturnCode.isSuccess(session.returnCode)) {
            val log = session.allLogsAsString?.lines()?.lastOrNull { it.isNotBlank() }?.take(200)
            return "Remux failed: ${log ?: "FFmpeg error ${session.returnCode}"}"
        }
        return null
    }

    private fun upload(nas: NasServer, file: File, remotePath: String) {
        val total = file.length().coerceAtLeast(1)
        Smb.openWrite(nas, remotePath).use { remote ->
            FileInputStream(file).use { input ->
                val buf = ByteArray(4 * 1024 * 1024)
                var offset = 0L
                var lastTick = 0L
                while (!cancelled) {
                    val n = input.read(buf)
                    if (n <= 0) break
                    remote.write(buf, offset, 0, n)
                    offset += n
                    fileProgress = 0.8 + 0.2 * offset / total
                    val now = System.currentTimeMillis()
                    if (now - lastTick > 500) { lastTick = now; changed() }
                }
            }
        }
    }

    private fun log(nas: NasServer, path: String, success: Boolean, error: String?, inSize: Long, outSize: Long, started: Long, quality: String) {
        val r = run ?: return
        val unc = "\\\\${nas.host}\\${nas.share}\\${path.replace('/', '\\')}"
        JobManager.appendLogJson(JSONObject().apply {
            put("id", "nas-$started"); put("kind", "nas"); put("input", unc); put("output", unc)
            put("success", success); put("error", error ?: JSONObject.NULL)
            put("inputSize", inSize); put("outputSize", outSize)
            put("startedAt", started); put("finishedAt", System.currentTimeMillis())
            put("qualityLabel", quality)
            put("codecLabel", if (r.optString("mime") == MimeTypes.VIDEO_H265) "H.265" else "H.264")
            put("originalDeleted", success)
            put("server", nas.name)
        })
    }

    private fun acquireWifi() {
        if (wifiLock?.isHeld == true) return
        val wm = appContext.getSystemService(WifiManager::class.java) ?: return
        wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_LOW_LATENCY, "squishy:nas").apply {
            setReferenceCounted(false); acquire()
        }
    }

    private fun releaseWifi() { wifiLock?.let { if (it.isHeld) it.release() } }

    // ---- status --------------------------------------------------------------------

    fun snapshot(): Map<String, Any?>? {
        val r = run ?: return null
        val total = r.optJSONArray("files")?.length() ?: 0
        val index = r.optInt("index")
        val overall = if (total == 0) 0.0 else ((index + if (active) fileProgress else 0.0) / total).coerceIn(0.0, 1.0)
        return mapOf(
            "status" to r.optString("status"),
            "serverName" to r.optString("serverName"),
            "root" to r.optString("root"),
            "found" to r.optInt("found", total),
            "total" to total,
            "index" to index,
            "done" to r.optInt("done"),
            "failed" to r.optInt("failed"),
            "skipped" to r.optInt("skipped"),
            "saved" to r.optLong("saved"),
            "phase" to phase,
            "current" to currentName,
            "fileProgress" to fileProgress,
            "overall" to overall,
            "error" to (lastError ?: r.optString("error").takeIf { it.isNotEmpty() }),
            "startedAt" to r.optLong("startedAt"),
        )
    }
}
