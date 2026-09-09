package com.squishy.model

import org.junit.Assert.assertEquals
import org.junit.Test

class VideoSortOrderTest {

    private val a = VideoItem(1, "alpha.mp4", 300L, 300_000L, 10_000L, "content://video/1")
    private val b = VideoItem(2, "Bravo.mp4", 100L, 200_000L, 30_000L, "content://video/2")
    private val c = VideoItem(3, "charlie.mp4", 200L, 100_000L, 20_000L, "content://video/3")

    private fun sample() = listOf(b, c, a)

    @Test
    fun name_sorts_case_insensitively() {
        val sorted = sample().sortedWith(VideoSortOrder.NAME.comparator())
        assertEquals(listOf(1L, 2L, 3L), sorted.map { it.id })
    }

    @Test
    fun dateModified_sortsNewestFirst() {
        val sorted = sample().sortedWith(VideoSortOrder.DATE_MODIFIED.comparator())
        assertEquals(listOf(1L, 2L, 3L), sorted.map { it.id })
    }

    @Test
    fun size_sortsLargestFirst() {
        val sorted = sample().sortedWith(VideoSortOrder.SIZE.comparator())
        assertEquals(listOf(1L, 3L, 2L), sorted.map { it.id })
    }

    @Test
    fun duration_sortsLongestFirst() {
        val sorted = sample().sortedWith(VideoSortOrder.DURATION.comparator())
        assertEquals(listOf(2L, 3L, 1L), sorted.map { it.id })
    }

    @Test
    fun emptyList_sortsToEmptyList() {
        assertEquals(emptyList<Long>(), emptyList<VideoItem>().sortedWith(VideoSortOrder.NAME.comparator()).map { it.id })
    }

    @Test
    fun sortOrders_haveReadableLabels() {
        assertEquals("Name", VideoSortOrder.NAME.label)
        assertEquals("Date modified", VideoSortOrder.DATE_MODIFIED.label)
        assertEquals("Size", VideoSortOrder.SIZE.label)
        assertEquals("Duration", VideoSortOrder.DURATION.label)
    }
}
