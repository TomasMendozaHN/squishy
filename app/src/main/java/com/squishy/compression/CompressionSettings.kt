package com.squishy.compression

data class CompressionSettings(
    val targetHeight: Int = 0,
    val targetVideoBitrateBps: Int = DEFAULT_VIDEO_BITRATE_BPS
) {
    companion object {
        const val ORIGINAL_HEIGHT = 0
        private const val DEFAULT_VIDEO_BITRATE_BPS = 2_500_000

        val ORIGINAL = CompressionSettings()

        val QUALITY_480P = CompressionSettings(
            targetHeight = 480,
            targetVideoBitrateBps = 1_000_000
        )

        val QUALITY_720P = CompressionSettings(
            targetHeight = 720,
            targetVideoBitrateBps = 2_500_000
        )

        val QUALITY_1080P = CompressionSettings(
            targetHeight = 1080,
            targetVideoBitrateBps = 5_000_000
        )

        val DEFAULT = QUALITY_720P

        fun bitrateForHeight(targetHeight: Int): Int = when {
            targetHeight <= 0 -> DEFAULT_VIDEO_BITRATE_BPS
            targetHeight <= 480 -> QUALITY_480P.targetVideoBitrateBps
            targetHeight <= 720 -> QUALITY_720P.targetVideoBitrateBps
            else -> QUALITY_1080P.targetVideoBitrateBps
        }
    }
}
