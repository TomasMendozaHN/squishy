package com.squishy

import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Bridge between Flutter and the native side. The UI only observes and sends
 * commands; the queue itself lives in [JobManager] / [CompressionService].
 */
class MainActivity : FlutterActivity() {

    private val io = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())
    private var jobsSink: EventChannel.EventSink? = null
    private val jobsListener: () -> Unit = { jobsSink?.success(JobManager.snapshot()) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        JobManager.init(applicationContext)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "squishy/native").setMethodCallHandler(::onCall)

        EventChannel(messenger, "squishy/jobs").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                jobsSink = events
                JobManager.addListener(jobsListener)
                events.success(JobManager.snapshot())
            }

            override fun onCancel(arguments: Any?) {
                JobManager.removeListener(jobsListener)
                jobsSink = null
            }
        })

        // If the queue survived a process death, make sure the service is back on it.
        if (JobManager.hasWork()) CompressionService.start(this)
    }

    override fun onDestroy() {
        JobManager.removeListener(jobsListener)
        io.shutdown()
        super.onDestroy()
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            val value = runCatching(work)
            main.post {
                value.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("native", it.message, null) },
                )
            }
        }
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = applicationContext
        when (call.method) {
            "deviceInfo" -> result.success(MediaTools.deviceInfo(ctx))
            "storageRoots" -> result.success(MediaTools.storageRoots(ctx))
            "probe" -> {
                val paths = call.argument<List<String>>("paths").orEmpty()
                background(result) { paths.map { MediaTools.probe(it) } }
            }
            "thumbnail" -> {
                val path = call.argument<String>("path")!!
                val size = call.argument<Int>("size") ?: 320
                background(result) { MediaTools.thumbnail(ctx, path, size) }
            }
            "frameAt" -> {
                val path = call.argument<String>("path")!!
                val time = (call.argument<Number>("timeMs") ?: 0).toLong()
                val size = call.argument<Int>("size") ?: 200
                background(result) { MediaTools.frameAt(ctx, path, time, size) }
            }
            "enqueue" -> {
                val maps = call.argument<List<Map<*, *>>>("jobs").orEmpty()
                call.argument<Int>("parallel")?.let { JobManager.setParallel(ctx, it) }
                JobManager.enqueue(maps.map(Job::fromMap))
                CompressionService.start(this)
                result.success(null)
            }
            "setParallel" -> {
                JobManager.setParallel(ctx, call.argument<Int>("value") ?: 2)
                CompressionService.instance?.pump()
                result.success(null)
            }
            "jobs" -> result.success(JobManager.snapshot())
            "cancel" -> {
                val id = call.argument<String>("id")!!
                CompressionService.instance?.cancel(id) ?: JobManager.cancelQueued(id)
                result.success(null)
            }
            "cancelAll" -> {
                CompressionService.instance?.let { it.cancelAll(); it.pump() }
                    ?: JobManager.jobs.keys.toList().forEach(JobManager::cancelQueued)
                result.success(null)
            }
            "clearFinished" -> {
                JobManager.clearFinished()
                result.success(null)
            }
            "log" -> background(result) { JobManager.readLog() }
            "clearLog" -> {
                JobManager.clearLog()
                result.success(null)
            }
            "setKeepScreenOn" -> {
                if (call.argument<Boolean>("on") == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
            "requestIgnoreBatteryOptimizations" -> result.success(MediaTools.requestIgnoreBatteryOptimizations(this))
            "openAutostart" -> result.success(MediaTools.openAutostart(this))
            "openBatterySaver" -> result.success(MediaTools.openBatterySaver(this))
            "openAppSettings" -> result.success(MediaTools.openAppSettings(this))
            "isXiaomi" -> result.success(MediaTools.isXiaomiFamily())
            "openVideo" -> result.success(MediaTools.openVideo(this, call.argument<String>("path")!!))
            "shareVideo" -> result.success(
                MediaTools.shareVideo(this, call.argument<String>("path")!!, call.argument<String>("target") ?: "any")
            )
            else -> result.notImplemented()
        }
    }
}
