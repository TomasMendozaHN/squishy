package com.squishy.model

enum class VideoSortOrder(
    val label: String
) {
    NAME("Name"),
    DATE_MODIFIED("Date modified"),
    SIZE("Size"),
    DURATION("Duration");

    fun comparator(): Comparator<VideoItem> = when (this) {
        NAME -> compareBy(String.CASE_INSENSITIVE_ORDER, VideoItem::displayName)
        DATE_MODIFIED -> compareByDescending(VideoItem::dateModified)
        SIZE -> compareByDescending(VideoItem::sizeBytes)
        DURATION -> compareByDescending(VideoItem::durationMs)
    }
}
