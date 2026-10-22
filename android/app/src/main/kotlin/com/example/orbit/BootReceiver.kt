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

class BootReceiver : BroadcastReceiver() {

    private val tag = "OrbitAlarm"

    /** Alarms older than this on boot are considered stale and not surfaced. */
    private val missedWindowMs = 12 * 60 * 60 * 1000L

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.app_limits_json", null)
                ?: prefs.getString("app_limits_json", null)

            // Only restart monitor service if limits have been configured
            if (!raw.isNullOrBlank() && raw != "[]") {
                val serviceIntent = Intent(context, AppMonitorService::class.java)
                ContextCompat.startForegroundService(context, serviceIntent)
            }

            // Re-arm task alarms that survive a reboot or package update, and
            // notify about any that came due while the device was off.
            val overdue = TaskAlarmScheduler.rescheduleAll(context)
            postMissedAlarms(context, overdue)
        }
    }

    private fun postMissedAlarms(context: Context, overdue: List<TaskAlarmScheduler.AlarmEntry>) {
        val now = System.currentTimeMillis()
        val recent = overdue.filter { now - it.epochMs <= missedWindowMs }
        if (recent.isEmpty()) return

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        val channelId = "orbit_missed_alarm"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val sound = Uri.parse("android.resource://${context.packageName}/${R.raw.orbit_alarm}")
            nm.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "Missed alarms",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alarms that fired while the device was off"
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

        for (entry in recent) {
            val openIntent = PendingIntent.getActivity(
                context,
                TaskAlarmScheduler.alarmId(entry.taskId).toInt(),
                Intent(context, MainActivity::class.java).apply {
                    putExtra("orbit_action", "open")
                    putExtra("orbit_taskId", entry.taskId)
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
                .setContentTitle("Missed alarm")
                .setContentText(entry.title)
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText("${entry.title} came due while the device was off.")
                )
                .setContentIntent(openIntent)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .build()

            try {
                nm.notify(TaskAlarmScheduler.alarmId(entry.taskId).toInt(), notification)
            } catch (t: Throwable) {
                Log.e(tag, "missed alarm notification failed", t)
            }
        }
    }
}
