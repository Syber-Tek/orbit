package com.example.orbit

import android.app.ActivityManager
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.example.orbit/usage_stats"
        const val FOCUS_CHANNEL = "com.example.orbit/focus"
        const val FOCUS_EVENTS_CHANNEL = "com.example.orbit/focus_events"
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            window.navigationBarColor = android.graphics.Color.TRANSPARENT
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "openUsageSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getTodayUsageStats" -> {
                    // Always run usage query on a background thread to prevent any ANR
                    thread {
                        val usage = try {
                            UsageStatsHelper.getTodayUsageMinutes(applicationContext)
                        } catch (e: Exception) {
                            emptyMap()
                        }
                        runOnUiThread {
                            result.success(usage)
                        }
                    }
                }
                "getScreenTimeStats" -> {
                    thread {
                        val stats = try {
                            UsageStatsHelper.getScreenTimeStats(applicationContext)
                        } catch (e: Exception) {
                            emptyMap()
                        }
                        runOnUiThread {
                            result.success(stats)
                        }
                    }
                }
                "startMonitorService" -> {
                    try {
                        val intent = Intent(this, AppMonitorService::class.java)
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "stopMonitorService" -> {
                    try {
                        val intent = Intent(this, AppMonitorService::class.java)
                        stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isMonitorServiceRunning" -> {
                    result.success(isServiceRunning(AppMonitorService::class.java))
                }
                "checkAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "moveTaskToBack" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startFocus" -> {
                    val title = call.argument<String>("title") ?: "Focus"
                    val totalSeconds = call.argument<Int>("totalSeconds") ?: 25 * 60
                    val remainingSeconds = call.argument<Int>("remainingSeconds") ?: totalSeconds
                    try {
                        val intent = Intent(this, FocusTimerService::class.java).apply {
                            action = FocusTimerService.ACTION_START
                            putExtra("title", title)
                            putExtra("totalSeconds", totalSeconds)
                            putExtra("remainingSeconds", remainingSeconds)
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "pauseFocus" -> {
                    startFocusServiceAction(FocusTimerService.ACTION_PAUSE)
                    result.success(true)
                }
                "resumeFocus" -> {
                    startFocusServiceAction(FocusTimerService.ACTION_RESUME)
                    result.success(true)
                }
                "stopFocus" -> {
                    startFocusServiceAction(FocusTimerService.ACTION_STOP)
                    result.success(true)
                }
                "getFocusState" -> {
                    val prefs = getSharedPreferences(FocusTimerService.PREFS, Context.MODE_PRIVATE)
                    if (!prefs.contains("title") || prefs.getInt("remainingSeconds", 0) <= 0) {
                        result.success(null)
                    } else {
                        result.success(
                            mapOf(
                                "title" to (prefs.getString("title", "Focus") ?: "Focus"),
                                "totalSeconds" to prefs.getInt("totalSeconds", 25 * 60),
                                "remainingSeconds" to prefs.getInt("remainingSeconds", 0),
                                "running" to prefs.getBoolean("running", false)
                            )
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Focus timer service -> Flutter events (Pause/Resume/Stop/Complete from
        // the lock-screen notification while the app may be open or closed).
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    FocusTimerService.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    FocusTimerService.eventSink = null
                }
            })
    }

    private fun startFocusServiceAction(action: String) {
        try {
            val intent = Intent(this, FocusTimerService::class.java).setAction(action)
            ContextCompat.startForegroundService(this, intent)
        } catch (e: Exception) {
            // Ignore; the service may already have been stopped.
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedService = "$packageName/${ScreenTimeAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        return enabledServices.split(":").any {
            it.equals(expectedService, ignoreCase = true) ||
            it.contains(ScreenTimeAccessibilityService::class.java.simpleName)
        }
    }

    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
        @Suppress("DEPRECATION")
        for (service in am.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }
}
