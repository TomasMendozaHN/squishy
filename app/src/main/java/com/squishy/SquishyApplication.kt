package com.squishy

import android.app.Application
import android.os.Build

class SquishyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        CrashLogger.init(this)
        CrashLogger.log(
            "app",
            "started version=${BuildConfig.VERSION_NAME} (code ${BuildConfig.VERSION_CODE}) " +
                "sdk=${Build.VERSION.SDK_INT} device=${Build.MANUFACTURER}/${Build.MODEL}"
        )
    }
}
