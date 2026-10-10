package com.example.orbit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {
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

            // Re-arm task alarms that survive a reboot or package update.
            TaskAlarmScheduler.rescheduleAll(context)
        }
    }
}
