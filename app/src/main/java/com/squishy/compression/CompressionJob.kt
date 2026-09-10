package com.squishy.compression

import com.squishy.model.VideoItem

data class CompressionJob(
    val id: Long,
    val inputUri: String,
    val displayName: String,
    val sizeBytes: Long,
    val durationMs: Long,
    val settings: CompressionSettings = CompressionSettings.DEFAULT
) {
    companion object {
        fun from(video: VideoItem, settings: CompressionSettings = CompressionSettings.DEFAULT): CompressionJob =
            CompressionJob(
                id = video.id,
                inputUri = video.uri,
                displayName = video.displayName,
                sizeBytes = video.sizeBytes,
                durationMs = video.durationMs,
                settings = settings
            )
    }
}
