package com.example.orbit

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/** Fires an armed task alarm: hands off to [RingAlarmService] which plays the
 *  looping alarm sound for the configured duration.
 *
 *  The registry entry is only dropped once the ring service has actually
 *  started. If the background service start is refused (an OEM restriction
 *  that occasionally still slips past the alarmed-app allowlist), a full-screen
 *  notification carrying the alarm sound is posted instead so the alarm is
 *  never silently lost. */
class TaskAlarmReceiver : BroadcastReceiver() {

    private val tag = "OrbitAlarm"

    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra("taskId") ?: run {
            Log.w(tag, "onReceive: no taskId")
            return
        }
        val title = intent.getStringExtra("title") ?: "Task"
        Log.i(tag, "onReceive fired taskId=$taskId title=$title")

        val notificationId = TaskAlarmScheduler.alarmId(taskId).toInt()
        val serviceIntent = Intent(context, RingAlarmService::class.java).apply {
            action = RingAlarmService.ACTION_START
            putExtra(RingAlarmService.EXTRA_KIND, "task")
            putExtra(RingAlarmService.EXTRA_TASK_ID, taskId)
            putExtra(RingAlarmService.EXTRA_TITLE, title)
            putExtra(RingAlarmService.EXTRA_NOTIFICATION_ID, notificationId)
        }

        val started = try {
            ContextCompat.startForegroundService(context, serviceIntent)
            true
        } catch (t: Throwable) {
            Log.e(tag, "startForegroundService FAILED, falling back to notification", t)
            false
        }

        if (started) {
            TaskAlarmScheduler.removeFired(context, taskId)
        } else {
            postFallbackNotification(context, taskId, title, notificationId)
            TaskAlarmScheduler.removeFired(context, taskId)
        }
    }

    /** Emergency path: a sound-bearing, full-screen notification so the user
     *  is still alerted if the foreground service could not be started. */
    private fun postFallbackNotification(
        context: Context,
        taskId: String,
        title: String,
        notificationId: Int
    ) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        val channelId = "orbit_missed_alarm"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val sound = Uri.parse("android.resource://${context.packageName}/${R.raw.orbit_alarm}")
            nm.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "Alarm fallback",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alarms that could not start their ring service"
                    setSound(
                        sound,
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    enableVibration(true)
                }
            )
        }

        val fullScreenIntent = PendingIntent.getActivity(
            context,
            notificationId,
            Intent(context, AlarmRingActivity::class.java).apply {
                putExtra(AlarmRingActivity.EXTRA_KIND, "task")
                putExtra(AlarmRingActivity.EXTRA_TASK_ID, taskId)
                putExtra(AlarmRingActivity.EXTRA_TITLE, title)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText("Alarm for: $title")
            .setContentIntent(fullScreenIntent)
            .setFullScreenIntent(fullScreenIntent, true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .build()

        try {
            nm.notify(notificationId, notification)
        } catch (t: Throwable) {
            Log.e(tag, "fallback notification failed", t)
        }
    }
}
