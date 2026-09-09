package com.squishy.data

import android.content.Context
import android.net.Uri
import android.provider.MediaStore
import com.squishy.model.VideoItem

class VideoRepository(private val context: Context) {

    fun loadVideos(): List<VideoItem> {
        val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_MODIFIED,
            MediaStore.Video.Media.DURATION
        )
        val mediaStoreOrder = "${MediaStore.Video.Media.DATE_MODIFIED} DESC"

        val cursor = context.contentResolver.query(
            collection,
            projection,
            null,
            null,
            mediaStoreOrder
        ) ?: return emptyList()

        return cursor.use { c ->
            val idIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val nameIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val sizeIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val dateIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_MODIFIED)
            val durationIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            val result = mutableListOf<VideoItem>()
            while (c.moveToNext()) {
                val size = c.getLong(sizeIndex)
                if (size <= 0L) continue
                val id = c.getLong(idIndex)
                result += VideoItem(
                    id = id,
                    displayName = c.getString(nameIndex).orEmpty(),
                    sizeBytes = size,
                    dateModified = c.getLong(dateIndex) * 1000L,
                    durationMs = c.getLong(durationIndex),
                    uri = Uri.withAppendedPath(collection, id.toString()).toString()
                )
            }
            result
        }
    }
}
