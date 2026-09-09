package com.squishy.compression

enum class CompressionStatus {
    QUEUED,
    RUNNING,
    COMPLETED,
    FAILED,
    CANCELLED
}

data class CompressionJobState(
    val job: CompressionJob,
    val status: CompressionStatus,
    val progress: Int = 0,
    val outputPath: String? = null,
    val outputSizeBytes: Long? = null,
    val errorMessage: String? = null
) {
    val isTerminal: Boolean
        get() = status == CompressionStatus.COMPLETED ||
            status == CompressionStatus.FAILED ||
            status == CompressionStatus.CANCELLED
}
