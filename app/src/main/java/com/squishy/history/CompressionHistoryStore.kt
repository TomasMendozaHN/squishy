package com.squishy.history

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class HistoryEntry(
    val displayName: String,
    val status: String,
    val finishedAt: Long,
    val durationMs: Long,
    val detail: String? = null
)

object CompressionHistoryStore {

    private const val FILE_NAME = "squishy_history.json"
    private const val MAX_ENTRIES = 200

    const val STATUS_COMPLETED = "COMPLETED"
    const val STATUS_FAILED = "FAILED"
    const val STATUS_CANCELLED = "CANCELLED"

    suspend fun load(context: Context): List<HistoryEntry> = withContext(Dispatchers.IO) {
        val file = File(context.filesDir, FILE_NAME)
        if (!file.exists()) return@withContext emptyList()
        try {
            val arr = JSONArray(file.readText())
            val list = ArrayList<HistoryEntry>(arr.length())
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                list += HistoryEntry(
                    displayName = o.optString("name"),
                    status = o.optString("status"),
                    finishedAt = o.optLong("finishedAt"),
                    durationMs = o.optLong("durationMs"),
                    detail = o.optString("detail", "")
                        .takeIf { it.isNotEmpty() }
                )
            }
            list
        } catch (_: Throwable) {
            emptyList()
        }
    }

    suspend fun append(context: Context, entry: HistoryEntry) = withContext(Dispatchers.IO) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            val arr = if (file.exists()) JSONArray(file.readText()) else JSONArray()
            arr.put(
                JSONObject()
                    .put("name", entry.displayName)
                    .put("status", entry.status)
                    .put("finishedAt", entry.finishedAt)
                    .put("durationMs", entry.durationMs)
                    .put("detail", entry.detail.orEmpty())
            )
            while (arr.length() > MAX_ENTRIES) arr.remove(0)
            file.writeText(arr.toString())
        } catch (_: Throwable) {
        }
    }

    suspend fun clear(context: Context) = withContext(Dispatchers.IO) {
        try {
            File(context.filesDir, FILE_NAME).delete()
        } catch (_: Throwable) {
        }
    }
}
