@file:OptIn(UnstableApi::class)

package com.squishy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.Clock
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSourceBitmapLoader
import androidx.media3.effect.Presentation
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultAssetLoaderFactory
import androidx.media3.transformer.DefaultDecoderFactory
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
import com.arthenica.ffmpegkit.FFprobeKit
import com.arthenica.ffmpegkit.ReturnCode
import com.squishy.nas.NasRunner
import java.io.File
import kotlin.math.abs
import kotlin.math.max

/**
 * Runs the job queue. It is a foreground service of type specialUse, holds a
 * partial wake lock while working and is START_STICKY, so it keeps going with the
 * app in the background, the screen off, or the task swiped away.
 */
class CompressionService : Service() {

    companion object {
        const val ACTION_PUMP = "com.squishy.PUMP"
        const val ACTION_CANCEL_ALL = "com.squishy.CANCEL_ALL"
        private const val CHANNEL_WORK = "squishing"
        private const val CHANNEL_DONE = "finished"
        private const val NOTIFICATION_WORK = 1
        private const val NOTIFICATION_DONE = 2

        fun start(context: Context, action: String = ACTION_PUMP) {
            context.startForegroundService(Intent(context, CompressionService::class.java).setAction(action))
        }

        /** In safe mode the video encode is this share of the progress bar; the audio mux is the rest. */
        private const val ENCODE_SHARE = 0.95

        /**
         * A running job with no progress for this long is considered stuck: a few minutes on
         * the first attempt (so a real hang gets its retry quickly), longer on the retry.
         */
        private const val FIRST_STALL_MS = 3 * 60_000L
        private const val STALL_MS = 10 * 60_000L

        /**
         * The ticker runs every 500 ms. A longer gap means the system kept the whole app paused
         * (HyperOS/MIUI freeze background apps); that time is not counted as a stall.
         */
        private const val PAUSE_GAP_MS = 15_000L

        /**
         * After a long pause the codec service may have dropped its buffers and the encoder
         * never moves again. If nothing moves this long after a pause, the job starts over
         * (up to MAX_PAUSE_RESTARTS times, without using up its retry).
         */
        private const val RESUME_GRACE_MS = 45_000L
        private const val MAX_PAUSE_RESTARTS = 3

        /** Resource-contention failures that usually succeed when the job runs alone. */
        private val RETRYABLE = setOf(
            ExportException.ERROR_CODE_MUXING_TIMEOUT,
            ExportException.ERROR_CODE_MUXING_FAILED,
            ExportException.ERROR_CODE_ENCODER_INIT_FAILED,
            ExportException.ERROR_CODE_ENCODING_FAILED,
            ExportException.ERROR_CODE_DECODER_INIT_FAILED,
            ExportException.ERROR_CODE_DECODING_FAILED,
            ExportException.ERROR_CODE_VIDEO_FRAME_PROCESSING_FAILED,
        )

        /** Running jobs and their transformer (null while safe mode muxes the audio with FFmpeg). */
        val active = mutableMapOf<String, Transformer?>()

        /**
         * Each transformer lives on its own thread. Media3's cancel() waits until the codecs
         * are released, and a stuck hardware decoder can make that wait forever; on the main
         * thread that froze the whole app until Android closed it.
         */
        private val workers = mutableMapOf<String, Handler>()
        var instance: CompressionService? = null
    }

    private val main = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastStateSave = 0L
    private var sessionDone = 0
    private var sessionFailed = 0
    private var sessionSaved = 0L

    private var lastTick = 0L

    private val ticker = object : Runnable {
        override fun run() {
            val now = SystemClock.elapsedRealtime()
            if (lastTick > 0 && now - lastTick > PAUSE_GAP_MS) onPaused(now - lastTick)
            lastTick = now
            pollProgress()
            if (active.isNotEmpty() && now - lastStateSave > 30_000) {
                lastStateSave = now
                ExitReasons.saveState(this@CompressionService)
            }
            main.postDelayed(this, 500)
        }
    }

    /** The app was frozen for [gap] ms: restart the stall clocks and remember it for the report. */
    private fun onPaused(gap: Long) {
        val now = System.currentTimeMillis()
        for (id in active.keys) {
            val job = JobManager.jobs[id] ?: continue
            job.lastProgressAt = now
            job.resumedAt = now
            job.pauses++
            job.pausedMs += gap
        }
    }

    /** The encoder didn't come back after a pause: run the job again from the start. */
    private fun restartAfterPause(job: Job) {
        stopWork(job)
        job.pauseRestarts++
        job.resumedAt = 0
        job.status = JobStatus.queued
        job.progress = 0.0
        JobManager.saveQueue()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        JobManager.init(this)
        NasRunner.init(this)
        createChannels()
        goForeground()
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "squishy:compress")
            .apply { setReferenceCounted(false); acquire() }
        main.post(ticker)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Must be called promptly on every start; the type is passed explicitly
        // (v1 crashed on Android 16 when it wasn't).
        goForeground()
        if (intent?.action == ACTION_CANCEL_ALL) cancelAll()
        pump()
        return START_STICKY
    }

    override fun onDestroy() {
        main.removeCallbacks(ticker)
        active.keys.toList().mapNotNull { JobManager.jobs[it] }.forEach { stopWork(it) }
        active.clear()
        wakeLock?.let { if (it.isHeld) it.release() }
        instance = null
        super.onDestroy()
    }

    private fun goForeground() {
        startForeground(NOTIFICATION_WORK, buildWorkNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
    }

    /** Starts queued jobs until the parallel limit is reached; stops when idle. */
    fun pump() {
        while (active.size < JobManager.parallel) {
            // The NAS run's encode step shares the same hardware encoder.
            if (NasRunner.encoding) break
            // A job retrying on its own gets the hardware encoder to itself.
            if (active.keys.any { JobManager.jobs[it]?.solo == true }) break
            val job = JobManager.nextQueued() ?: break
            if (job.solo && active.isNotEmpty()) break
            startJob(job)
        }
        NasRunner.kick()
        if (active.isEmpty() && !JobManager.hasWork() && !NasRunner.active) finishSession()
        JobManager.changed()
    }

    private fun startJob(job: Job) {
        job.status = JobStatus.running
        job.startedAt = System.currentTimeMillis()
        job.lastProgressAt = job.startedAt
        job.progress = 0.0
        job.encodeFraction = 0.0
        job.lastBytes = 0
        job.resumedAt = 0
        try {
            val input = File(job.input)
            if (!input.exists()) throw IllegalStateException("Source file no longer exists")
            File(job.output).parentFile?.mkdirs()
            File(job.tempPath).delete()
            File(job.videoTempPath).delete()
            val worker = Handler(HandlerThread("squish-${job.id}").apply { start() }.looper)
            val run = ++job.run
            val transformer = buildTransformer(job, worker.looper, run)
            val composition = buildComposition(job)
            val out = if (job.safe) job.videoTempPath else job.tempPath
            active[job.id] = transformer
            workers[job.id] = worker
            job.rawProgress = -1
            worker.post {
                try {
                    transformer.start(composition, out)
                } catch (t: Throwable) {
                    main.post {
                        if (job.run != run) return@post
                        stopWork(job)
                        fail(job, t.message ?: t.javaClass.simpleName)
                        pump()
                    }
                }
            }
        } catch (t: Throwable) {
            stopWork(job)
            fail(job, t.message ?: t.javaClass.simpleName)
        }
    }

    /** Callbacks arrive on [looper] and are handed to the main thread; [run] drops stale ones. */
    private fun buildTransformer(job: Job, looper: Looper, run: Int): Transformer {
        val encoderFactory = DefaultEncoderFactory.Builder(this)
            .setRequestedVideoEncoderSettings(
                VideoEncoderSettings.Builder().setBitrate(job.videoBitrate).build()
            )
            .setRequestedAudioEncoderSettings(
                AudioEncoderSettings.Builder().setBitrate(max(job.audioBitrate, 64000)).build()
            )
            .setEnableFallback(true)
            .build()
        // The retry uses H.264: some phones' H.265 encoders stall where H.264 does not.
        val mime = if (job.mime == MimeTypes.VIDEO_H265 && (!MediaTools.hasHevcEncoder() || job.attempts > 0)) {
            MimeTypes.VIDEO_H264
        } else job.mime
        job.encoderLabel = if (mime == MimeTypes.VIDEO_H265) "H.265" else "H.264"
        val builder = Transformer.Builder(this)
        if (job.attempts > 0) {
            // The retry decodes in software: a phone's hardware decoder can hang for good on one
            // odd frame (always at the same spot) that a software decoder just gets through.
            job.encoderLabel += ", software decoder"
            val softwareFirst = MediaCodecSelector { mimeType, secure, tunneling ->
                MediaCodecUtil.getDecoderInfos(mimeType, secure, tunneling).sortedByDescending { it.softwareOnly }
            }
            val decoderFactory = DefaultDecoderFactory.Builder(this)
                .setMediaCodecSelector(softwareFirst)
                .setEnableDecoderFallback(true)
                .build()
            builder.setAssetLoaderFactory(
                DefaultAssetLoaderFactory(this, decoderFactory, Clock.DEFAULT, DefaultMediaSourceFactory(this), DataSourceBitmapLoader(this))
            )
        }
        return builder
            .setVideoMimeType(mime)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoderFactory)
            .setLooper(looper)
            // Media3's muxer timer (ERROR_CODE_MUXING_TIMEOUT) also fires right after the system
            // unfreezes a paused app, killing a healthy export. It's off; pollProgress detects
            // real stalls instead and doesn't count paused time.
            .setMaxDelayBetweenMuxerSamplesMs(C.TIME_UNSET)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) = onMain {
                    releaseWorker(job)
                    if (job.safe) {
                        muxAudio(job)
                        return@onMain
                    }
                    active.remove(job.id)
                    complete(job)
                    pump()
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) = onMain {
                    releaseWorker(job)
                    active.remove(job.id)
                    if (job.status == JobStatus.running) {
                        if (job.attempts == 0 && exportException.errorCode in RETRYABLE) {
                            retrySolo(job)
                        } else {
                            // Media3 puts the whole codec configuration in the message; the codec name is enough.
                            val message = (exportException.message ?: "export failed").replace(Regex("configurationFormat=\\{.*?\\}, "), "")
                            failWithScan(job, "${exportException.errorCodeName}${where(job)}: $message${retryNote(job)}${details(job)}")
                        }
                    }
                    pump()
                }

                private fun onMain(block: () -> Unit) {
                    main.post { if (job.run == run) block() }
                }
            })
            .build()
    }

    /** The transformer finished; its thread can end. */
    private fun releaseWorker(job: Job) {
        workers.remove(job.id)?.looper?.quitSafely()
    }

    private fun buildComposition(job: Job): Composition {
        val uri = Uri.fromFile(File(job.input))
        val effects = Effects(
            emptyList(),
            listOf(Presentation.createForWidthAndHeight(job.width, job.height, Presentation.LAYOUT_SCALE_TO_FIT)),
        )
        val mediaItems = if (job.segments.isEmpty()) {
            listOf(MediaItem.fromUri(uri))
        } else {
            job.segments.map { (start, end) ->
                MediaItem.Builder()
                    .setUri(uri)
                    .setClippingConfiguration(
                        MediaItem.ClippingConfiguration.Builder()
                            .setStartPositionMs(start)
                            .setEndPositionMs(end)
                            .build()
                    )
                    .build()
            }
        }
        val edited = mediaItems.map { EditedMediaItem.Builder(it).setEffects(effects).setRemoveAudio(job.safe).build() }
        val sequence = EditedMediaItemSequence.Builder(edited).build()
        return Composition.Builder(sequence)
            // Phone cameras often record HDR; SDR output is smaller and plays everywhere.
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
            .build()
    }

    /** Verifies the output, moves it into place and deletes the original if asked. */
    private fun complete(job: Job) {
        val temp = File(job.tempPath)
        if (!temp.exists() || temp.length() == 0L) {
            temp.delete(); fail(job, "Output file is empty"); return
        }
        val outDuration = readDurationMs(temp)
        if (job.expectedDurationMs > 0) {
            val tolerance = max(2000L, job.expectedDurationMs / 20)
            if (outDuration <= 0 || abs(outDuration - job.expectedDurationMs) > tolerance) {
                temp.delete()
                fail(job, "Verification failed: output is ${outDuration / 1000}s, expected ${job.expectedDurationMs / 1000}s")
                return
            }
        }
        if (!job.isCut && temp.length() >= job.inputSize) {
            val outSize = temp.length()
            temp.delete()
            fail(job, "No size gain (${MediaTools.formatBytes(outSize)} ≥ original ${MediaTools.formatBytes(job.inputSize)}). Original kept.")
            return
        }
        val target = uniqueFile(File(job.output))
        if (!temp.renameTo(target)) {
            temp.delete(); fail(job, "Could not write to ${target.parent}"); return
        }
        job.output = target.absolutePath
        job.outputSize = target.length()
        job.progress = 1.0
        job.status = JobStatus.done
        val scan = mutableListOf(target.absolutePath)
        if (job.deleteOriginal && !job.isCut) {
            job.originalDeleted = File(job.input).delete()
            if (!job.originalDeleted) job.error = "Compressed fine, but the original could not be deleted"
            scan += job.input
        }
        MediaScannerConnection.scanFile(this, scan.toTypedArray(), null, null)
        sessionDone++
        if (!job.isCut) sessionSaved += job.inputSize - job.outputSize
        JobManager.finish(job)
    }

    /**
     * Safe mode, step 2: FFmpeg puts the source's audio next to the encoded video. The audio is
     * re-encoded to AAC with gaps filled by silence, so odd audio tracks (gaps, late start,
     * early end) are fixed instead of stalling the export.
     */
    private fun muxAudio(job: Job) {
        active[job.id] = null
        job.lastProgressAt = System.currentTimeMillis()
        job.progress = ENCODE_SHARE
        job.encodeFraction = 1.0
        val video = File(job.videoTempPath)
        val temp = File(job.tempPath)
        if (!MediaTools.hasAudio(job.input)) {
            active.remove(job.id)
            if (video.renameTo(temp)) complete(job) else fail(job, "Could not write the output file")
            pump()
            return
        }
        val args = arrayOf(
            "-y", "-hide_banner", "-loglevel", "error",
            "-i", video.path, "-i", job.input,
            "-map", "0:v:0", "-map", "1:a:0",
            "-c:v", "copy",
            "-c:a", "aac", "-b:a", "${max(job.audioBitrate, 64000)}",
            "-af", "aresample=async=1:first_pts=0",
            "-max_muxing_queue_size", "9999",
            "-movflags", "+faststart",
            temp.path,
        )
        val session = FFmpegKit.executeWithArgumentsAsync(
            args,
            { s ->
                main.post {
                    // A cancel or stall already cleaned up; otherwise it's ours to finish.
                    if (job.status != JobStatus.running || job.id !in active || active[job.id] != null) return@post
                    active.remove(job.id)
                    job.ffmpegSession = null
                    video.delete()
                    if (ReturnCode.isSuccess(s.returnCode)) {
                        complete(job)
                    } else {
                        val log = s.allLogsAsString?.lines()?.lastOrNull { it.isNotBlank() }?.take(200)
                        fail(job, "Adding the audio failed: ${log ?: "FFmpeg error ${s.returnCode}"}${details(job)}")
                    }
                    pump()
                }
            },
            { },
            { stats ->
                if (job.expectedDurationMs > 0) main.post {
                    val p = ENCODE_SHARE + (1 - ENCODE_SHARE) * (stats.time / job.expectedDurationMs).coerceIn(0.0, 1.0)
                    if (p > job.progress) job.lastProgressAt = System.currentTimeMillis()
                    job.progress = p
                }
            },
        )
        job.ffmpegSession = session.sessionId
    }

    /** Stops whatever is running for this job (encoder or audio mux) and removes temp files. */
    private fun stopWork(job: Job) {
        job.run++ // ignore anything the old transformer still reports
        val transformer = active.remove(job.id)
        val worker = workers.remove(job.id)
        if (transformer != null && worker != null) {
            // If the codec is stuck, cancel() never returns; only this job's thread is left waiting.
            worker.post { runCatching { transformer.cancel() } }
            worker.looper.quitSafely()
        }
        job.ffmpegSession?.let { FFmpegKit.cancel(it) }
        job.ffmpegSession = null
        File(job.tempPath).delete()
        File(job.videoTempPath).delete()
    }

    /**
     * Fails a job whose video got stuck, after scanning the source around that spot so the
     * report says what's there. The job stays "running" (but not active) until the scan is
     * done; a cancel in the meantime wins.
     */
    private fun failWithScan(job: Job, reason: String) {
        if (job.isCut || job.expectedDurationMs <= 0) {
            fail(job, reason)
            return
        }
        probeAround(job.input, (job.expectedDurationMs * job.encodeFraction).toLong()) { found ->
            if (job.status == JobStatus.running) {
                fail(job, reason, found)
                pump()
            }
        }
    }

    /**
     * Scans about 25 s of the video around [atMs] with FFmpeg's own decoder and reports what it finds:
     * decode errors, size changes and timestamp jumps. Runs off the main thread; [done] is called
     * on the main thread.
     */
    private fun probeAround(path: String, atMs: Long, done: (String) -> Unit) {
        val from = max(0L, atMs - 10_000) / 1000.0
        Thread {
            val text = runCatching {
                val session = FFprobeKit.executeWithArguments(arrayOf(
                    "-v", "error", "-select_streams", "v:0", "-read_intervals", "%.1f%%+25".format(java.util.Locale.US, from),
                    "-show_entries", "frame=pts_time,pict_type,width,height", "-of", "compact=p=0", path,
                ))
                summarizeProbe(session.output.orEmpty(), from)
            }.getOrElse { "Scan failed: ${it.message}" }
            main.post { done(text) }
        }.start()
    }

    private fun summarizeProbe(output: String, from: Double): String {
        val frames = mutableListOf<Triple<Double, String, String>>() // time, size, type
        val errors = mutableListOf<String>()
        for (line in output.lines().map { it.trim() }.filter { it.isNotEmpty() }) {
            if ("pts_time=" in line) {
                val f = line.split('|').associate { it.substringBefore('=') to it.substringAfter('=') }
                val t = f["pts_time"]?.toDoubleOrNull() ?: continue
                frames += Triple(t, "${f["width"]}×${f["height"]}", f["pict_type"].orEmpty())
            } else {
                errors += line.take(160)
            }
        }
        fun ts(t: Double) = MediaTools.formatTime((t * 1000).toLong())
        // FFmpeg starts at the keyframe before [from], so the real range is what was read.
        val range = if (frames.isEmpty()) "from ${ts(from)}" else "${ts(frames.first().first)}–${ts(frames.last().first)}"
        val out = mutableListOf("Scan of $range (FFmpeg): ${frames.size} frames, ${errors.size} decode errors")
        if (frames.isNotEmpty()) {
            val sizes = frames.map { it.second }.distinct()
            if (sizes.size > 1) {
                val change = frames.zipWithNext().first { it.first.second != it.second.second }
                out += "Resolution changes at ${ts(change.second.first)}: ${sizes.joinToString(" → ")}"
            }
            val gap = frames.zipWithNext().maxByOrNull { it.second.first - it.first.first }
            if (gap != null && gap.second.first - gap.first.first > 0.5) {
                out += "Timestamp jump at ${ts(gap.first.first)}: %.1f s".format(java.util.Locale.US, gap.second.first - gap.first.first)
            }
            val back = frames.zipWithNext().firstOrNull { it.second.first < it.first.first }
            if (back != null) out += "Timestamps go backwards at ${ts(back.first.first)}"
            out += "Keyframes: ${frames.filter { it.third == "I" }.joinToString(" ") { ts(it.first) }.ifEmpty { "none" }}"
        }
        out += errors.distinct().take(4)
        return out.joinToString("\n")
    }

    private fun retryNote(job: Job) =
        if (job.attempts > 0) " (also failed when retried on its own with ${job.encoderLabel}, video and audio done separately)" else ""

    /** Where in the video the encoder was, e.g. " at 37% (0:33 of 1:30)". */
    private fun where(job: Job): String {
        val pct = (job.encodeFraction * 100).toInt()
        if (job.expectedDurationMs <= 0) return " at $pct%"
        val at = (job.expectedDurationMs * job.encodeFraction).toLong()
        return " at $pct% (${MediaTools.formatTime(at)} of ${MediaTools.formatTime(job.expectedDurationMs)})"
    }

    private fun pausedNote(job: Job) =
        if (job.pauses == 0) "" else " · Android paused Squishy ${job.pauses}× in the background " +
            "(${MediaTools.formatTime(job.pausedMs)} total). Settings → Background reliability → Battery saver → No restrictions"

    /** Source format + encoder, so a failure report says what kind of video broke. */
    private fun details(job: Job) = " [${MediaTools.describe(job.input)} → ${job.width}×${job.height} ${job.encoderLabel}]"

    /** Puts a job back at the front of the queue to run alone, once. */
    private fun retrySolo(job: Job) {
        File(job.tempPath).delete()
        File(job.videoTempPath).delete()
        job.attempts++
        job.solo = true
        job.status = JobStatus.queued
        job.progress = 0.0
        JobManager.saveQueue()
        JobManager.changed()
    }

    private fun fail(job: Job, reason: String, scan: String? = null) {
        job.status = JobStatus.failed
        job.error = reason + pausedNote(job)
        job.diag = listOfNotNull(scan, MediaTools.recentLog()).filter { it.isNotBlank() }.joinToString("\n")
        File(job.tempPath).delete()
        File(job.videoTempPath).delete()
        sessionFailed++
        JobManager.finish(job)
    }

    fun cancel(id: String) {
        val job = JobManager.jobs[id] ?: return
        if (job.status != JobStatus.queued && job.status != JobStatus.running) return
        stopWork(job)
        job.status = JobStatus.cancelled
        job.error = "Cancelled"
        JobManager.finish(job)
        pump()
    }

    fun cancelAll() {
        JobManager.jobs.values
            .filter { it.status == JobStatus.queued || it.status == JobStatus.running }
            .map { it.id }
            .forEach { id ->
                val job = JobManager.jobs[id]!!
                stopWork(job)
                job.status = JobStatus.cancelled
                job.error = "Cancelled"
                JobManager.finish(job)
            }
    }

    private fun pollProgress() {
        NasRunner.pollEncodeProgress()
        if (NasRunner.active) {
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_WORK, buildWorkNotification())
        }
        if (active.isEmpty()) return
        val now = System.currentTimeMillis()
        val stalled = mutableListOf<Job>()
        val revive = mutableListOf<Job>()
        for ((id, transformer) in active) {
            val job = JobManager.jobs[id] ?: continue
            // Progress is read on the transformer's thread and picked up on the next tick.
            if (transformer != null) {
                workers[id]?.post {
                    val holder = ProgressHolder()
                    if (transformer.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) job.rawProgress = holder.progress
                }
            }
            // While FFmpeg adds the audio (transformer == null) its stats callback moves progress.
            if (transformer != null && job.rawProgress >= 0) {
                job.encodeFraction = job.rawProgress / 100.0
                val p = job.encodeFraction * (if (job.safe) ENCODE_SHARE else 1.0)
                if (p > job.progress || job.lastProgressAt == 0L) job.lastProgressAt = now
                job.progress = p
            }
            // Progress is whole percents (minutes apart on a long movie); a growing output file
            // also counts as alive.
            if (transformer != null) {
                val bytes = File(if (job.safe) job.videoTempPath else job.tempPath).length()
                if (bytes > job.lastBytes) {
                    job.lastBytes = bytes
                    job.lastProgressAt = now
                }
            }
            if (job.resumedAt > 0) {
                // A last flush right after the resume doesn't count; it has to keep moving.
                if (job.lastProgressAt > job.resumedAt + 10_000) {
                    job.resumedAt = 0
                } else if (now - job.resumedAt > RESUME_GRACE_MS && job.pauseRestarts < MAX_PAUSE_RESTARTS) {
                    revive += job
                    continue
                }
            }
            val limit = if (job.attempts == 0) FIRST_STALL_MS else STALL_MS
            if (job.lastProgressAt > 0 && now - job.lastProgressAt > limit) stalled += job
        }
        revive.forEach { restartAfterPause(it) }
        for (job in stalled) {
            val muxing = job.id in active && active[job.id] == null
            stopWork(job)
            job.lastProgressAt = 0
            if (job.attempts == 0) {
                retrySolo(job)
            } else if (muxing) {
                fail(job, "Adding the audio stalled: no progress for ${STALL_MS / 60_000} minutes${retryNote(job)}${details(job)}")
            } else {
                failWithScan(job, "Encoder stalled${where(job)}: no progress for ${STALL_MS / 60_000} minutes${retryNote(job)}${details(job)}")
            }
        }
        if (stalled.isNotEmpty() || revive.isNotEmpty()) pump()
        JobManager.changed()
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_WORK, buildWorkNotification())
    }

    private fun finishSession() {
        if (sessionDone + sessionFailed > 0) {
            val text = buildString {
                append("$sessionDone squished")
                if (sessionFailed > 0) append(", $sessionFailed failed")
                if (sessionSaved > 0) append(" · saved ${MediaTools.formatBytes(sessionSaved)}")
            }
            val n = Notification.Builder(this, CHANNEL_DONE)
                .setSmallIcon(R.drawable.ic_stat_squishy)
                .setContentTitle("All done!")
                .setContentText(text)
                .setContentIntent(openAppIntent())
                .setAutoCancel(true)
                .build()
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_DONE, n)
        }
        sessionDone = 0; sessionFailed = 0; sessionSaved = 0
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildWorkNotification(): Notification {
        val all = JobManager.jobs.values.toList()
        val running = all.filter { it.status == JobStatus.running }
        val queued = all.count { it.status == JobStatus.queued }
        val sessionJobs = all.filter { it.startedAt > 0 || it.status == JobStatus.queued }
        val overall = if (sessionJobs.isEmpty()) 0.0 else sessionJobs.sumOf {
            if (it.status == JobStatus.running) it.progress else if (it.status == JobStatus.queued) 0.0 else 1.0
        } / sessionJobs.size
        NasRunner.snapshot()?.takeIf { NasRunner.active && running.isEmpty() }?.let { nas ->
            val total = (nas["total"] as Int).coerceAtLeast(1)
            return Notification.Builder(this, CHANNEL_WORK)
                .setSmallIcon(R.drawable.ic_stat_squishy)
                .setContentTitle("NAS: ${nas["phase"]} · ${nas["current"]}")
                .setContentText("${nas["index"]} of ${nas["total"]} · saved ${MediaTools.formatBytes(nas["saved"] as Long)}")
                .setProgress(1000, ((nas["overall"] as Double) * 1000).toInt(), nas["status"] == "scanning" || total == 0)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
                .setContentIntent(openAppIntent())
                .build()
        }
        val title = when {
            running.isEmpty() -> "Getting ready…"
            running.size == 1 -> "Squishing ${running[0].name}"
            else -> "Squishing ${running.size} videos"
        }
        val text = buildString {
            append("${(overall * 100).toInt()}% overall")
            if (queued > 0) append(" · $queued waiting")
        }
        val cancel = PendingIntent.getService(
            this, 1,
            Intent(this, CompressionService::class.java).setAction(ACTION_CANCEL_ALL),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return Notification.Builder(this, CHANNEL_WORK)
            .setSmallIcon(R.drawable.ic_stat_squishy)
            .setContentTitle(title)
            .setContentText(text)
            .setProgress(100, (overall * 100).toInt(), running.isEmpty())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(openAppIntent())
            .addAction(Notification.Action.Builder(null, "Cancel all", cancel).build())
            .build()
    }

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        this, 0,
        Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE,
    )

    private fun createChannels() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_WORK, "Squishing progress", NotificationManager.IMPORTANCE_LOW)
        )
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_DONE, "Finished batches", NotificationManager.IMPORTANCE_DEFAULT)
        )
    }

    private fun readDurationMs(file: File): Long = runCatching {
        MediaMetadataRetriever().use { r ->
            r.setDataSource(file.absolutePath)
            r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0L
        }
    }.getOrDefault(0L)

    private fun uniqueFile(file: File): File {
        if (!file.exists()) return file
        val base = file.nameWithoutExtension
        val ext = file.extension
        var i = 1
        while (true) {
            val candidate = File(file.parentFile, "$base ($i).$ext")
            if (!candidate.exists()) return candidate
            i++
        }
    }
}
