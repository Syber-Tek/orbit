package com.example.orbit

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray

class ScreenTimeAccessibilityService : AccessibilityService() {

    companion object {
        const val CHECK_INTERVAL_MS = 15_000L
        const val KICK_COOLDOWN_MS = 10_000L
    }

    private var workerThread: HandlerThread? = null
    private var workerHandler: Handler? = null

    @Volatile
    private var currentPackage: String? = null
    private var lastKickAt = 0L

    private val checkTask = Runnable {
        checkAndKick()
    }

    private val periodicRunnable = object : Runnable {
        override fun run() {
            try {
                checkAndKick()
            } catch (t: Throwable) {
                // Keep worker alive
            } finally {
                workerHandler?.postDelayed(this, CHECK_INTERVAL_MS)
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        workerThread = HandlerThread("screen-time-a11y").apply {
            start()
            workerHandler = Handler(looper)
            workerHandler?.post(periodicRunnable)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val pkg = event.packageName?.toString() ?: return
            // Ignore system UI and Orbit itself
            if (pkg == packageName || pkg == "com.android.systemui") return

            if (pkg != currentPackage) {
                currentPackage = pkg
                scheduleCheck()
            }
        }
    }

    override fun onInterrupt() {
        // Accessibility service interrupted
    }

    override fun onDestroy() {
        workerHandler?.removeCallbacksAndMessages(null)
        workerThread?.quitSafely()
        workerThread = null
        workerHandler = null
        super.onDestroy()
    }

    private fun scheduleCheck() {
        workerHandler?.removeCallbacks(checkTask)
        // Debounce by 250ms so fast window switches coalesce into a single check
        workerHandler?.postDelayed(checkTask, 250L)
    }

    private fun checkAndKick() {
        val pkg = currentPackage ?: return

        val limits = loadLimits()
        val limit = limits.firstOrNull {
            it.packageName == pkg && it.isEnabled && it.limitMinutes > 0
        } ?: return

        val usage = UsageStatsHelper.getTodayUsageMinutes(this)
        val used = usage[pkg] ?: 0

        if (used >= limit.limitMinutes && limit.isStrictLock) {
            val now = System.currentTimeMillis()
            if (now - lastKickAt >= KICK_COOLDOWN_MS) {
                lastKickAt = now
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        }
    }

    private fun loadLimits(): List<NativeAppLimit> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.app_limits_json", null)
            ?: prefs.getString("app_limits_json", null)
            ?: return emptyList()

        return try {
            val arr = JSONArray(raw)
            val list = mutableListOf<NativeAppLimit>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                list.add(
                    NativeAppLimit(
                        packageName = obj.optString("packageName"),
                        appName = obj.optString("appName"),
                        limitMinutes = obj.optInt("limitMinutes", 0),
                        notifyAt10Min = obj.optBoolean("notifyAt10Min", true),
                        notifyAt5Min = obj.optBoolean("notifyAt5Min", true),
                        isStrictLock = obj.optBoolean("isStrictLock", true),
                        isEnabled = obj.optBoolean("isEnabled", true)
                    )
                )
            }
            list
        } catch (e: Exception) {
            emptyList()
        }
    }
}
