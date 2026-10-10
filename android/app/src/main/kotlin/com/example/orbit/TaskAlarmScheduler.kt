package com.example.orbit

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * Owns the AlarmManager alarms that back task reminders. A small registry of
 * armed alarms is kept in SharedPreferences so they can be re-armed after a
 * reboot or package update without reading the Dart-owned task store.
 *
 * When the alarm fires, [TaskAlarmReceiver] starts [RingAlarmService], which
 * loops the alarm sound for the user-configured duration. Delivering the ring
 * natively (instead of via the notification channel sound) makes the full
 * duration reliable on every device, including OEM build that cut
 * FLAG_INSISTENT short.
 */
object TaskAlarmScheduler {

    private const val PREFS = "orbit_alarm_registry"
    private const val KEY_ALARMS = "alarms"

    private const val ID_BASE = 1_000_000L
    private const val ID_SPACE = 900_000L

    private const val EP_PREFIX = 'a'

    data class AlarmEntry(
        val taskId: String,
        val title: String,
        val epochMs: Long
    )

    /** Same FNV-1a id the Dart side computes for a task alarm notification. */
    fun alarmId(taskId: String): Long = ID_BASE + stableHash(taskId) % ID_SPACE

    private fun stableHash(seed: String): Long {
        var hash = 0x811c9dc5L
        for (byte in seed.toByteArray(Charsets.UTF_8)) {
            hash = hash xor (byte.toLong() and 0xFF)
            hash = (hash * 0x01000193L) and 0xFFFFFFFFL
        }
        return hash
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun registry(context: Context): List<AlarmEntry> {
        val raw = prefs(context).getString(KEY_ALARMS, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.getJSONObject(i)
                AlarmEntry(o.getString("taskId"), o.getString("title"), o.getLong("epochMs"))
            }
        } catch (t: Throwable) {
            emptyList()
        }
    }

    private fun saveRegistry(context: Context, entries: List<AlarmEntry>) {
        val arr = JSONArray()
        for (e in entries) {
            arr.put(
                JSONObject().apply {
                    put("taskId", e.taskId)
                    put("title", e.title)
                    put("epochMs", e.epochMs)
                }
            )
        }
        prefs(context).edit().putString(KEY_ALARMS, arr.toString()).apply()
    }

    private fun alarmPendingIntent(context: Context, entry: AlarmEntry): PendingIntent {
        val intent = Intent(context, TaskAlarmReceiver::class.java).apply {
            action = "$EP_PREFIX${entry.taskId}"
            putExtra("taskId", entry.taskId)
            putExtra("title", entry.title)
        }
        return PendingIntent.getBroadcast(
            context,
            alarmId(entry.taskId).toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Arms the OS alarm. Inexact scheduling is used when exact access was
     *  revoked or refused, so the alarm is never silently dropped. */
    @Synchronized
    fun arm(context: Context, taskId: String, title: String, epochMs: Long): Boolean {
        if (epochMs <= 0L) return false
        val entry = AlarmEntry(taskId, title, epochMs)
        val pi = alarmPendingIntent(context, entry)
        val am = context.getSystemService(AlarmManager::class.java) ?: return false
        try {
            val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                am.canScheduleExactAlarms()
            if (canExact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pi)
            }
        } catch (t: Throwable) {
            try {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pi)
            } catch (t2: Throwable) {
                return false
            }
        }
        val updated = registry(context).filterNot { it.taskId == taskId } + entry
        saveRegistry(context, updated)
        return true
    }

    @Synchronized
    fun cancel(context: Context, taskId: String) {
        val am = context.getSystemService(AlarmManager::class.java)
        if (am != null) {
            val entry = registry(context).firstOrNull { it.taskId == taskId }
            if (entry != null) {
                try {
                    am.cancel(alarmPendingIntent(context, entry))
                } catch (t: Throwable) {
                    // Continue with the registry cleanup regardless.
                }
            }
        }
        saveRegistry(context, registry(context).filterNot { it.taskId == taskId })
        RingAlarmService.stopForTaskId(context, taskId)
    }

    /** Removes a fired alarm from the registry so a reboot never re-rings it. */
    @Synchronized
    fun removeFired(context: Context, taskId: String) {
        saveRegistry(context, registry(context).filterNot { it.taskId == taskId })
    }

    /** Re-arms every future alarm after boot or package replacement. */
    fun rescheduleAll(context: Context) {
        val now = System.currentTimeMillis()
        val future = registry(context).filter { it.epochMs > now }
        saveRegistry(context, future)
        for (entry in future) {
            arm(context, entry.taskId, entry.title, entry.epochMs)
        }
    }
}