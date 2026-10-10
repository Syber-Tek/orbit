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
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Plays Orbit's alarm sound in a real loop for exactly the configured ring
 * duration (default 2 minutes) — independent of the notification channel's
 * sound, which OEM skins often cut short. Covers both task alarms and the
 * focus-complete chime.
 *
 * Owns a foreground notification with Snooze / Mark done (tasks) or Silence
 * (focus) actions. Snooze and Silence are handled natively; Mark done opens
 * [MainActivity], which forwards to Dart to persist the completion.
 */
class RingAlarmService : Service() {

    companion object {
        const val CHANNEL_RING = "orbit_ring_alarm"
        const val PREFS = "orbit_ring_state"

        private val tag = "OrbitAlarm"

        const val ACTION_START = "com.example.orbit.ring.START"
        const val ACTION_STOP = "com.example.orbit.ring.STOP"
        const val ACTION_SNOOZE = "com.example.orbit.ring.SNOOZE"

        /** Stops the ringing service only when it is currently ringing [taskId]. */
        fun stopForTaskId(context: Context, taskId: String) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (prefs.getString("taskId", null) != taskId) return
            Log.i(tag, "stopForTaskId matches taskId=$taskId")
            try {
                context.startService(
                    Intent(context, RingAlarmService::class.java).setAction(ACTION_STOP)
                )
            } catch (t: Throwable) {
                Log.w(tag, "stopForTaskId startService blocked", t)
                // Service not running; nothing to stop.
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private var notificationId = 0
    private var kind = "task"
    private var taskId: String? = null
    private var title = "Task"
    private var ringEndWallClockMs = 0L

    private val stopWhenFinished = object : Runnable {
        override fun run() {
            finishRing(showNotification = false)
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.i(tag, "onCreate")
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                notificationId = intent.getIntExtra("id", 1000000)
                kind = intent.getStringExtra("kind") ?: "task"
                taskId = intent.getStringExtra("taskId")
                title = intent.getStringExtra("title") ?: "Task"
                Log.i(tag, "onStartCommand START kind=$kind id=$notificationId taskId=$taskId")
                startRing()
            }
            ACTION_SNOOZE -> {
                // Snoozed from the notification: re-arm natively for later and
                // stop this ring. Dart take no part — the task data is stable.
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val snoozeMinutes = try {
                    prefs.getInt("flutter.orbit.notif.snooze_minutes", 10)
                } catch (t: Throwable) {
                    10
                }.coerceAtLeast(1)
                val currentTaskId = taskId
                if (currentTaskId != null) {
                    TaskAlarmScheduler.arm(
                        this,
                        currentTaskId,
                        title,
                        System.currentTimeMillis() + snoozeMinutes * 60_000L
                    )
                }
                finishRing(showNotification = false)
            }
            ACTION_STOP -> finishRing(showNotification = false)
            else -> {
                // START_STICKY restart while still inside the ring window.
                val restored = restoreRing()
                Log.i(tag, "onStartCommand else (resticky) restoreRing=$restored")
                if (!restored) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                if (ringEndWallClockMs <= System.currentTimeMillis()) {
                    finishRing(showNotification = false)
                } else {
                    startRing()
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        stopPlayer()
        releaseWakeLock()
        Log.i(tag, "onDestroy")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_RING,
                    "Alarm",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Ringing task alarms and focus completion"
                    setSound(null, null) // The sound is played by MediaPlayer.
                    enableVibration(true)
                }
            )
        }
    }

    private fun startRing() {
        handler.removeCallbacksAndMessages(null)

        val ringMs = readRingDurationMs()
        ringEndWallClockMs = System.currentTimeMillis() + ringMs
        persist()
        Log.i(tag, "startRing ringMs=$ringMs endWall=${ringEndWallClockMs}")

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    notificationId,
                    buildNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(notificationId, buildNotification())
            }
        } catch (t: Throwable) {
            Log.e(tag, "startForeground failed, retrying without type", t)
            startForeground(notificationId, buildNotification())
        }

        startPlayer()
        acquireWakeLock(ringMs)
        handler.postDelayed(stopWhenFinished, ringMs)
        Log.i(tag, "startRing complete")
    }

    private fun finishRing(showNotification: Boolean) {
        Log.i(tag, "finishRing showNotification=$showNotification")
        handler.removeCallbacksAndMessages(null)
        stopPlayer()
        releaseWakeLock()
        try {
            if (showNotification) {
                stopForeground(STOP_FOREGROUND_DETACH)
            } else {
                stopForeground(STOP_FOREGROUND_REMOVE)
            }
        } catch (t: Throwable) {
            // Ignore termination races.
        }
        clearPersist()
        stopSelf()
    }

    private fun startPlayer() {
        stopPlayer()
        try {
            val uri = Uri.parse("android.resource://$packageName/${R.raw.orbit_alarm}")
            val player = MediaPlayer().apply {
                setDataSource(this@RingAlarmService, uri)
                isLooping = true
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setOnErrorListener { _, _, _ ->
                    isLooping = true
                    false
                }
                prepare()
                start()
            }
            mediaPlayer = player
            Log.i(tag, "player started, looping=${player.isLooping}")
        } catch (t: Throwable) {
            Log.e(tag, "player start failed", t)
            mediaPlayer = null
        }
    }

    private fun stopPlayer() {
        try {
            mediaPlayer?.let { player ->
                if (player.isPlaying) player.stop()
                player.release()
            }
        } catch (t: Throwable) {
            // Already released or failed to start.
        }
        mediaPlayer = null
    }

    private fun acquireWakeLock(ms: Long) {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "orbit:ring").apply {
                setReferenceCounted(false)
                acquire(ms)
            }
        } catch (t: Throwable) {
            wakeLock = null
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (t: Throwable) {
            // Ignore.
        }
        wakeLock = null
    }

    private fun readRingDurationMs(): Long {
        val minutes = try {
            val p = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            p.getInt("flutter.orbit.notif.alarm_duration_minutes", 2)
        } catch (t: Throwable) {
            2
        }
        return (minutes.coerceIn(1, 60)) * 60_000L
    }

    private fun buildNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .putExtra("orbit_action", "open")
                .putExtra("orbit_taskId", taskId ?: ""),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_RING)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(if (kind == "focus") "Focus Complete" else title)
            .setContentText(
                if (kind == "focus") {
                    "Nice work! Tap to see your session."
                } else {
                    "Task alarm — tap to open Orbit."
                }
            )
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    if (kind == "focus") {
                        "$title finished. Nice work! Tap to see your session."
                    } else {
                        "Alarm for: $title"
                    }
                )
            )
            .setContentIntent(contentIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)

        if (kind == "focus") {
            builder.addAction(0, "Silence", stopAction())
        } else {
            builder.addAction(0, "Snooze", snoozeAction())
            builder.addAction(0, "Mark done", doneAction())
        }

        val notification = builder.build()
        notification.flags = Notification.FLAG_ONGOING_EVENT or Notification.FLAG_NO_CLEAR
        return notification
    }

    private fun snoozeAction(): PendingIntent {
        return PendingIntent.getService(
            this,
            1,
            Intent(this, RingAlarmService::class.java).setAction(ACTION_SNOOZE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun stopAction(): PendingIntent {
        return PendingIntent.getService(
            this,
            2,
            Intent(this, RingAlarmService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun doneAction(): PendingIntent {
        return PendingIntent.getActivity(
            this,
            3,
            Intent(this, MainActivity::class.java)
                .putExtra("orbit_action", "done")
                .putExtra("orbit_taskId", taskId ?: ""),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun persist() {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putInt("notificationId", notificationId)
            .putString("kind", kind)
            .putString("taskId", taskId ?: "")
            .putString("title", title)
            .putLong("ringEndWallClockMs", ringEndWallClockMs)
            .apply()
    }

    private fun restoreRing(): Boolean {
        val p: SharedPreferences = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!p.contains("ringEndWallClockMs")) return false
        notificationId = p.getInt("notificationId", 1000000)
        kind = p.getString("kind", "task") ?: "task"
        taskId = (p.getString("taskId", "") ?: "").ifEmpty { null }
        title = p.getString("title", "Task") ?: "Task"
        ringEndWallClockMs = p.getLong("ringEndWallClockMs", 0L)
        return ringEndWallClockMs > 0L
    }

    private fun clearPersist() {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }
}