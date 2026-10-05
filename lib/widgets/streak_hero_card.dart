import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/services/habit_provider.dart';

class StreakHeroCard extends ConsumerWidget {
  const StreakHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final maxStreak = ref.watch(overallStreakProvider);
    final habits = ref.watch(habitListProvider);
    final completionRate = ref.watch(dailyCompletionRateProvider);
    final completedCount = habits.where((h) => h.isCompletedToday).length;

    final now = DateTime.now();
    // Monday of the current week
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          // Clean Fire Icon (no circle container)
          const Icon(
            Icons.local_fire_department_rounded,
            color: Color(0xFFFF5500),
            size: 48,
          ),
          const SizedBox(height: 8),
          // Large Bold Streak Number
          Text(
            '$maxStreak',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          Text(
            'days streak',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF27272A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Keep your daily momentum alive to expand your orbit.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 22),

          // Weekday Strip (Mon - Sun) inspired by references 1 & 5
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131417) : const Color(0xFFF4F4F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final dayDate = currentWeekStart.add(Duration(days: index));
                final isToday =
                    dayDate.day == now.day &&
                    dayDate.month == now.month &&
                    dayDate.year == now.year;
                final isPast = dayDate.isBefore(
                  DateTime(now.year, now.month, now.day),
                );

                const dayLabels = [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ];
                final label = dayLabels[index];

                // Check if any habit was completed on this day
                final dateKey =
                    '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
                final isCompleted = habits.any(
                  (h) => h.completedDates.contains(dateKey),
                );

                return Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDayBadge(
                      isCompleted: isCompleted,
                      isToday: isToday,
                      isPast: isPast,
                      isDark: isDark,
                    ),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(height: 18),

          // Daily Completion Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Progress',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              Text(
                '$completedCount of ${habits.length} habits • ${(completionRate * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: habits.isEmpty ? 0 : completionRate,
              minHeight: 7,
              backgroundColor: isDark
                  ? const Color(0xFF272830)
                  : const Color(0xFFE4E4DE),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? Colors.white : const Color(0xFF18181B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBadge({
    required bool isCompleted,
    required bool isToday,
    required bool isPast,
    required bool isDark,
  }) {
    if (isCompleted) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white : const Color(0xFF18181B),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.check_rounded,
            color: isDark ? const Color(0xFF141517) : Colors.white,
            size: 18,
          ),
        ),
      );
    }

    if (isToday) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: const Color(0xFFFF6B2B), width: 2),
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF6B2B),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }
}
