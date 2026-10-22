package com.example.orbit

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager.LayoutParams
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * Full-screen alarm UI, launched by [RingAlarmService] (via the notification's
 * full-screen intent, or directly when the screen is off / keyguard locked).
 * Mirrors the OEM clock-alarm experience: shows over the lock screen, turns
 * the screen on, and offers Snooze / Done / Dismiss. The looping sound is
 * owned by [RingAlarmService]; this activity only drives the buttons.
 */
class AlarmRingActivity : Activity() {

    private var kind = "task"
    private var taskId: String? = null
    private var title = "Task"

    /// Closes this UI when the ring window ends (auto-timeout or dismissed
    /// from the notification) so the screen doesn't stay on the alarm page.
    private val ringFinishedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == RingAlarmService.ACTION_RING_FINISHED) {
                finish()
            }
        }
    }
    private var receiverRegistered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    LayoutParams.FLAG_TURN_SCREEN_ON or
                    LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        window.addFlags(LayoutParams.FLAG_KEEP_SCREEN_ON)

        kind = intent.getStringExtra(EXTRA_KIND) ?: "task"
        taskId = intent.getStringExtra(EXTRA_TASK_ID)?.ifEmpty { null }
        title = intent.getStringExtra(EXTRA_TITLE)
            ?: if (kind == "focus") "Focus Complete" else "Task"

        try {
            getSystemService(KeyguardManager::class.java)
                ?.requestDismissKeyguard(this, null)
        } catch (_: Throwable) {
            // Not critical; the activity already shows over the lock screen.
        }

        setContentView(buildContent())
    }

    override fun onResume() {
        super.onResume()
        if (!receiverRegistered) {
            val filter = IntentFilter(RingAlarmService.ACTION_RING_FINISHED)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(
                    ringFinishedReceiver,
                    filter,
                    Context.RECEIVER_NOT_EXPORTED
                )
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(ringFinishedReceiver, filter)
            }
            receiverRegistered = true
        }
    }

    override fun onPause() {
        super.onPause()
        if (receiverRegistered) {
            try {
                unregisterReceiver(ringFinishedReceiver)
            } catch (_: Throwable) {
                // Already unregistered.
            }
            receiverRegistered = false
        }
    }

    private fun buildContent(): ScrollView {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(48), dp(32), dp(48))
            setBackgroundColor(Color.parseColor("#0E0E12"))
        }

        root.addView(
            TextView(this).apply {
                text = if (kind == "focus") "Focus complete" else "Alarm"
                setTextColor(Color.parseColor("#8B8BA3"))
                textSize = 16f
                gravity = Gravity.CENTER
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(16) }
        )

        root.addView(
            TextView(this).apply {
                text = title
                setTextColor(Color.WHITE)
                textSize = 32f
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(48) }
        )

        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        val buttonParams = LinearLayout.LayoutParams(
            0,
            LinearLayout.LayoutParams.WRAP_CONTENT,
            1f
        ).apply { marginStart = dp(8); marginEnd = dp(8) }

        if (kind == "focus") {
            buttons.addView(actionButton("Silence") { pressStop() }, buttonParams)
        } else {
            buttons.addView(actionButton("Snooze") { pressSnooze() }, buttonParams)
            buttons.addView(actionButton("Done") { pressDone() }, buttonParams)
            buttons.addView(actionButton("Dismiss") { pressStop() }, buttonParams)
        }
        root.addView(buttons)

        return ScrollView(this).apply { addView(root) }
    }

    private fun actionButton(label: String, onClick: () -> Unit): Button =
        Button(this).apply {
            text = label
            textSize = 16f
            setTextColor(Color.WHITE)
            isAllCaps = false
            setOnClickListener { onClick() }
        }

    private fun pressSnooze() {
        sendRingAction(RingAlarmService.ACTION_SNOOZE)
        finish()
    }

    private fun pressStop() {
        sendRingAction(RingAlarmService.ACTION_STOP)
        finish()
    }

    private fun pressDone() {
        // Complete the task natively and stop the ring — do not open the app.
        sendRingAction(RingAlarmService.ACTION_DONE)
        finish()
    }

    private fun sendRingAction(action: String) {
        try {
            startService(
                Intent(this, RingAlarmService::class.java).apply {
                    this.action = action
                    putExtra(RingAlarmService.EXTRA_KIND, kind)
                    taskId?.let { putExtra(RingAlarmService.EXTRA_TASK_ID, it) }
                    putExtra(RingAlarmService.EXTRA_TITLE, title)
                }
            )
        } catch (_: Throwable) {
            // Service already gone; nothing left to stop.
        }
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    companion object {
        const val EXTRA_KIND = "kind"
        const val EXTRA_TASK_ID = "taskId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_NOTIFICATION_ID = "id"
    }
}
