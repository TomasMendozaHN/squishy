package com.squishy.nas

import com.arthenica.ffmpegkit.FFprobeKit
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** What FFprobe says about a file. Bitrates are bits/s, 0 when unknown. */
data class ProbeInfo(
    val durationMs: Long,
    val width: Int,
    val height: Int,
    val rotation: Int,
    val videoBitrate: Long,
    val hdr: Boolean,
    val audioCount: Int,
    val subtitleCount: Int,
    val videoCount: Int,
    val videoLanguage: String,
) {
    val shortSide get() = min(width, height)
}

object Probe {
    /** Why the last [run] returned null (FFprobe's own message), for the log. */
    @Volatile var lastError: String? = null

    fun run(input: String): ProbeInfo? {
        // FFmpegKit mixes FFprobe's logs into the same stream as its JSON, so a single
        // warning can corrupt it. Probe silently; only re-run with logging to explain a failure.
        val session = FFprobeKit.executeWithArguments(
            arrayOf("-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", input)
        )
        val out = session.output.orEmpty()
        val start = out.indexOf('{')
        val end = out.lastIndexOf('}')
        val info = if (start >= 0 && end > start) {
            runCatching { parse(JSONObject(out.substring(start, end + 1))) }.getOrNull()
        } else null
        if (info == null) {
            val why = FFprobeKit.executeWithArguments(arrayOf("-v", "error", "-show_format", input))
            lastError = why.allLogsAsString?.lines()?.lastOrNull { it.isNotBlank() && !it.startsWith("[FORMAT]") }
                ?.trim()?.take(200) ?: "FFprobe error ${session.returnCode}"
        }
        return info
    }

    private fun bps(o: JSONObject): Long {
        o.optString("bit_rate").toLongOrNull()?.let { return it }
        // mkvmerge stores per-track bitrates as tags.
        val tags = o.optJSONObject("tags") ?: return 0
        for (k in tags.keys()) if (k.uppercase().startsWith("BPS")) tags.optString(k).toLongOrNull()?.let { return it }
        return 0
    }

    private fun parse(root: JSONObject): ProbeInfo {
        val format = root.optJSONObject("format") ?: JSONObject()
        val streams = root.optJSONArray("streams")
        var video: JSONObject? = null
        var videoCount = 0
        var audio = 0
        var subs = 0
        var audioBps = 0L
        for (i in 0 until (streams?.length() ?: 0)) {
            val s = streams!!.getJSONObject(i)
            val attachedPic = s.optJSONObject("disposition")?.optInt("attached_pic") == 1
            when (s.optString("codec_type")) {
                "video" -> if (!attachedPic) { videoCount++; if (video == null) video = s }
                "audio" -> { audio++; audioBps += bps(s) }
                "subtitle" -> subs++
            }
        }
        val v = video ?: JSONObject()
        val durationMs = ((format.optString("duration").toDoubleOrNull() ?: 0.0) * 1000).toLong()
        var videoBps = bps(v)
        if (videoBps == 0L) {
            val total = format.optString("bit_rate").toLongOrNull() ?: 0L
            if (total > 0) videoBps = max(0, total - audioBps)
        }
        var rotation = 0
        v.optJSONArray("side_data_list")?.let { list ->
            for (i in 0 until list.length()) {
                val r = list.getJSONObject(i).optInt("rotation", Int.MIN_VALUE)
                if (r != Int.MIN_VALUE) rotation = ((r % 360) + 360) % 360
            }
        }
        val transfer = v.optString("color_transfer")
        return ProbeInfo(
            durationMs = durationMs,
            width = v.optInt("width"),
            height = v.optInt("height"),
            rotation = rotation,
            videoBitrate = videoBps,
            hdr = transfer == "smpte2084" || transfer == "arib-std-b67",
            audioCount = audio,
            subtitleCount = subs,
            videoCount = videoCount,
            videoLanguage = v.optJSONObject("tags")?.optString("language")?.takeIf { it.isNotEmpty() } ?: "und",
        )
    }
}

/** Same numbers as lib/core/encoding_plan.dart (keep the two in sync). */
object NasPlan {
    private val avc = mapOf(360 to 700_000, 480 to 1_200_000, 720 to 2_500_000, 1080 to 5_000_000)

    fun targetBitrate(height: Int, hevc: Boolean): Int {
        val v = avc[height] ?: avc.getValue(1080)
        return if (hevc) (v * 0.6).roundToInt() else v
    }

    /** (width, height, videoBitrate) of the compressed video, display-oriented, never upscaled. */
    fun video(info: ProbeInfo, height: Int, hevc: Boolean): Triple<Int, Int, Int> {
        var bitrate = targetBitrate(height, hevc)
        if (info.videoBitrate > 0) bitrate = min(bitrate, (info.videoBitrate * 0.8).roundToInt())
        val rotated = info.rotation % 180 != 0
        val dw = if (rotated) info.height else info.width
        val dh = if (rotated) info.width else info.height
        val short = info.shortSide
        if (short <= 0) return Triple(dw, dh, bitrate)
        val scale = min(height, short).toDouble() / short
        fun even(x: Double) = max(2, (x / 2).roundToInt() * 2)
        return Triple(even(dw * scale), even(dh * scale), bitrate)
    }

    /** True when re-encoding would barely help: the source is already near the target. */
    fun alreadySmall(info: ProbeInfo, height: Int, hevc: Boolean): Boolean =
        info.videoBitrate > 0 && info.shortSide <= height + 8 &&
            info.videoBitrate <= targetBitrate(height, hevc) * 1.15

    fun durationClose(a: Long, b: Long) = abs(a - b) <= max(2000L, a / 100)
}

/**
 * Lives on the NAS at <share>/.squishy/ledger.json so stats and the "already
 * squished" list survive reinstalls and are shared by every phone.
 */
class Ledger(private val root: JSONObject) {
    val files: JSONObject get() = root.optJSONObject("files") ?: JSONObject().also { root.put("files", it) }
    val folders: JSONObject get() = root.optJSONObject("folders") ?: JSONObject().also { root.put("folders", it) }

    var pending: JSONObject?
        get() = root.optJSONObject("pending")
        set(v) { if (v == null) root.remove("pending") else root.put("pending", v) }

    fun isDone(path: String, currentSize: Long): Boolean =
        files.optJSONObject(path)?.optLong("out") == currentSize

    private fun folder(top: String): JSONObject =
        folders.optJSONObject(top) ?: JSONObject().also { folders.put(top, it) }

    /** Files that failed or were skipped, by path (latest reason wins). */
    private val issues: JSONObject get() = root.optJSONObject("issues") ?: JSONObject().also { root.put("issues", it) }

    fun recordIssue(path: String, kind: String, reason: String) {
        issues.put(path, JSONObject().put("t", kind).put("r", reason).put("at", System.currentTimeMillis()))
    }

    fun recordDone(path: String, top: String, inSize: Long, outSize: Long, quality: String) {
        issues.remove(path)
        files.put(path, JSONObject().apply {
            put("in", inSize); put("out", outSize); put("at", System.currentTimeMillis()); put("q", quality)
        })
        folder(top).apply {
            put("files", optInt("files") + 1)
            put("saved", optLong("saved") + (inSize - outSize))
            put("inBytes", optLong("inBytes") + inSize)
        }
    }

    fun toStatsMap(): Map<String, Any> {
        val failed = mutableMapOf<String, Int>()
        val skipped = mutableMapOf<String, Int>()
        for (p in issues.keys()) {
            val top = if (p.contains('/')) p.substringBefore('/') else "(share root)"
            val bucket = if (issues.getJSONObject(p).optString("t") == "failed") failed else skipped
            bucket[top] = (bucket[top] ?: 0) + 1
        }
        val names = folders.keys().asSequence().toSet() + failed.keys + skipped.keys
        val perFolder = names.associateWith { k ->
            val f = folders.optJSONObject(k) ?: JSONObject()
            mapOf(
                "files" to f.optInt("files"), "saved" to f.optLong("saved"), "inBytes" to f.optLong("inBytes"),
                "failed" to (failed[k] ?: 0), "skipped" to (skipped[k] ?: 0),
            )
        }
        return mapOf(
            "files" to perFolder.values.sumOf { it["files"] as Int },
            "saved" to perFolder.values.sumOf { it["saved"] as Long },
            "folders" to perFolder,
        )
    }

    override fun toString(): String = root.toString()

    companion object {
        const val PATH = ".squishy/ledger.json"

        fun load(nas: NasServer): Ledger =
            Ledger(Smb.readText(nas, PATH)?.let { runCatching { JSONObject(it) }.getOrNull() } ?: JSONObject().put("version", 1))

        fun save(nas: NasServer, ledger: Ledger) {
            Smb.mkdirs(nas, ".squishy")
            Smb.writeText(nas, PATH, ledger.toString())
        }
    }
}
