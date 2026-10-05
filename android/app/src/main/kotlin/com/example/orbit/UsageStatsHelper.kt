package com.example.orbit

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import java.util.Calendar

object UsageStatsHelper {

    fun startOfToday(): Long {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    fun getTodayUsageMinutes(context: Context): Map<String, Int> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyMap()

        val endTime = System.currentTimeMillis()
        val startTime = startOfToday()
        // Query last 48 hours to account for long sessions started before local midnight
        val queryStart = startTime - (48 * 60 * 60 * 1000L)

        val events = try {
            usm.queryEvents(queryStart, endTime)
        } catch (e: Exception) {
            return emptyMap()
        } ?: return emptyMap()

        val resumedAt = HashMap<String, Long>()
        val totals = HashMap<String, Long>()
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            val time = event.timeStamp

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED, 1 -> { // 1 = MOVE_TO_FOREGROUND
                    if (!resumedAt.containsKey(pkg)) {
                        resumedAt[pkg] = time
                    }
                }
                UsageEvents.Event.ACTIVITY_PAUSED, 2 -> { // 2 = MOVE_TO_BACKGROUND
                    val resume = resumedAt.remove(pkg)
                    if (resume != null) {
                        addClamped(totals, pkg, resume, time, startTime, endTime)
                    }
                }
            }
        }

        // Sessions still currently foregrounded count up to endTime
        for ((pkg, resume) in resumedAt) {
            addClamped(totals, pkg, resume, endTime, startTime, endTime)
        }

        return totals.mapNotNull { (pkg, ms) ->
            val mins = (ms / 60_000L).toInt()
            if (mins > 0) pkg to mins else null
        }.toMap()
    }

    private fun addClamped(
        totals: HashMap<String, Long>,
        pkg: String,
        from: Long,
        to: Long,
        rangeStart: Long,
        rangeEnd: Long
    ) {
        val start = maxOf(from, rangeStart)
        val end = minOf(to, rangeEnd)
        if (end > start) {
            totals[pkg] = (totals[pkg] ?: 0L) + (end - start)
        }
    }
}
