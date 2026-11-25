package com.coffeehauslabs.nightingale_tv

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.ComponentCallbacks2
import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File

/** What the next launch needs to report how this one ended
 *  (crash-visibility D2, D5): the device's memory, Android's exit reason
 *  for the previous process, the trim levels' names, and the clean-exit
 *  mark. */
object CrashVisibility {
    /** Beside lib/reporting/session_record.dart's session.json. */
    private const val CLEAN_EXIT = "reports/clean_exit"

    /** `ActivityManager.MemoryInfo`, in bytes. A cheap binder call. */
    fun memoryInfo(context: Context): Map<String, Any> {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        return mapOf(
            "availMem" to info.availMem,
            "totalMem" to info.totalMem,
            "threshold" to info.threshold,
            "lowMemory" to info.lowMemory,
        )
    }

    /** Android 11+: the newest recorded exit of this app's process at or
     *  after [sinceMs] (the previous launch's start), or null. */
    fun exitReason(context: Context, sinceMs: Long): Map<String, Any?>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return try {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val exit = am.getHistoricalProcessExitReasons(context.packageName, 0, 5)
                .filter { it.timestamp >= sinceMs && it.processName == context.packageName }
                .maxByOrNull { it.timestamp } ?: return null
            mapOf(
                "reason" to reasonName(exit.reason),
                "description" to exit.description,
                "status" to exit.status,
                "pss" to exit.pss * 1024,
                "rss" to exit.rss * 1024,
                "timestamp" to exit.timestamp,
            )
        } catch (e: Exception) {
            Log.w("NightingaleTV", "exit reason unavailable: $e")
            null
        }
    }

    private fun reasonName(reason: Int): String = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) "unknown" else when (reason) {
        ApplicationExitInfo.REASON_EXIT_SELF -> "exit_self"
        ApplicationExitInfo.REASON_SIGNALED -> "signaled"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "low_memory"
        ApplicationExitInfo.REASON_CRASH -> "crash"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "crash_native"
        ApplicationExitInfo.REASON_ANR -> "anr"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "initialization_failure"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "permission_change"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "excessive_resource_usage"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "user_requested"
        ApplicationExitInfo.REASON_USER_STOPPED -> "user_stopped"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "dependency_died"
        ApplicationExitInfo.REASON_OTHER -> "other"
        else -> when (reason) {
            14 -> "freezer"
            15 -> "package_state_change"
            16 -> "package_updated"
            else -> "unknown_$reason"
        }
    }

    /** `onTrimMemory`'s level, by name. */
    @Suppress("DEPRECATION")
    fun trimLevelName(level: Int): String = when (level) {
        ComponentCallbacks2.TRIM_MEMORY_RUNNING_MODERATE -> "RUNNING_MODERATE"
        ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW -> "RUNNING_LOW"
        ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL -> "RUNNING_CRITICAL"
        ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN -> "UI_HIDDEN"
        ComponentCallbacks2.TRIM_MEMORY_BACKGROUND -> "BACKGROUND"
        ComponentCallbacks2.TRIM_MEMORY_MODERATE -> "MODERATE"
        ComponentCallbacks2.TRIM_MEMORY_COMPLETE -> "COMPLETE"
        else -> "LEVEL_$level"
    }

    /** The activity is finishing for good: the session it ended exited
     *  cleanly. Written here, synchronously, since the process is killed
     *  right after (MainActivity.onDestroy) and Dart can't write in time. */
    fun markCleanExit(context: Context, sessionId: String?) {
        if (sessionId.isNullOrEmpty()) return
        try {
            val file = File(context.filesDir, CLEAN_EXIT)
            file.parentFile?.mkdirs()
            file.writeText(sessionId)
        } catch (e: Exception) {
            Log.w("NightingaleTV", "clean exit not marked: $e")
        }
    }
}
