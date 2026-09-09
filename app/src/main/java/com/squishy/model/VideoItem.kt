package com.squishy.model

data class VideoItem(
    val id: Long,
    val displayName: String,
    val sizeBytes: Long,
    val dateModified: Long,
    val durationMs: Long,
    val uri: String
)
