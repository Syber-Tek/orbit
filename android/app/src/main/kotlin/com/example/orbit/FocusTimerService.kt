package com.example.orbit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel

/**
 * Keeps the focus timer running (and visible) while the app is closed.
 *
 * Owns its own countdown so the remaining time stays accurate even when the
 * Dart isolate is dead, posts an ongoing notification that shows on the lock
 * screen with Pause/Resume and Stop actions, and reports state changes back to
 * Flutter through [eventSink] whenever the app is alive to receive them.
 */
class FocusTimerService : Service() {

    companion object {
        const val CHANNEL_ID = "orbit_focus_running"
        const val NOTIFICATION_ID = 1002
        const val PREFS = "orbit_focus_prefs"

        const val ACTION_START = "com.example.orbit.focus.START"
        const val ACTION_PAUSE = "com.example.orbit.focus.PAUSE"
        const val ACTION_RESUME = "com.example.orbit.focus.RESUME"
        const val ACTION_STOP = "com.example.orbit.focus.STOP"

        @Volatile
        var eventSink: EventChannel.EventSink? = null

        fun pushEvent(
            event: String,
            title: String,
            totalSeconds: Int,
            remainingSeconds: Int,
            running: Boolean
        ) {
            try {
                eventSink?.success(
                    mapOf(
                        "event" to event,
                        "title" to title,
                        "totalSeconds" to totalSeconds,
                        "remainingSeconds" to remainingSeconds,
                        "running" to running
                    )
                )
            } catch (e: Exception) {
                // The Dart side is not listening; the persisted state is the
                // source of truth until the app opens again.
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var prefs: SharedPreferences? = null

    private var title = "Focus"
    private var totalSeconds = 25 * 60
    private var remainingSeconds = 25 * 60
    private var running = false

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            if (remainingSeconds <= 1) {
                complete()
                return
            }
            remainingSeconds--
            persist()
            updateNotification()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                title = intent.getStringExtra("title") ?: "Focus"
                totalSeconds = intent.getIntExtra("totalSeconds", 25 * 60).coerceAtLeast(1)
                remainingSeconds = intent.getIntExtra("remainingSeconds", totalSeconds).coerceIn(1, totalSeconds)
                running = true
                handler.removeCallbacksAndMessages(tick)
                startMyForeground()
                persist()
                handler.postDelayed(tick, 1000)
            }
            ACTION_PAUSE -> pause()
            ACTION_RESUME -> resume()
            ACTION_STOP -> stopFocus()
            else -> {
                // Restarted by the system (START_STICKY) or background action.
                if (restore()) {
                    startMyForeground()
                    if (running) {
                        handler.removeCallbacksAndMessages(tick)
                        handler.postDelayed(tick, 1000)
                    } else {
                        updateNotification()
                    }
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Focus Timer",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Shows the running focus timer with controls"
                    setShowBadge(false)
                }
            )
        }
    }

    private fun startMyForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun pause() {
        running = false
        handler.removeCallbacksAndMessages(tick)
        persist()
        updateNotification()
        pushEvent("paused", title, totalSeconds, remainingSeconds, running)
    }

    private fun resume() {
        running = true
        persist()
        updateNotification()
        pushEvent("resumed", title, totalSeconds, remainingSeconds, running)
        handler.removeCallbacksAndMessages(tick)
        handler.postDelayed(tick, 1000)
    }

    private fun stopFocus() {
        handler.removeCallbacksAndMessages(tick)
        stopForeground(STOP_FOREGROUND_REMOVE)
        clearPrefs()
        pushEvent("stopped", title, totalSeconds, remainingSeconds, running)
        stopSelf()
    }

    private fun complete() {
        handler.removeCallbacksAndMessages(tick)
        remainingSeconds = 0
        running = false
        persist(false)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.cancel(NOTIFICATION_ID)
        pushEvent("completed", title, totalSeconds, 0, false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun updateNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        try {
            nm.notify(NOTIFICATION_ID, buildNotification())
        } catch (e: SecurityException) {
            // Missing notification permission on Android 13+
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val pauseIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, FocusTimerService::class.java).setAction(ACTION_PAUSE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val resumeIntent = PendingIntent.getService(
            this,
            2,
            Intent(this, FocusTimerService::class.java).setAction(ACTION_RESUME),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = PendingIntent.getService(
            this,
            3,
            Intent(this, FocusTimerService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val remainingText = "${formatTime(remainingSeconds)} remaining"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(remainingText)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$title • $remainingText"))
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(0, if (running) "Pause" else "Resume", if (running) pauseIntent else resumeIntent)
            .addAction(0, "Stop", stopIntent)
            .build()
    }

    private fun formatTime(totalSecondsValue: Int): String {
        val m = totalSecondsValue / 60
        val s = totalSecondsValue % 60
        val mm = m.toString().padStart(2, '0')
        val ss = s.toString().padStart(2, '0')
        return "$mm:$ss"
    }

    private fun persist(storeRunning: Boolean = true) {
        prefs?.edit()?.apply {
            putString("title", title)
            putInt("totalSeconds", totalSeconds)
            putInt("remainingSeconds", remainingSeconds)
            putBoolean("running", storeRunning && running)
        }?.apply()
    }

    private fun clearPrefs() {
        prefs?.edit()?.clear()?.apply()
    }

    private fun restore(): Boolean {
        val p = prefs ?: return false
        if (!p.contains("title")) return false
        title = p.getString("title", "Focus") ?: "Focus"
        totalSeconds = p.getInt("totalSeconds", 25 * 60).coerceAtLeast(1)
        remainingSeconds = p.getInt("remainingSeconds", totalSeconds).coerceIn(1, totalSeconds)
        running = p.getBoolean("running", false)
        return remainingSeconds > 0
    }
}