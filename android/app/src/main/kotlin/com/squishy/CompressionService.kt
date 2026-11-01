@file:OptIn(UnstableApi::class)

package com.squishy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import com.squishy.nas.NasRunner
import java.io.File
import kotlin.math.abs
import kotlin.math.max

/**
 * Runs the job queue. It is a foreground service of type specialUse, holds a
 * partial wake lock while working and is START_STICKY, so it keeps going with the
 * app in the background, the screen off, or the task swiped away.
 */
class CompressionService : Service() {

    companion object {
        const val ACTION_PUMP = "com.squishy.PUMP"
        const val ACTION_CANCEL_ALL = "com.squishy.CANCEL_ALL"
        private const val CHANNEL_WORK = "squishing"
        private const val CHANNEL_DONE = "finished"
        private const val NOTIFICATION_WORK = 1
        private const val NOTIFICATION_DONE = 2

        fun start(context: Context, action: String = ACTION_PUMP) {
            context.startForegroundService(Intent(context, CompressionService::class.java).setAction(action))
        }

        /** Resource-contention failures that usually succeed when the job runs alone. */
        private val RETRYABLE = setOf(
            ExportException.ERROR_CODE_MUXING_TIMEOUT,
            ExportException.ERROR_CODE_MUXING_FAILED,
            ExportException.ERROR_CODE_ENCODER_INIT_FAILED,
            ExportException.ERROR_CODE_ENCODING_FAILED,
            ExportException.ERROR_CODE_DECODER_INIT_FAILED,
            ExportException.ERROR_CODE_DECODING_FAILED,
            ExportException.ERROR_CODE_VIDEO_FRAME_PROCESSING_FAILED,
        )

        /** Live transformers, so the activity can cancel a single job. */
        val active = mutableMapOf<String, Transformer>()
        var instance: CompressionService? = null
    }

    private val main = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    private val progressHolder = ProgressHolder()
    private var sessionDone = 0
    private var sessionFailed = 0
    private var sessionSaved = 0L

    private val ticker = object : Runnable {
        override fun run() {
            pollProgress()
            main.postDelayed(this, 500)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        JobManager.init(this)
        NasRunner.init(this)
        createChannels()
        goForeground()
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "squishy:compress")
            .apply { setReferenceCounted(false); acquire() }
        main.post(ticker)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Must be called promptly on every start; the type is passed explicitly
        // (v1 crashed on Android 16 when it wasn't).
        goForeground()
        if (intent?.action == ACTION_CANCEL_ALL) cancelAll()
        pump()
        return START_STICKY
    }

    override fun onDestroy() {
        main.removeCallbacks(ticker)
        active.values.forEach { it.cancel() }
        active.clear()
        wakeLock?.let { if (it.isHeld) it.release() }
        instance = null
        super.onDestroy()
    }

    private fun goForeground() {
        startForeground(NOTIFICATION_WORK, buildWorkNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
    }

    /** Starts queued jobs until the parallel limit is reached; stops when idle. */
    fun pump() {
        while (active.size < JobManager.parallel) {
            // The NAS run's encode step shares the same hardware encoder.
            if (NasRunner.encoding) break
            // A job retrying on its own gets the hardware encoder to itself.
            if (active.keys.any { JobManager.jobs[it]?.solo == true }) break
            val job = JobManager.nextQueued() ?: break
            if (job.solo && active.isNotEmpty()) break
            startJob(job)
        }
        NasRunner.kick()
        if (active.isEmpty() && !JobManager.hasWork() && !NasRunner.active) finishSession()
        JobManager.changed()
    }

    private fun startJob(job: Job) {
        job.status = JobStatus.running
        job.startedAt = System.currentTimeMillis()
        job.progress = 0.0
        try {
            val input = File(job.input)
            if (!input.exists()) throw IllegalStateException("Source file no longer exists")
            File(job.output).parentFile?.mkdirs()
            File(job.tempPath).delete()
            val transformer = buildTransformer(job)
            active[job.id] = transformer
            transformer.start(buildComposition(job), job.tempPath)
        } catch (t: Throwable) {
            active.remove(job.id)
            fail(job, t.message ?: t.javaClass.simpleName)
        }
    }

    private fun buildTransformer(job: Job): Transformer {
        val encoderFactory = DefaultEncoderFactory.Builder(this)
            .setRequestedVideoEncoderSettings(
                VideoEncoderSettings.Builder().setBitrate(job.videoBitrate).build()
            )
            .setRequestedAudioEncoderSettings(
                AudioEncoderSettings.Builder().setBitrate(max(job.audioBitrate, 64000)).build()
            )
            .setEnableFallback(true)
            .build()
        val mime = if (job.mime == MimeTypes.VIDEO_H265 && !MediaTools.hasHevcEncoder()) MimeTypes.VIDEO_H264 else job.mime
        return Transformer.Builder(this)
            .setVideoMimeType(mime)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoderFactory)
            .setLooper(Looper.getMainLooper())
            // Media3 aborts if the muxer gets no samples for ~10 s. Encoders shared by
            // parallel jobs (or throttled with the screen off) can legitimately stall
            // longer, which caused ERROR_CODE_MUXING_TIMEOUT on real phones.
            .setMaxDelayBetweenMuxerSamplesMs(
                if (job.solo || JobManager.parallel == 1) 60_000L else 180_000L
            )
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    active.remove(job.id)
                    complete(job)
                    pump()
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    active.remove(job.id)
                    if (job.status == JobStatus.running) {
                        if (job.attempts == 0 && exportException.errorCode in RETRYABLE) {
                            retrySolo(job)
                        } else {
                            val retried = if (job.attempts > 0) " (also failed when retried on its own)" else ""
                            fail(job, "${exportException.errorCodeName}: ${exportException.message ?: "export failed"}$retried")
                        }
                    }
                    pump()
                }
            })
            .build()
    }

    private fun buildComposition(job: Job): Composition {
        val uri = Uri.fromFile(File(job.input))
        val effects = Effects(
            emptyList(),
            listOf(Presentation.createForWidthAndHeight(job.width, job.height, Presentation.LAYOUT_SCALE_TO_FIT)),
        )
        val mediaItems = if (job.segments.isEmpty()) {
            listOf(MediaItem.fromUri(uri))
        } else {
            job.segments.map { (start, end) ->
                MediaItem.Builder()
                    .setUri(uri)
                    .setClippingConfiguration(
                        MediaItem.ClippingConfiguration.Builder()
                            .setStartPositionMs(start)
                            .setEndPositionMs(end)
                            .build()
                    )
                    .build()
            }
        }
        val edited = mediaItems.map { EditedMediaItem.Builder(it).setEffects(effects).build() }
        val sequence = EditedMediaItemSequence.Builder(edited).build()
        return Composition.Builder(sequence)
            // Phone cameras often record HDR; SDR output is smaller and plays everywhere.
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
            .build()
    }

    /** Verifies the output, moves it into place and deletes the original if asked. */
    private fun complete(job: Job) {
        val temp = File(job.tempPath)
        if (!temp.exists() || temp.length() == 0L) {
            temp.delete(); fail(job, "Output file is empty"); return
        }
        val outDuration = readDurationMs(temp)
        if (job.expectedDurationMs > 0) {
            val tolerance = max(2000L, job.expectedDurationMs / 20)
            if (outDuration <= 0 || abs(outDuration - job.expectedDurationMs) > tolerance) {
                temp.delete()
                fail(job, "Verification failed: output is ${outDuration / 1000}s, expected ${job.expectedDurationMs / 1000}s")
                return
            }
        }
        if (!job.isCut && temp.length() >= job.inputSize) {
            val outSize = temp.length()
            temp.delete()
            fail(job, "No size gain (${MediaTools.formatBytes(outSize)} ≥ original ${MediaTools.formatBytes(job.inputSize)}). Original kept.")
            return
        }
        val target = uniqueFile(File(job.output))
        if (!temp.renameTo(target)) {
            temp.delete(); fail(job, "Could not write to ${target.parent}"); return
        }
        job.output = target.absolutePath
        job.outputSize = target.length()
        job.progress = 1.0
        job.status = JobStatus.done
        val scan = mutableListOf(target.absolutePath)
        if (job.deleteOriginal && !job.isCut) {
            job.originalDeleted = File(job.input).delete()
            if (!job.originalDeleted) job.error = "Compressed fine, but the original could not be deleted"
            scan += job.input
        }
        MediaScannerConnection.scanFile(this, scan.toTypedArray(), null, null)
        sessionDone++
        if (!job.isCut) sessionSaved += job.inputSize - job.outputSize
        JobManager.finish(job)
    }

    /** Puts a job back at the front of the queue to run alone, once. */
    private fun retrySolo(job: Job) {
        File(job.tempPath).delete()
        job.attempts++
        job.solo = true
        job.status = JobStatus.queued
        job.progress = 0.0
        JobManager.saveQueue()
        JobManager.changed()
    }

    private fun fail(job: Job, reason: String) {
        job.status = JobStatus.failed
        job.error = reason
        File(job.tempPath).delete()
        sessionFailed++
        JobManager.finish(job)
    }

    fun cancel(id: String) {
        val job = JobManager.jobs[id] ?: return
        if (job.status != JobStatus.queued && job.status != JobStatus.running) return
        active.remove(id)?.cancel()
        File(job.tempPath).delete()
        job.status = JobStatus.cancelled
        job.error = "Cancelled"
        JobManager.finish(job)
        pump()
    }

    fun cancelAll() {
        JobManager.jobs.values
            .filter { it.status == JobStatus.queued || it.status == JobStatus.running }
            .map { it.id }
            .forEach { id ->
                val job = JobManager.jobs[id]!!
                active.remove(id)?.cancel()
                File(job.tempPath).delete()
                job.status = JobStatus.cancelled
                job.error = "Cancelled"
                JobManager.finish(job)
            }
    }

    private fun pollProgress() {
        NasRunner.pollEncodeProgress()
        if (NasRunner.active) {
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_WORK, buildWorkNotification())
        }
        if (active.isEmpty()) return
        for ((id, transformer) in active) {
            val job = JobManager.jobs[id] ?: continue
            if (transformer.getProgress(progressHolder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                job.progress = progressHolder.progress / 100.0
            }
        }
        JobManager.changed()
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_WORK, buildWorkNotification())
    }

    private fun finishSession() {
        if (sessionDone + sessionFailed > 0) {
            val text = buildString {
                append("$sessionDone squished")
                if (sessionFailed > 0) append(", $sessionFailed failed")
                if (sessionSaved > 0) append(" · saved ${MediaTools.formatBytes(sessionSaved)}")
            }
            val n = Notification.Builder(this, CHANNEL_DONE)
                .setSmallIcon(R.drawable.ic_stat_squishy)
                .setContentTitle("All done!")
                .setContentText(text)
                .setContentIntent(openAppIntent())
                .setAutoCancel(true)
                .build()
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_DONE, n)
        }
        sessionDone = 0; sessionFailed = 0; sessionSaved = 0
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildWorkNotification(): Notification {
        val all = JobManager.jobs.values.toList()
        val running = all.filter { it.status == JobStatus.running }
        val queued = all.count { it.status == JobStatus.queued }
        val sessionJobs = all.filter { it.startedAt > 0 || it.status == JobStatus.queued }
        val overall = if (sessionJobs.isEmpty()) 0.0 else sessionJobs.sumOf {
            if (it.status == JobStatus.running) it.progress else if (it.status == JobStatus.queued) 0.0 else 1.0
        } / sessionJobs.size
        NasRunner.snapshot()?.takeIf { NasRunner.active && running.isEmpty() }?.let { nas ->
            val total = (nas["total"] as Int).coerceAtLeast(1)
            return Notification.Builder(this, CHANNEL_WORK)
                .setSmallIcon(R.drawable.ic_stat_squishy)
                .setContentTitle("NAS: ${nas["phase"]} · ${nas["current"]}")
                .setContentText("${nas["index"]} of ${nas["total"]} · saved ${MediaTools.formatBytes(nas["saved"] as Long)}")
                .setProgress(1000, ((nas["overall"] as Double) * 1000).toInt(), nas["status"] == "scanning" || total == 0)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
                .setContentIntent(openAppIntent())
                .build()
        }
        val title = when {
            running.isEmpty() -> "Getting ready…"
            running.size == 1 -> "Squishing ${running[0].name}"
            else -> "Squishing ${running.size} videos"
        }
        val text = buildString {
            append("${(overall * 100).toInt()}% overall")
            if (queued > 0) append(" · $queued waiting")
        }
        val cancel = PendingIntent.getService(
            this, 1,
            Intent(this, CompressionService::class.java).setAction(ACTION_CANCEL_ALL),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return Notification.Builder(this, CHANNEL_WORK)
            .setSmallIcon(R.drawable.ic_stat_squishy)
            .setContentTitle(title)
            .setContentText(text)
            .setProgress(100, (overall * 100).toInt(), running.isEmpty())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(openAppIntent())
            .addAction(Notification.Action.Builder(null, "Cancel all", cancel).build())
            .build()
    }

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        this, 0,
        Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE,
    )

    private fun createChannels() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_WORK, "Squishing progress", NotificationManager.IMPORTANCE_LOW)
        )
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_DONE, "Finished batches", NotificationManager.IMPORTANCE_DEFAULT)
        )
    }

    private fun readDurationMs(file: File): Long = runCatching {
        MediaMetadataRetriever().use { r ->
            r.setDataSource(file.absolutePath)
            r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0L
        }
    }.getOrDefault(0L)

    private fun uniqueFile(file: File): File {
        if (!file.exists()) return file
        val base = file.nameWithoutExtension
        val ext = file.extension
        var i = 1
        while (true) {
            val candidate = File(file.parentFile, "$base ($i).$ext")
            if (!candidate.exists()) return candidate
            i++
        }
    }
}
