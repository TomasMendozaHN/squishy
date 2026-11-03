package com.squishy

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.PowerManager
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * Finds out why Android closed Squishy. Android keeps the reason for every process exit
 * (crash, not responding, low memory, killed by the system's battery/heat manager...); on
 * the next start each new one becomes an "App closed" entry in History with the phone's
 * last known state (temperature, memory), so "Send details" can say what happened.
 */
object ExitReasons {
    private const val PREFS = "squishy_exit"

    /** Exits that are expected: the user closed the app, an update, the app stopping itself. */
    private val EXPECTED = setOf(
        ApplicationExitInfo.REASON_USER_REQUESTED,
        ApplicationExitInfo.REASON_USER_STOPPED,
        ApplicationExitInfo.REASON_PACKAGE_UPDATED,
        ApplicationExitInfo.REASON_EXIT_SELF,
    )

    private var crashFile: File? = null
    private var stateFile: File? = null

    fun init(context: Context) {
        crashFile = File(context.filesDir, "last_crash.txt")
        stateFile = File(context.filesDir, "last_state.txt")
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, e ->
            if (thread.name.startsWith("Transformer:")) {
                // Media3 can throw on its own thread while a stopped export winds down after a
                // stuck codec comes back (a failed check in TransformerInternal.endInternal).
                // That export was already given up; only its thread ends, not the whole app.
                // A live export that loses its thread is caught by the stall detector.
                Log.w("Squishy", "Media3 thread ${thread.name} died", e)
                return@setDefaultUncaughtExceptionHandler
            }
            runCatching { crashFile?.writeText("${thread.name}: ${e.stackTraceToString().take(4000)}") }
            previous?.uncaughtException(thread, e)
        }
        runCatching { record(context) }
    }

    private fun record(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val seen = prefs.getLong("seen", 0L)
        val infos = context.getSystemService(ActivityManager::class.java)
            .getHistoricalProcessExitReasons(null, 0, 10)
            .filter { it.timestamp > seen }
        if (infos.isEmpty()) return
        prefs.edit().putLong("seen", infos.maxOf { it.timestamp }).apply()
        // First run with this feature: only report what happened in the last day.
        val since = if (seen == 0L) System.currentTimeMillis() - 24 * 3600_000L else 0L
        val state = stateFile?.takeIf { it.exists() }?.readText()
        val crash = crashFile?.takeIf { it.exists() }?.readText()
        crashFile?.delete()
        val working = runCatching {
            org.json.JSONArray(File(context.filesDir, "queue.json").readText()).getJSONObject(0).getString("input")
        }.getOrNull()
        for (info in infos.sortedBy { it.timestamp }) {
            if (info.reason in EXPECTED || info.timestamp < since) continue
            val diag = buildList {
                state?.let { add("Last state: $it") }
                add("Memory when closed: ${info.pss / 1024} MB (PSS), ${info.rss / 1024} MB (RSS)")
                if (info.reason == ApplicationExitInfo.REASON_CRASH) crash?.let { add(it) }
                if (info.reason == ApplicationExitInfo.REASON_ANR) trace(info)?.let { add(it) }
            }.joinToString("\n")
            JobManager.appendLogJson(JSONObject().apply {
                put("id", "exit-${info.timestamp}"); put("kind", "crash")
                put("input", working ?: "Squishy"); put("output", "")
                put("success", false)
                put("error", "${reasonName(info.reason)} while ${importanceName(info.importance)}" +
                    (info.description?.let { " · $it" } ?: ""))
                put("inputSize", 0); put("outputSize", 0)
                put("startedAt", info.timestamp); put("finishedAt", info.timestamp)
                put("qualityLabel", ""); put("codecLabel", "")
                put("originalDeleted", false)
                put("diag", diag)
            })
        }
    }

    /** The main thread's stack from a "not responding" report: shows what it was stuck on. */
    private fun trace(info: ApplicationExitInfo): String? = runCatching {
        val lines = info.traceInputStream?.bufferedReader()?.readLines() ?: return null
        val start = lines.indexOfFirst { it.startsWith("\"main\"") }
        if (start < 0) null else lines.drop(start).takeWhile { it.isNotBlank() }.take(25).joinToString("\n")
    }.getOrNull()

    /** Saves temperature, heat level, charging and memory; the last one is kept for a crash report. */
    fun saveState(context: Context) {
        runCatching {
            val battery = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val temp = (battery?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0) / 10.0
            val plugged = (battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0
            val thermal = when (context.getSystemService(PowerManager::class.java).currentThermalStatus) {
                PowerManager.THERMAL_STATUS_NONE -> "normal"
                PowerManager.THERMAL_STATUS_LIGHT -> "warm"
                PowerManager.THERMAL_STATUS_MODERATE -> "hot (moderate)"
                PowerManager.THERMAL_STATUS_SEVERE -> "hot (severe)"
                PowerManager.THERMAL_STATUS_CRITICAL -> "critical heat"
                PowerManager.THERMAL_STATUS_EMERGENCY -> "heat emergency"
                else -> "heat shutdown"
            }
            val mem = ActivityManager.MemoryInfo().also { context.getSystemService(ActivityManager::class.java).getMemoryInfo(it) }
            val time = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.US).format(java.util.Date())
            stateFile?.writeText(
                "$time · battery %.1f °C%s · heat: $thermal · free RAM %d MB of %d MB%s".format(
                    java.util.Locale.US, temp, if (plugged) " (charging)" else "", mem.availMem shr 20, mem.totalMem shr 20,
                    if (mem.lowMemory) " (low!)" else "",
                )
            )
        }
    }

    private fun reasonName(reason: Int) = when (reason) {
        ApplicationExitInfo.REASON_CRASH -> "Squishy crashed"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "Squishy crashed (native code)"
        ApplicationExitInfo.REASON_ANR -> "Squishy froze (not responding) and Android closed it"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "Android closed Squishy to free memory"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "Android closed Squishy for using too much CPU/battery"
        ApplicationExitInfo.REASON_FREEZER -> "Android froze and closed Squishy"
        ApplicationExitInfo.REASON_SIGNALED -> "Squishy was killed by the system"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "Android closed Squishy after a permission change"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "Squishy failed to start"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "A system service Squishy uses died"
        else -> "Android closed Squishy (reason $reason)"
    }

    private fun importanceName(importance: Int) = when {
        importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND -> "on screen"
        importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND_SERVICE -> "working in the background"
        importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE -> "visible"
        else -> "in the background"
    }
}
