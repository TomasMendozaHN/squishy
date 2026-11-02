package com.squishy

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.ThumbnailUtils
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.storage.StorageManager
import android.provider.Settings
import android.util.Size
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest

object MediaTools {

    private val hevcEncoder: Boolean by lazy {
        MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.any { info ->
            info.isEncoder && info.supportedTypes.any { it.equals("video/hevc", ignoreCase = true) }
        }
    }

    fun hasHevcEncoder() = hevcEncoder

    fun probe(path: String): Map<String, Any?> {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            fun key(k: Int) = r.extractMetadata(k)
            mapOf(
                "path" to path,
                "durationMs" to (key(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L),
                "width" to (key(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0),
                "height" to (key(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0),
                "rotation" to (key(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0),
                "bitrate" to (key(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toIntOrNull() ?: 0),
                "hasAudio" to (key(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes"),
            )
        } catch (t: Throwable) {
            mapOf("path" to path, "error" to (t.message ?: "unreadable"))
        } finally {
            r.release()
        }
    }

    private fun cacheFile(context: Context, key: String): File {
        val dir = File(context.cacheDir, "thumbs").apply { mkdirs() }
        val hash = MessageDigest.getInstance("MD5").digest(key.toByteArray())
            .joinToString("") { "%02x".format(it) }
        return File(dir, "$hash.jpg")
    }

    private fun save(bitmap: Bitmap, file: File): String {
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 82, it) }
        bitmap.recycle()
        return file.absolutePath
    }

    fun thumbnail(context: Context, path: String, size: Int): String? {
        val src = File(path)
        val out = cacheFile(context, "$path:${src.lastModified()}:$size")
        if (out.exists()) return out.absolutePath
        return runCatching {
            save(ThumbnailUtils.createVideoThumbnail(src, Size(size, size), null), out)
        }.getOrNull()
    }

    fun frameAt(context: Context, path: String, timeMs: Long, size: Int): String? {
        val src = File(path)
        val out = cacheFile(context, "$path:${src.lastModified()}:$timeMs:$size:frame")
        if (out.exists()) return out.absolutePath
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            val bmp = r.getScaledFrameAtTime(timeMs * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, size, size)
                ?: r.getScaledFrameAtTime(timeMs * 1000, MediaMetadataRetriever.OPTION_PREVIOUS_SYNC, size, size)
            bmp?.let { save(it, out) }
        } catch (t: Throwable) {
            null
        } finally {
            r.release()
        }
    }

    /** e.g. "3840×2160 HEVC HDR10 60fps": the video track, for failure reports. */
    fun describe(path: String): String {
        val ex = MediaExtractor()
        return try {
            ex.setDataSource(path)
            val format = (0 until ex.trackCount).map { ex.getTrackFormat(it) }
                .firstOrNull { it.getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true }
                ?: return "no video track"
            fun int(key: String) = if (format.containsKey(key)) format.getInteger(key) else null
            val mime = format.getString(MediaFormat.KEY_MIME).orEmpty()
            val codec = when {
                mime.contains("hevc") -> "HEVC"
                mime.contains("avc") -> "H.264"
                mime.contains("av01") -> "AV1"
                mime.contains("vp9") -> "VP9"
                else -> mime.substringAfter('/')
            }
            val hdr = when (int(MediaFormat.KEY_COLOR_TRANSFER)) {
                MediaFormat.COLOR_TRANSFER_ST2084 -> " HDR10"
                MediaFormat.COLOR_TRANSFER_HLG -> " HLG"
                else -> ""
            }
            val fps = if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                runCatching { format.getInteger(MediaFormat.KEY_FRAME_RATE) }
                    .getOrElse { format.getFloat(MediaFormat.KEY_FRAME_RATE).toInt() }
            } else null
            "${int(MediaFormat.KEY_WIDTH)}×${int(MediaFormat.KEY_HEIGHT)} $codec$hdr${fps?.let { " ${it}fps" }.orEmpty()}"
        } catch (t: Throwable) {
            "unknown format"
        } finally {
            ex.release()
        }
    }

    fun hasAudio(path: String): Boolean {
        val ex = MediaExtractor()
        return try {
            ex.setDataSource(path)
            (0 until ex.trackCount).any { ex.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true }
        } catch (_: Throwable) {
            true
        } finally {
            ex.release()
        }
    }

    fun formatTime(ms: Long): String {
        val s = ms / 1000
        return if (s >= 3600) "%d:%02d:%02d".format(s / 3600, s / 60 % 60, s % 60) else "%d:%02d".format(s / 60, s % 60)
    }

    private val LOG_KEYS = listOf("transformer", "codec", "muxer", "media3", "exception", "extractor", "encoder", "decoder", "ffmpeg")

    // Harmless lines every Codec2 device prints; they would crowd out the real error.
    private val LOG_NOISE = listOf("param skipped", "Media Quality Service", "required system resources", "max input size", "BAD_INDEX", "mapper.")

    /** Last codec/muxer warnings and errors from this app's own log (no permission needed). */
    fun recentLog(): String = runCatching {
        val p = ProcessBuilder("logcat", "-d", "-t", "3000", "-v", "time", "--pid=${android.os.Process.myPid()}", "*:W")
            .redirectErrorStream(true)
            .start()
        val lines = p.inputStream.bufferedReader().readLines()
        p.waitFor()
        lines.filter { l -> LOG_KEYS.any { l.contains(it, ignoreCase = true) } && LOG_NOISE.none { l.contains(it) } }
            .takeLast(15)
            .joinToString("\n") { it.take(240) }
    }.getOrDefault("")

    fun shareText(context: Context, text: String) = tryStart(
        context,
        listOf(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text), "Send details")),
    )

    fun storageRoots(context: Context): List<Map<String, String>> {
        val sm = context.getSystemService(StorageManager::class.java)
        return sm.storageVolumes.mapNotNull { v ->
            val dir = v.directory ?: return@mapNotNull null
            mapOf(
                "path" to dir.absolutePath,
                "label" to if (v.isPrimary) "Internal storage" else (v.getDescription(context) ?: "SD card"),
            )
        }
    }

    fun deviceInfo(context: Context): Map<String, Any> {
        val pm = context.getSystemService(PowerManager::class.java)
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "sdk" to Build.VERSION.SDK_INT,
            "hevc" to hevcEncoder,
            "ignoringBatteryOptimizations" to pm.isIgnoringBatteryOptimizations(context.packageName),
        )
    }

    fun isXiaomiFamily() = Build.MANUFACTURER.lowercase() in setOf("xiaomi", "redmi", "poco")

    private fun tryStart(context: Context, intents: List<Intent>): Boolean {
        for (intent in intents) {
            try {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: ActivityNotFoundException) {
            } catch (_: SecurityException) {
            }
        }
        return false
    }

    private fun appDetails(context: Context) =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))

    fun requestIgnoreBatteryOptimizations(context: Context) = tryStart(
        context,
        listOf(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${context.packageName}")),
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
        ),
    )

    /** MIUI / HyperOS "Autostart" toggle. */
    fun openAutostart(context: Context) = tryStart(
        context,
        listOf(
            Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            Intent("miui.intent.action.OP_AUTO_START").addCategory(Intent.CATEGORY_DEFAULT),
            appDetails(context),
        ),
    )

    /** MIUI / HyperOS per-app battery saver ("No restrictions"). */
    fun openBatterySaver(context: Context) = tryStart(
        context,
        listOf(
            Intent().setComponent(ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"))
                .putExtra("package_name", context.packageName)
                .putExtra("package_label", "Squishy"),
            appDetails(context),
        ),
    )

    fun openAppSettings(context: Context) = tryStart(context, listOf(appDetails(context)))

    private fun contentUri(context: Context, path: String): Uri =
        FileProvider.getUriForFile(context, "${context.packageName}.files", File(path))

    /** Opens the video in the user's default player. */
    fun openVideo(context: Context, path: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(contentUri(context, path), "video/*")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return tryStart(context, listOf(intent))
    }

    /**
     * Shares a video. [target] is "whatsapp" (contact picker), "gmail" (new email; Gmail
     * itself swaps attachments over 25 MB for a Drive link) or anything else for the
     * system share sheet. Falls back to the share sheet if the app isn't installed.
     */
    fun shareVideo(context: Context, path: String, target: String): Boolean {
        val uri = contentUri(context, path)
        fun send() = Intent(Intent.ACTION_SEND)
            .setType("video/mp4")
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            .apply { clipData = ClipData.newRawUri(null, uri) }
        // Apps can register several share targets (Gmail: email + Chat; WhatsApp: chats +
        // status), so aim at the one we want instead of letting Android ask.
        fun targeted(pkg: String, hint: String): List<Intent> {
            val base = send().setPackage(pkg)
            val match = context.packageManager.queryIntentActivities(base, 0)
                .firstOrNull { it.activityInfo.name.contains(hint, ignoreCase = true) }
                ?: return listOf(base)
            return listOf(send().setClassName(pkg, match.activityInfo.name), base)
        }
        val direct = when (target) {
            "whatsapp" -> targeted("com.whatsapp", "ContactPicker") + targeted("com.whatsapp.w4b", "ContactPicker")
            "gmail" -> targeted("com.google.android.gm", "Compose")
            else -> emptyList()
        }
        val chooser = Intent.createChooser(send(), null)
        return tryStart(context, direct + chooser)
    }

    fun formatBytes(bytes: Long): String {
        if (bytes <= 0) return "0 B"
        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        var v = bytes.toDouble()
        var u = 0
        while (v >= 1024 && u < units.lastIndex) { v /= 1024; u++ }
        return if (v >= 100 || u == 0) "%.0f %s".format(v, units[u]) else "%.1f %s".format(v, units[u])
    }
}
