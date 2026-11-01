package com.squishy

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

enum class JobStatus { queued, running, done, failed, cancelled }

/** One compression or cut job. Mutated only on the main thread. */
class Job(
    val id: String,
    val kind: String,
    val input: String,
    var output: String,
    val width: Int,
    val height: Int,
    val videoBitrate: Int,
    val audioBitrate: Int,
    val mime: String,
    val segments: List<LongArray>,
    val deleteOriginal: Boolean,
    val inputSize: Long,
    val expectedDurationMs: Long,
    val estimatedBytes: Long,
    val qualityLabel: String,
    val codecLabel: String,
) {
    var status = JobStatus.queued
    var progress = 0.0
    var error: String? = null
    var startedAt = 0L
    var finishedAt = 0L
    var outputSize = 0L
    var originalDeleted = false

    /** Times this job was retried after a codec/muxer failure. */
    var attempts = 0

    /** Run with nothing else in parallel (set when retrying). */
    var solo = false

    val isCut get() = kind == "cut"
    val tempPath get() = "$output.squishy-tmp.mp4"
    val name get() = input.substringAfterLast('/')

    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "kind" to kind,
        "input" to input,
        "output" to output,
        "status" to status.name,
        "progress" to progress,
        "error" to error,
        "inputSize" to inputSize,
        "outputSize" to outputSize,
        "estimatedBytes" to estimatedBytes,
        "startedAt" to startedAt,
        "finishedAt" to finishedAt,
        "qualityLabel" to qualityLabel,
    )

    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id); put("kind", kind); put("input", input); put("output", output)
        put("width", width); put("height", height)
        put("videoBitrate", videoBitrate); put("audioBitrate", audioBitrate)
        put("mime", mime)
        put("segments", JSONArray().apply { segments.forEach { put(JSONArray(listOf(it[0], it[1]))) } })
        put("deleteOriginal", deleteOriginal); put("inputSize", inputSize)
        put("expectedDurationMs", expectedDurationMs); put("estimatedBytes", estimatedBytes)
        put("qualityLabel", qualityLabel); put("codecLabel", codecLabel)
        put("attempts", attempts); put("solo", solo)
    }

    fun toLogJson(): JSONObject = JSONObject().apply {
        put("id", id); put("kind", kind); put("input", input); put("output", output)
        put("success", status == JobStatus.done)
        put("error", error ?: JSONObject.NULL)
        put("inputSize", inputSize); put("outputSize", outputSize)
        put("startedAt", startedAt); put("finishedAt", finishedAt)
        put("qualityLabel", qualityLabel); put("codecLabel", codecLabel)
        put("originalDeleted", originalDeleted)
    }

    companion object {
        fun fromMap(m: Map<*, *>): Job = Job(
            id = m["id"] as String,
            kind = m["kind"] as? String ?: "compress",
            input = m["input"] as String,
            output = m["output"] as String,
            width = (m["width"] as Number).toInt(),
            height = (m["height"] as Number).toInt(),
            videoBitrate = (m["videoBitrate"] as Number).toInt(),
            audioBitrate = (m["audioBitrate"] as Number).toInt(),
            mime = m["mime"] as String,
            segments = (m["segments"] as? List<*>).orEmpty().map { seg ->
                val s = seg as List<*>
                longArrayOf((s[0] as Number).toLong(), (s[1] as Number).toLong())
            },
            deleteOriginal = m["deleteOriginal"] as? Boolean ?: false,
            inputSize = (m["inputSize"] as? Number)?.toLong() ?: File(m["input"] as String).length(),
            expectedDurationMs = (m["expectedDurationMs"] as? Number)?.toLong() ?: 0L,
            estimatedBytes = (m["estimatedBytes"] as? Number)?.toLong() ?: 0L,
            qualityLabel = m["qualityLabel"] as? String ?: "",
            codecLabel = m["codecLabel"] as? String ?: "",
        )

        fun fromJson(o: JSONObject): Job {
            val segs = o.optJSONArray("segments") ?: JSONArray()
            return Job(
                id = o.getString("id"),
                kind = o.optString("kind", "compress"),
                input = o.getString("input"),
                output = o.getString("output"),
                width = o.getInt("width"),
                height = o.getInt("height"),
                videoBitrate = o.getInt("videoBitrate"),
                audioBitrate = o.getInt("audioBitrate"),
                mime = o.getString("mime"),
                segments = (0 until segs.length()).map {
                    val s = segs.getJSONArray(it); longArrayOf(s.getLong(0), s.getLong(1))
                },
                deleteOriginal = o.optBoolean("deleteOriginal"),
                inputSize = o.optLong("inputSize"),
                expectedDurationMs = o.optLong("expectedDurationMs"),
                estimatedBytes = o.optLong("estimatedBytes"),
                qualityLabel = o.optString("qualityLabel"),
                codecLabel = o.optString("codecLabel"),
            ).apply {
                attempts = o.optInt("attempts")
                solo = o.optBoolean("solo")
            }
        }
    }
}

/**
 * Process-wide job state shared by [CompressionService] and [MainActivity].
 * Unfinished jobs are persisted to queue.json so a restarted service resumes them;
 * finished jobs are appended to log.json.
 */
object JobManager {
    private const val MAX_LOG = 2000

    private lateinit var queueFile: File
    private lateinit var logFile: File
    private val main = Handler(Looper.getMainLooper())

    val jobs = LinkedHashMap<String, Job>()
    var parallel = 1
    private val listeners = mutableSetOf<() -> Unit>()
    private var notifyPending = false
    private var loaded = false

    fun init(context: Context) {
        if (loaded) return
        loaded = true
        queueFile = File(context.filesDir, "queue.json")
        logFile = File(context.filesDir, "log.json")
        val prefs = context.getSharedPreferences("squishy_native", Context.MODE_PRIVATE)
        parallel = prefs.getInt("parallel", 1)
        if (queueFile.exists()) {
            runCatching {
                val arr = JSONArray(queueFile.readText())
                for (i in 0 until arr.length()) {
                    val job = Job.fromJson(arr.getJSONObject(i))
                    // Anything that was mid-flight when the process died starts over.
                    File(job.tempPath).delete()
                    jobs[job.id] = job
                }
            }
        }
    }

    fun setParallel(context: Context, value: Int) {
        parallel = value.coerceIn(1, 3)
        context.getSharedPreferences("squishy_native", Context.MODE_PRIVATE)
            .edit().putInt("parallel", parallel).apply()
    }

    fun addListener(l: () -> Unit) { listeners += l }
    fun removeListener(l: () -> Unit) { listeners -= l }

    /** Coalesces bursts of changes into one UI update per frame-ish. */
    fun changed() {
        if (notifyPending) return
        notifyPending = true
        main.postDelayed({
            notifyPending = false
            listeners.toList().forEach { it() }
        }, 120)
    }

    fun enqueue(newJobs: List<Job>) {
        newJobs.forEach { jobs[it.id] = it }
        saveQueue()
        changed()
    }

    fun nextQueued(): Job? = jobs.values.firstOrNull { it.status == JobStatus.queued }
    fun running(): List<Job> = jobs.values.filter { it.status == JobStatus.running }
    fun hasWork(): Boolean = jobs.values.any { it.status == JobStatus.queued || it.status == JobStatus.running }

    fun finish(job: Job) {
        job.finishedAt = System.currentTimeMillis()
        appendLog(job)
        saveQueue()
        changed()
    }

    /** Cancels a job that no service is running yet (e.g. right after enqueue). */
    fun cancelQueued(id: String) {
        val job = jobs[id] ?: return
        if (job.status != JobStatus.queued) return
        job.status = JobStatus.cancelled
        job.error = "Cancelled"
        finish(job)
    }

    fun clearFinished() {
        jobs.values.removeAll { it.status != JobStatus.queued && it.status != JobStatus.running }
        changed()
    }

    fun snapshot(): List<Map<String, Any?>> = jobs.values.map { it.toMap() }

    fun saveQueue() {
        val arr = JSONArray()
        jobs.values.filter { it.status == JobStatus.queued || it.status == JobStatus.running }
            .forEach { arr.put(it.toJson()) }
        queueFile.writeText(arr.toString())
    }

    private fun appendLog(job: Job) {
        val arr = readLogArray()
        arr.put(job.toLogJson())
        val trimmed = if (arr.length() > MAX_LOG) {
            JSONArray().apply { for (i in arr.length() - MAX_LOG until arr.length()) put(arr.get(i)) }
        } else arr
        logFile.writeText(trimmed.toString())
    }

    private fun readLogArray(): JSONArray =
        if (logFile.exists()) runCatching { JSONArray(logFile.readText()) }.getOrElse { JSONArray() } else JSONArray()

    fun readLog(): String = readLogArray().toString()

    fun clearLog() { logFile.delete() }
}
