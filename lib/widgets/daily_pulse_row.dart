import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/task.dart';
import 'package:orbit/services/ledger_provider.dart';
import 'package:orbit/services/screen_time_provider.dart';
import 'package:orbit/services/task_provider.dart';

class DailyPulseRow extends ConsumerWidget {
  static const List<String> _weekdayLabels = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final VoidCallback? onScreenTimeTap;
  final VoidCallback? onAlarmsTap;
  final VoidCallback? onBudgetTap;

  const DailyPulseRow({
    super.key,
    this.onScreenTimeTap,
    this.onAlarmsTap,
    this.onBudgetTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screenTime = ref.watch(screenTimeProvider);
    final ledger = ref.watch(ledgerProvider);
    final nextAlarm = ref.watch(nextAlarmProvider);

    final (alarmValue, alarmSubtitle) = _describeNextAlarm(context, nextAlarm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Orbit Pulse',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            Text(
              'Live Overview',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Card 1: Screen Time
            Expanded(
              child: _buildBentoCard(
                context: context,
                isDark: isDark,
                icon: IconlyLight.chart,
                accentColor: isDark ? Colors.white : const Color(0xFF18181B),
                title: 'Screen Time',
                value: screenTime.formattedTotalSpent,
                subtitle: '${screenTime.formattedDailyGoal} daily goal',
                onTap: onScreenTimeTap,
              ),
            ),
            const SizedBox(width: 10),
            // Card 2: Next Alarm / Tasks
            Expanded(
              child: _buildBentoCard(
                context: context,
                isDark: isDark,
                icon: IconlyLight.timeCircle,
                accentColor: isDark ? Colors.white : const Color(0xFF18181B),
                title: 'Next Alarm',
                value: alarmValue,
                subtitle: alarmSubtitle,
                onTap: onAlarmsTap,
              ),
            ),
            const SizedBox(width: 10),
            // Card 3: Today's Budget
            Expanded(
              child: _buildBentoCard(
                context: context,
                isDark: isDark,
                icon: IconlyLight.wallet,
                accentColor: isDark ? Colors.white : const Color(0xFF18181B),
                title: 'Spent Today',
                value: 'GH₵${ledger.totalSpentToday.toStringAsFixed(2)}',
                subtitle: 'GH₵${ledger.dailyBudgetLimit.toStringAsFixed(0)} daily cap',
                onTap: onBudgetTap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Resolves the "Next Alarm" card copy from the real armed task alarm.
  /// Falls back to a muted empty state when nothing is scheduled.
  (String, String) _describeNextAlarm(BuildContext context, TaskItem? task) {
    final time = task?.scheduledTime;
    if (task == null || time == null) return ('--:--', 'No alarms set');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(
      task.scheduledDate.year,
      task.scheduledDate.month,
      task.scheduledDate.day,
    );
    final dayGap = day.difference(today).inDays;

    final String when;
    if (dayGap == 0) {
      when = 'Today';
    } else if (dayGap == 1) {
      when = 'Tomorrow';
    } else if (dayGap > 1 && dayGap < 7) {
      when = _weekdayLabels[task.scheduledDate.weekday - 1];
    } else {
      when = '${task.scheduledDate.day}/${task.scheduledDate.month}';
    }

    return (time.format(context), when);
  }

  Widget _buildBentoCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String value,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18191E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(icon, color: accentColor, size: 17)),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
