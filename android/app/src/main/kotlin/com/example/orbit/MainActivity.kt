package com.example.orbit

import android.app.ActivityManager
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.example.orbit/usage_stats"
        const val FOCUS_CHANNEL = "com.example.orbit/focus"
        const val FOCUS_EVENTS_CHANNEL = "com.example.orbit/focus_events"
        const val NATIVE_ALARMS_CHANNEL = "com.example.orbit/native_alarms"
        const val ALARM_ACTIONS_CHANNEL = "com.example.orbit/alarm_actions"

        private const val EXTRA_ACTION = "orbit_action"
        private const val EXTRA_TASK_ID = "orbit_taskId"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var flutterEngineRef: FlutterEngine? = null
    private var pendingAlarmAction: Pair<String, String>? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            window.navigationBarColor = android.graphics.Color.TRANSPARENT
        }
        handleAlarmAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAlarmAction(intent)
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
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        requestIgnoreBatteryOptimizations()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
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
                    result.success(FocusTimerService.currentState(this))
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

        flutterEngineRef = flutterEngine
        processPendingAlarmAction()

        // Dart -> native task alarm scheduling (AlarmManager + RingAlarmService).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_ALARMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleTask" -> {
                        val taskId = call.argument<String>("taskId") ?: return@setMethodCallHandler result.success(false)
                        val title = call.argument<String>("title") ?: "Task"
                        val whenMs = (call.argument<Any>("whenMs") as? Number)?.toLong() ?: 0L
                        result.success(TaskAlarmScheduler.arm(this, taskId, title, whenMs))
                    }
                    "cancelTask" -> {
                        val taskId = call.argument<String>("taskId")
                        if (taskId != null) TaskAlarmScheduler.cancel(this, taskId)
                        result.success(true)
                    }
                    "stopRinging" -> {
                        val taskId = call.argument<String>("taskId")
                        if (taskId != null) RingAlarmService.stopForTaskId(this, taskId)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Routes Snooze/Mark done/body-tap intents from the native alarm
    /// notification to Dart. Retries until the Dart handler is registered,
    /// which covers cold starts where the activity launches before Dart runs.
    private fun handleAlarmAction(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra(EXTRA_ACTION) ?: return
        val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: ""
        pendingAlarmAction = action to taskId
        processPendingAlarmAction()
    }

    private fun processPendingAlarmAction() {
        val pending = pendingAlarmAction ?: return
        if (flutterEngineRef == null) return
        pushAlarmAction(pending.first, pending.second, attemptsRemaining = 40)
    }

    private fun pushAlarmAction(action: String, taskId: String, attemptsRemaining: Int) {
        val engine = flutterEngineRef ?: return
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, ALARM_ACTIONS_CHANNEL)
        channel.invokeMethod(
            "applyAction",
            mapOf("action" to action, "taskId" to taskId),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    // Delivered to the Dart handler.
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    retry()
                }

                override fun notImplemented() {
                    retry()
                }

                private fun retry() {
                    if (attemptsRemaining <= 0) return
                    mainHandler.postDelayed(
                        { pushAlarmAction(action, taskId, attemptsRemaining - 1) },
                        250
                    )
                }
            }
        )
    }

    private fun startFocusServiceAction(action: String) {
        try {
            val intent = Intent(this, FocusTimerService::class.java).setAction(action)
            // Pause/Resume/Stop only ever target an already-foreground service.
            // A plain start (vs startForegroundService) avoids the
            // "did not then call Service.startForeground()" crash Android
            // throws when the service had already stopped and nothing follows.
            startService(intent)
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

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /// Shows the system "Allow Orbit to run in the background" dialog. The user
    /// must opt in, but once accepted the OEM won't freeze or kill the app.
    private fun requestIgnoreBatteryOptimizations() {
        if (isIgnoringBatteryOptimizations()) return
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:$packageName"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
