package com.squishy.model

import org.junit.Assert.assertEquals
import org.junit.Test

class VideoFormatTest {

    @Test
    fun formatSize_bytes() {
        assertEquals("0 B", VideoFormat.formatSize(0))
        assertEquals("512 B", VideoFormat.formatSize(512))
    }

    @Test
    fun formatSize_kilobytes() {
        assertEquals("1.0 KB", VideoFormat.formatSize(1024L))
    }

    @Test
    fun formatSize_megabytes() {
        assertEquals("1.0 MB", VideoFormat.formatSize(1_048_576L))
        assertEquals("150.0 MB", VideoFormat.formatSize(150 * 1_048_576L))
    }

    @Test
    fun formatSize_gigabytes() {
        assertEquals("1.5 GB", VideoFormat.formatSize(1_610_612_736L))
    }

    @Test
    fun formatSize_negativeClampsToZero() {
        assertEquals("0 B", VideoFormat.formatSize(-5))
    }

    @Test
    fun formatDuration_short() {
        assertEquals("0:45", VideoFormat.formatDuration(45_000L))
        assertEquals("0:00", VideoFormat.formatDuration(0L))
    }

    @Test
    fun formatDuration_minutes() {
        assertEquals("1:05", VideoFormat.formatDuration(65_000L))
    }

    @Test
    fun formatDuration_hours() {
        assertEquals("1:02:03", VideoFormat.formatDuration(3_723_000L))
    }

    @Test
    fun formatDuration_negativeClampsToZero() {
        assertEquals("0:00", VideoFormat.formatDuration(-1_000L))
    }
}
