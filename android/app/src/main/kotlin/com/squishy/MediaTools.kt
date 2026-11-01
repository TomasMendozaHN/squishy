package com.squishy

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaCodecList
import android.media.MediaMetadataRetriever
import android.media.ThumbnailUtils
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.storage.StorageManager
import android.provider.Settings
import android.util.Size
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

    fun formatBytes(bytes: Long): String {
        if (bytes <= 0) return "0 B"
        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        var v = bytes.toDouble()
        var u = 0
        while (v >= 1024 && u < units.lastIndex) { v /= 1024; u++ }
        return if (v >= 100 || u == 0) "%.0f %s".format(v, units[u]) else "%.1f %s".format(v, units[u])
    }
}
