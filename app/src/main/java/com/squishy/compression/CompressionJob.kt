package com.squishy.compression

import com.squishy.model.VideoItem

data class CompressionJob(
    val id: Long,
    val inputUri: String,
    val displayName: String,
    val sizeBytes: Long,
    val durationMs: Long
) {
    companion object {
        fun from(video: VideoItem): CompressionJob = CompressionJob(
            id = video.id,
            inputUri = video.uri,
            displayName = video.displayName,
            sizeBytes = video.sizeBytes,
            durationMs = video.durationMs
        )
    }
}
