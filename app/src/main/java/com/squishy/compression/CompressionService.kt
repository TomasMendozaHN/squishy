package com.squishy.compression

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaCodecInfo
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.MediaStore
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.getSystemService
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultAudioMixer
import androidx.media3.transformer.DefaultDecoderFactory
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.ExoPlayerAssetLoader
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import com.squishy.MainActivity
import com.squishy.R
import java.io.File
import java.io.Serializable
import java.util.concurrent.Executors
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

@OptIn(UnstableApi::class)
class CompressionService : Service() {

    companion object {
        const val ACTION_START = "com.squishy.action.COMPRESS"
        const val ACTION_STOP = "com.squishy.action.STOP"
        const val EXTRA_URI = "extra_uri"
        const val EXTRA_NAME = "extra_name"
        const val EXTRA_SIZE = "extra_size"
        const val EXTRA_DURATION = "extra_duration"
        const val EXTRA_QUEUED = "extra_queued"

        const val CHANNEL_ID = "compression"
        const val NOTIFICATION_ID = 1001

        private val _currentJobState = MutableStateFlow<CompressionJobState?>(null)
        val currentJobState: StateFlow<CompressionJobState?> =
            _currentJobState.asStateFlow()

        private val _queue = MutableStateFlow<List<CompressionJobState>>(emptyList())
        val queue: StateFlow<List<CompressionJobState>> = _queue.asStateFlow()

        private const val TARGET_VIDEO_BITRATE_BPS = 2_500_000
        private const val TARGET_AUDIO_BITRATE_BPS = 128_000
        private const val PROGRESS_POLL_MS = 500L
        private const val DONE_NOTIFICATION_MS = 5_000L
        private const val STOP_NOTIFICATION_MS = 2_000L

        fun startCompressing(context: Context, video: com.squishy.model.VideoItem) {
            val intent = Intent(context, CompressionService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_URI, video.uri)
                putExtra(EXTRA_NAME, video.displayName)
                putExtra(EXTRA_SIZE, video.sizeBytes)
                putExtra(EXTRA_DURATION, video.durationMs)
            }
            context.startForegroundService(intent)
        }

        fun enqueueCompressing(context: Context, videos: List<com.squishy.model.VideoItem>) {
            if (videos.isEmpty()) return
            val intent = Intent(context, CompressionService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_QUEUED, videos as Serializable)
            }
            context.startForegroundService(intent)
        }

        fun stopCompressing(context: Context) {
            context.startForegroundService(
                Intent(context, CompressionService::class.java).setAction(ACTION_STOP)
            )
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { r -> Thread(r, "squishy-io") }
    private var transformer: Transformer? = null
    private var activeJob: CompressionJob? = null
    private var outputPath: String? = null
    private val queuedJobs = mutableListOf<CompressionJob>()

    private fun publishQueue() {
        _queue.value = queuedJobs.map {
            CompressionJobState(job = it, status = CompressionStatus.QUEUED)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    private val transformerListener = object : Transformer.Listener {
        override fun onCompleted(composition: Composition, exportResult: ExportResult) {
            val job = activeJob ?: return
            val path = outputPath
            cancelProgressPoll()
            _currentJobState.value = CompressionJobState(
                job = job,
                status = CompressionStatus.COMPLETED,
                progress = 100,
                outputPath = path
            )
            postNotification(
                title = getString(R.string.notification_done_title),
                text = getString(R.string.notification_done_text, job.displayName),
                percent = 100,
                showStop = false
            )
            if (path != null) {
                worker.execute { registerInMediaStore(File(path), job.displayName) }
            }
            advanceQueue()
        }

        override fun onError(
            composition: Composition,
            exportResult: ExportResult,
            exportException: ExportException
        ) {
            val job = activeJob ?: return
            cancelProgressPoll()
            _currentJobState.value = CompressionJobState(
                job = job,
                status = CompressionStatus.FAILED,
                errorMessage = exportException.getErrorCodeName()
            )
            postNotification(
                title = getString(R.string.notification_failed_title),
                text = getString(R.string.notification_failed_text, job.displayName),
                percent = null,
                showStop = false
            )
            advanceQueue()
        }
    }

    private fun queueLabel(): String {
        return if (queuedJobs.isEmpty()) {
            ""
        } else {
            getString(R.string.notification_queue_remaining, queuedJobs.size)
        }
    }

    private fun advanceQueue() {
        publishQueue()
        if (queuedJobs.isEmpty()) {
            mainHandler.postDelayed({
                _currentJobState.value = null
                stopSelf()
            }, DONE_NOTIFICATION_MS)
        } else {
            mainHandler.postDelayed({ startNextInQueue() }, 500L)
        }
    }

    private val progressPoll = object : Runnable {
        override fun run() {
            val transformerInstance = transformer ?: return
            val job = activeJob ?: return
            try {
                val holder = ProgressHolder()
                val state = transformerInstance.getProgress(holder)
                if (state == Transformer.PROGRESS_STATE_AVAILABLE) {
                    val percent = holder.progress.coerceIn(0, 100)
                    _currentJobState.value = CompressionJobState(
                        job = job,
                        status = CompressionStatus.RUNNING,
                        progress = percent
                    )
                    postNotification(
                        title = getString(R.string.notification_working_title),
                        text = getString(
                            R.string.notification_compressing_text,
                            job.displayName
                        ) + queueLabel(),
                        percent = percent,
                        showStop = true
                    )
                }
            } catch (_: Throwable) {
            }
            mainHandler.postDelayed(this, PROGRESS_POLL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification(
                title = getString(R.string.notification_working_title),
                text = getString(R.string.notification_started_text),
                percent = null,
                showStop = true
            ),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING
        )
        when (intent?.action) {
            ACTION_START -> {
                @Suppress("UNCHECKED_CAST")
                val queued = intent.getSerializableExtra(EXTRA_QUEUED) as? ArrayList<com.squishy.model.VideoItem>
                if (queued != null && queued.isNotEmpty()) {
                    enqueue(queued)
                } else {
                    val uri = intent.getStringExtra(EXTRA_URI).orEmpty()
                    if (uri.isEmpty()) {
                        stopSelf()
                        return START_NOT_STICKY
                    }
                    val job = CompressionJob(
                        id = Uri.parse(uri).lastPathSegment?.toLongOrNull() ?: 0L,
                        inputUri = uri,
                        displayName = intent.getStringExtra(EXTRA_NAME).orEmpty(),
                        sizeBytes = intent.getLongExtra(EXTRA_SIZE, 0L),
                        durationMs = intent.getLongExtra(EXTRA_DURATION, 0L)
                    )
                    enqueueJobs(listOf(job))
                }
            }
            ACTION_STOP -> stopEverything()
        }
        return START_NOT_STICKY
    }

    private fun enqueue(videos: List<com.squishy.model.VideoItem>) {
        val jobs = videos.map { video ->
            CompressionJob(
                id = Uri.parse(video.uri).lastPathSegment?.toLongOrNull() ?: 0L,
                inputUri = video.uri,
                displayName = video.displayName,
                sizeBytes = video.sizeBytes,
                durationMs = video.durationMs
            )
        }
        enqueueJobs(jobs)
    }

    private fun enqueueJobs(jobs: List<CompressionJob>) {
        if (jobs.isEmpty()) return
        val busy = activeJob != null
        if (busy) {
            queuedJobs.addAll(jobs)
        } else {
            jobs.firstOrNull()?.let { startJob(it) }
            queuedJobs.addAll(jobs.drop(1))
        }
        publishQueue()
    }

    private fun startNextInQueue() {
        val job = queuedJobs.removeFirstOrNull()
        if (job == null) {
            return
        }
        startJob(job)
    }

    override fun onDestroy() {
        cancelProgressPoll()
        try {
            transformer?.cancel()
        } catch (_: Throwable) {
        }
        transformer = null
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun startJob(job: CompressionJob) {
        activeJob = job
        val path = outputFilePath(job)
        outputPath = path
        _currentJobState.value = CompressionJobState(
            job = job,
            status = CompressionStatus.RUNNING,
            progress = 0
        )
        val transformerInstance = buildTransformer()
        transformer = transformerInstance
        transformerInstance.addListener(transformerListener)
        postNotification(
            title = getString(R.string.notification_working_title),
            text = getString(R.string.notification_compressing_text, job.displayName),
            percent = 0,
            showStop = true
        )
        try {
            transformerInstance.start(MediaItem.fromUri(Uri.parse(job.inputUri)), path)
            startProgressPoll()
        } catch (e: Throwable) {
            transformer = null
            cancelProgressPoll()
            _currentJobState.value = CompressionJobState(
                job = job,
                status = CompressionStatus.FAILED,
                errorMessage = e.message ?: "compression failed"
            )
            postNotification(
                title = getString(R.string.notification_failed_title),
                text = getString(R.string.notification_failed_text, job.displayName),
                percent = null,
                showStop = false
            )
            advanceQueue()
        }
    }

    private fun buildTransformer(): Transformer {
        val videoSettings = VideoEncoderSettings.Builder()
            .setBitrate(TARGET_VIDEO_BITRATE_BPS)
            .setBitrateMode(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR)
            .build()
        val audioSettings = AudioEncoderSettings.Builder()
            .setBitrate(TARGET_AUDIO_BITRATE_BPS)
            .build()
        val encoderFactory = DefaultEncoderFactory.Builder(this)
            .setRequestedVideoEncoderSettings(videoSettings)
            .setRequestedAudioEncoderSettings(audioSettings)
            .build()
        return Transformer.Builder(this)
            .setAssetLoaderFactory(
                ExoPlayerAssetLoader.Factory(this, DefaultDecoderFactory(this), androidx.media3.common.util.Clock.DEFAULT)
            )
            .setEncoderFactory(encoderFactory)
            .setAudioMixerFactory(DefaultAudioMixer.Factory())
            .build()
    }

    private fun startProgressPoll() {
        cancelProgressPoll()
        mainHandler.postDelayed(progressPoll, PROGRESS_POLL_MS)
    }

    private fun stopEverything() {
        cancelProgressPoll()
        try {
            transformer?.cancel()
        } catch (_: Throwable) {
        }
        transformer = null
        activeJob?.let {
            _currentJobState.value = CompressionJobState(it, CompressionStatus.CANCELLED)
        }
        activeJob = null
        outputPath = null
        queuedJobs.clear()
        publishQueue()
        postNotification(
            title = getString(R.string.notification_working_title),
            text = getString(R.string.notification_stopped_text),
            percent = null,
            showStop = false
        )
        mainHandler.postDelayed({
            _currentJobState.value = null
            stopSelf()
        }, STOP_NOTIFICATION_MS)
    }

    private fun registerInMediaStore(output: File, displayName: String) {
        try {
            val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            val insertValues = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, output.name)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(MediaStore.Video.Media.SIZE, output.length())
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(collection, insertValues) ?: return
            contentResolver.openOutputStream(uri)?.use { out ->
                output.inputStream().use { it.copyTo(out) }
            }
            val doneValues = ContentValues().apply {
                put(MediaStore.Video.Media.IS_PENDING, 0)
            }
            contentResolver.update(uri, doneValues, null, null)
            output.delete()
        } catch (_: Throwable) {
        }
    }

    private fun outputFilePath(job: CompressionJob): String {
        val dir = File(getExternalFilesDir(Environment.DIRECTORY_MOVIES), "squishy")
        if (!dir.exists()) dir.mkdirs()
        val base = job.displayName
            .substringBeforeLast('.')
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .ifEmpty { "video" }
        return File(dir, "${base}_squishy.mp4").absolutePath
    }

    private fun createNotificationChannel() {
        val manager = getSystemService<NotificationManager>() ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_LOW
        )
        channel.setShowBadge(false)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(
        title: String,
        text: String,
        percent: Int?,
        showStop: Boolean
    ): Notification {
        val openIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentIntent(openIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        if (percent != null) {
            builder.setProgress(100, percent, false)
        }
        if (showStop) {
            val stopIntent = PendingIntent.getService(
                this,
                1,
                Intent(this, CompressionService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(0, getString(R.string.notification_stop_action), stopIntent)
        }
        return builder.build()
    }

    private fun postNotification(
        title: String,
        text: String,
        percent: Int?,
        showStop: Boolean
    ) {
        getSystemService<NotificationManager>()
            ?.notify(NOTIFICATION_ID, buildNotification(title, text, percent, showStop))
    }

    private fun cancelProgressPoll() {
        mainHandler.removeCallbacks(progressPoll)
    }
}
