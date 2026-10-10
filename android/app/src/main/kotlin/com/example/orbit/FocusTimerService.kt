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
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel

/**
 * Keeps the focus timer running (and visible) while the app is closed.
 *
 * The countdown is anchored to a wall-clock end time ([endWallClockMs]) so it
 * never drifts when the device is busy, frozen, or the process restarts. When
 * it finishes it posts a ringing "Focus complete" alarm on its own channel.
 */
class FocusTimerService : Service() {

    companion object {
        const val CHANNEL_RUNNING = "orbit_focus_running"
        const val CHANNEL_DONE = "orbit_focus_done"
        const val NOTIFICATION_ID = 1002
        const val NOTIFICATION_DONE_ID = 1003
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
                // The Dart side is not listening; persisted state is the
                // source of truth until the app opens again.
            }
        }

        /// Reports the in-flight session to Flutter (used by getFocusState).
        /// Computes the running countdown from the wall clock, not the last
        /// stored value, so the app opens with the correct time left.
        fun currentState(context: Context): Map<String, Any>? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (!prefs.contains("title")) return null
            val title = prefs.getString("title", "Focus") ?: "Focus"
            val total = prefs.getInt("totalSeconds", 25 * 60).coerceAtLeast(1)
            val running = prefs.getBoolean("running", false)
            var remaining = prefs.getInt("remainingSeconds", total).coerceIn(1, total)
            var persist = false
            if (running) {
                val end = prefs.getLong("endWallClockMs", 0L)
                if (end > 0L) {
                    val left = ((end - System.currentTimeMillis() + 999) / 1000).toInt()
                    if (left <= 0) return null
                    remaining = left
                    if (remaining != prefs.getInt("remainingSeconds", remaining)) persist = true
                }
            }
            if (persist) {
                prefs.edit().putInt("remainingSeconds", remaining).apply()
            }
            return mapOf(
                "title" to title,
                "totalSeconds" to total,
                "remainingSeconds" to remaining,
                "running" to running
            )
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var prefs: SharedPreferences? = null

    private var title = "Focus"
    private var totalSeconds = 25 * 60
    private var remainingSeconds = 25 * 60
    private var running = false
    private var endWallClockMs = 0L

    /// Seconds left until [endWallClockMs], derived from the wall clock so
    /// delayed or skipped ticks can never overcount time.
    private fun remainingFromClock(): Int {
        if (endWallClockMs <= 0L) return remainingSeconds
        val left = ((endWallClockMs - System.currentTimeMillis() + 999) / 1000).toInt()
        return if (left < 0) 0 else left
    }

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            if (remainingSeconds <= 0) {
                complete()
                return
            }
            remainingSeconds = remainingFromClock()
            if (remainingSeconds <= 0) {
                complete()
                return
            }
            persist()
            updateNotification()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                title = intent.getStringExtra("title") ?: "Focus"
                totalSeconds = intent.getIntExtra("totalSeconds", 25 * 60).coerceAtLeast(1)
                remainingSeconds = intent.getIntExtra("remainingSeconds", totalSeconds).coerceIn(1, totalSeconds)
                running = true
                endWallClockMs = System.currentTimeMillis() + remainingSeconds * 1000L
                handler.removeCallbacksAndMessages(tick)
                startMyForeground()
                persist()
                handler.postDelayed(tick, 1000)
            }
            ACTION_PAUSE -> if (restore()) pause() else stopSelf()
            ACTION_RESUME -> if (restore()) resume() else stopSelf()
            ACTION_STOP -> stopFocus()
            else -> {
                // Restarted by the system (START_STICKY) after a kill, or a
                // background action arrived without a fresh START.
                if (!restore()) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                if (running && remainingFromClock() <= 0) {
                    // Finished while the process was dead: ring and clean up.
                    complete()
                } else {
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

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val runningChan = NotificationChannel(
                CHANNEL_RUNNING,
                "Focus Timer",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows the running focus timer with controls"
                setShowBadge(false)
            }
            nm.createNotificationChannel(runningChan)

            val doneUri = Uri.parse("android.resource://$packageName/${R.raw.orbit_alarm}")
            val doneChan = NotificationChannel(
                CHANNEL_DONE,
                "Focus Complete",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Rings when a focus session finishes"
                setSound(
                    doneUri,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                enableVibration(true)
            }
            nm.createNotificationChannel(doneChan)
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
        remainingSeconds = remainingFromClock()
        endWallClockMs = 0L
        handler.removeCallbacksAndMessages(tick)
        persist()
        updateNotification()
        pushEvent("paused", title, totalSeconds, remainingSeconds, running)
    }

    private fun resume() {
        running = true
        remainingSeconds = remainingFromClock().coerceAtLeast(1)
        endWallClockMs = System.currentTimeMillis() + remainingSeconds * 1000L
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
        endWallClockMs = 0L
        clearPrefs()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.cancel(NOTIFICATION_ID)
        startCompletionRing()
        pushEvent("completed", title, totalSeconds, 0, false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /// Rings the looping "Focus Complete" chime for the same configured alarm
    /// duration as task alarms (default 2 minutes), handled by [RingAlarmService]
    /// so the duration is honoured even on OEM builds that cut notification
    /// channel sounds short.
    private fun startCompletionRing() {
        try {
            val intent = Intent(this, RingAlarmService::class.java).apply {
                action = RingAlarmService.ACTION_START
                putExtra("kind", "focus")
                putExtra("title", title)
                putExtra("id", NOTIFICATION_DONE_ID)
            }
            ContextCompat.startForegroundService(this, intent)
        } catch (t: Throwable) {
            // Fall back to the old insistent notification when the service
            // cannot be started.
            legacyPostFocusCompleteAlarm()
        }
    }

    private fun legacyPostFocusCompleteAlarm() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_DONE_ID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        var ringMs = 2 * 60 * 1000L
        try {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            ringMs = flutterPrefs.getLong(
                "flutter.orbit.notif.alarm_duration_minutes",
                ringMs
            )
        } catch (e: Exception) {
            // Keep the default when reading fails.
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_DONE)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Focus Complete")
            .setContentText("$title • Nice work! Tap to see your session.")
            .setStyle(NotificationCompat.BigTextStyle().bigText("$title finished. Nice work! Tap to see your session."))
            .setContentIntent(contentIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        val notification = builder.build()
        notification.flags = Notification.FLAG_INSISTENT
        try {
            val field = Notification::class.java.getField("timeoutAfter")
            field.setLong(notification, ringMs)
        } catch (e: Exception) {
            // Ring until dismissed when the platform cannot auto-timeout.
        }
        try {
            nm.notify(NOTIFICATION_DONE_ID, notification)
        } catch (e: SecurityException) {
            // Missing notification permission on Android 13+
        }
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

        val remainingText = "${formatTime(remainingFromClock())} remaining"

        val notification = NotificationCompat.Builder(this, CHANNEL_RUNNING)
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

        // Permanent status: cannot be swiped or cleared from the notification
        // panel. Only the app's Stop action ends it.
        notification.flags = notification.flags or
            Notification.FLAG_ONGOING_EVENT or
            Notification.FLAG_NO_CLEAR
        return notification
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
            putLong("endWallClockMs", if (running) endWallClockMs else 0L)
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
        endWallClockMs = p.getLong("endWallClockMs", 0L)
        remainingSeconds = remainingFromClock()
        return remainingSeconds > 0
    }
}