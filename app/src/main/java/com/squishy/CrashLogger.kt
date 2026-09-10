package com.squishy

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object CrashLogger {

    private const val MAX_BYTES = 256 * 1024
    private const val KEEP_BYTES = 128 * 1024
    private val timeFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

    @Volatile
    private var appContext: Context? = null
    private val lock = Any()

    fun init(context: Context) {
        appContext = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                logException("uncaught on thread '${thread.name}'", thread.name, throwable)
            } catch (_: Throwable) {
            }
            previous?.uncaughtException(thread, throwable)
        }
    }

    fun log(tag: String, message: String) {
        synchronized(lock) {
            append("${timeFormat.format(Date())} [$tag] $message\n")
        }
    }

    fun logException(tag: String, threadName: String, throwable: Throwable) {
        val sb = StringBuilder()
        sb.append("EXCEPTION on thread '").append(threadName).append("': ")
        sb.append(throwable.javaClass.name)
        sb.append(": ").append(throwable.message).append('\n')
        for (element in throwable.stackTrace) {
            sb.append("    at ").append(element).append('\n')
        }
        var cause = throwable.cause
        var depth = 0
        while (cause != null && depth < 5) {
            sb.append("Caused by: ").append(cause.javaClass.name).append(": ").append(cause.message).append('\n')
            for (element in cause.stackTrace) {
                sb.append("    at ").append(element).append('\n')
            }
            cause = cause.cause
            depth++
        }
        log(tag, sb.toString())
    }

    fun dump(): String {
        val file = logFile() ?: return ""
        return try {
            if (file.exists()) file.readText() else ""
        } catch (_: Throwable) {
            ""
        }
    }

    fun clear() {
        synchronized(lock) {
            try {
                logFile()?.delete()
            } catch (_: Throwable) {
            }
        }
    }

    private fun logFile(): File? {
        val context = appContext ?: return null
        return File(context.filesDir, "squishy_log.txt")
    }

    private fun append(line: String) {
        val file = logFile() ?: return
        try {
            if (file.exists() && file.length() > MAX_BYTES) {
                val content = file.readText()
                val keepFrom = (content.length - KEEP_BYTES).coerceAtLeast(0)
                file.writeText(content.substring(keepFrom))
            }
            file.appendText(line)
        } catch (_: Throwable) {
        }
    }
}
