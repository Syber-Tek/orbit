package com.example.orbit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import java.util.Calendar

data class NativeAppLimit(
    val packageName: String,
    val appName: String,
    val limitMinutes: Int,
    val notifyAt10Min: Boolean = true,
    val notifyAt5Min: Boolean = true,
    val isStrictLock: Boolean = true,
    val isEnabled: Boolean = true
)

class AppMonitorService : Service() {

    companion object {
        const val CHANNEL_MONITOR = "app_monitor_channel"
        const val CHANNEL_ALERTS = "screen_time_alerts"
        const val NOTIFICATION_ID_FOREGROUND = 1001
        const val POLL_INTERVAL_MS = 10_000L
        const val KICK_COOLDOWN_MS = 30_000L
    }

    private var pollThread: HandlerThread? = null
    private var pollHandler: Handler? = null

    private var lastCheckDay = -1
    private val warnedThresholds = mutableSetOf<String>()
    private var lastKickAt = 0L

    private val pollRunnable = object : Runnable {
        override fun run() {
            try {
                pollAndEnforce()
            } catch (t: Throwable) {
                // Keep the background monitor resilient against errors
            } finally {
                pollHandler?.postDelayed(this, POLL_INTERVAL_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()

        val foregroundNotification = buildForegroundNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID_FOREGROUND,
                    foregroundNotification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID_FOREGROUND, foregroundNotification)
            }
        } else {
            startForeground(NOTIFICATION_ID_FOREGROUND, foregroundNotification)
        }

        pollThread = HandlerThread("app-monitor-poll").apply {
            start()
            pollHandler = Handler(looper)
            pollHandler?.post(pollRunnable)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val foregroundNotification = buildForegroundNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID_FOREGROUND,
                foregroundNotification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID_FOREGROUND, foregroundNotification)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        pollHandler?.removeCallbacksAndMessages(null)
        pollThread?.quitSafely()
        pollThread = null
        pollHandler = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val monitorChan = NotificationChannel(
                CHANNEL_MONITOR,
                "Screen Time Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows that Orbit screen time monitor is actively protecting your digital wellbeing"
                setShowBadge(false)
            }

            val alertChan = NotificationChannel(
                CHANNEL_ALERTS,
                "Screen Time Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies when app usage limits are approaching or reached"
                enableVibration(true)
            }

            nm.createNotificationChannel(monitorChan)
            nm.createNotificationChannel(alertChan)
        }
    }

    private fun buildForegroundNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_MONITOR)
            .setContentTitle("Orbit Screen Time Active")
            .setContentText("Monitoring configured app usage limits")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
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
                        // Defaults to strict to preserve behaviour for limits
                        // written before the flag existed.
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

    private fun getForegroundPackageName(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return null

        val now = System.currentTimeMillis()
        val events = try {
            usm.queryEvents(now - 60_000L, now)
        } catch (e: Exception) {
            null
        }

        var foregroundPkg: String? = null
        if (events != null) {
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val pkg = event.packageName ?: continue
                when (event.eventType) {
                    UsageEvents.Event.ACTIVITY_RESUMED, 1 -> foregroundPkg = pkg
                    UsageEvents.Event.ACTIVITY_PAUSED, 2 -> if (foregroundPkg == pkg) foregroundPkg = null
                }
            }
        }

        if (foregroundPkg != null) return foregroundPkg

        // Fallback: check queryUsageStats
        val stats = try {
            usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 60_000L, now)
        } catch (e: Exception) {
            null
        }

        return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
    }

    private fun pollAndEnforce() {
        val today = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)
        if (today != lastCheckDay) {
            lastCheckDay = today
            warnedThresholds.clear()
        }

        val limits = loadLimits().filter { it.isEnabled && it.limitMinutes > 0 }
        if (limits.isEmpty()) return

        val usage = UsageStatsHelper.getTodayUsageMinutes(this)
        val currentForeground = getForegroundPackageName()
        val nowMs = System.currentTimeMillis()

        for (limit in limits) {
            val used = usage[limit.packageName] ?: 0
            val remaining = (limit.limitMinutes - used).coerceAtLeast(0)

            if (used >= limit.limitMinutes) {
                if (warnedThresholds.add("${limit.packageName}:lock")) {
                    postAlertNotification(
                        id = stableId(limit.packageName) + 1,
                        title = "${limit.appName} Daily Limit Reached",
                        body = "Your daily limit for ${limit.appName} is used up. It is locked for today.",
                        fullScreen = true
                    )
                }
                // Only force-quit the app when the user asked for a strict lock.
                if (limit.isStrictLock &&
                    currentForeground == limit.packageName &&
                    (nowMs - lastKickAt >= KICK_COOLDOWN_MS)
                ) {
                    lastKickAt = nowMs
                    sendToHome()
                }
            } else if (remaining <= 5 && limit.notifyAt5Min) {
                if (warnedThresholds.add("${limit.packageName}:5")) {
                    postAlertNotification(
                        id = stableId(limit.packageName),
                        title = "${limit.appName} — 5 minutes left",
                        body = "You have $remaining minute${if (remaining == 1) "" else "s"} left on ${limit.appName} today."
                    )
                }
            } else if (remaining <= 10 && limit.notifyAt10Min) {
                if (warnedThresholds.add("${limit.packageName}:10")) {
                    postAlertNotification(
                        id = stableId(limit.packageName),
                        title = "${limit.appName} — 10 minutes left",
                        body = "You have $remaining minute${if (remaining == 1) "" else "s"} left on ${limit.appName} today."
                    )
                }
            }
        }
    }

    private fun sendToHome() {
        try {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
        } catch (e: Exception) {
            // Background activity starts are restricted on Android 10+;
            // ScreenTimeAccessibilityService reliably handles this via performGlobalAction.
        }
    }

    private fun postAlertNotification(
        id: Int,
        title: String,
        body: String,
        fullScreen: Boolean = false
    ) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            id,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ALERTS)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)

        if (fullScreen) {
            builder.setFullScreenIntent(pendingIntent, true)
        }

        try {
            nm.notify(id, builder.build())
        } catch (e: SecurityException) {
            // Catch missing notification permission on Android 13+
        }
    }

    private fun stableId(pkg: String): Int {
        return (pkg.hashCode() and Int.MAX_VALUE) % 100_000
    }
}
