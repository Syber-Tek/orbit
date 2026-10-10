package com.example.orbit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

/** Fires an armed task alarm: hands off to [RingAlarmService] which plays the
 *  looping alarm sound for the configured duration. */
class TaskAlarmReceiver : BroadcastReceiver() {

    private val tag = "OrbitAlarm"

    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra("taskId") ?: run {
            Log.w(tag, "onReceive: no taskId")
            return
        }
        val title = intent.getStringExtra("title") ?: "Task"
        Log.i(tag, "onReceive fired taskId=$taskId title=$title")
        TaskAlarmScheduler.removeFired(context, taskId)

        val serviceIntent = Intent(context, RingAlarmService::class.java).apply {
            action = RingAlarmService.ACTION_START
            putExtra("kind", "task")
            putExtra("taskId", taskId)
            putExtra("title", title)
            putExtra("id", TaskAlarmScheduler.alarmId(taskId).toInt())
        }
        try {
            ContextCompat.startForegroundService(context, serviceIntent)
            Log.i(tag, "startForegroundService OK")
        } catch (t: Throwable) {
            Log.e(tag, "startForegroundService FAILED", t)
            // Background-start blocked: the alarm is re-delivered when the
            // process next runs (registry re-arm on boot/app launch).
        }
    }
}