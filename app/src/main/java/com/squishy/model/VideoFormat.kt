package com.squishy.model

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object VideoFormat {

    private val SIZE_UNITS = arrayOf("B", "KB", "MB", "GB", "TB")

    fun formatSize(bytes: Long): String {
        if (bytes <= 0L) return "0 B"
        var value = bytes.toDouble()
        var unit = 0
        while (value >= 1024.0 && unit < SIZE_UNITS.lastIndex) {
            value /= 1024.0
            unit++
        }
        return if (unit == 0) {
            "$bytes B"
        } else {
            String.format(Locale.ROOT, "%.1f %s", value, SIZE_UNITS[unit])
        }
    }

    fun formatDuration(ms: Long): String {
        val totalSeconds = (ms / 1000L).coerceAtLeast(0L)
        val hours = totalSeconds / 3600L
        val minutes = (totalSeconds % 3600L) / 60L
        val seconds = totalSeconds % 60L
        return if (hours > 0L) {
            String.format(Locale.ROOT, "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format(Locale.ROOT, "%d:%02d", minutes, seconds)
        }
    }

    fun formatDate(epochMillis: Long, locale: Locale = Locale.getDefault()): String {
        return SimpleDateFormat("d MMM yyyy", locale).format(Date(epochMillis))
    }
}
