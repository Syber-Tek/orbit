import 'package:flutter/material.dart';
import 'package:orbit/models/habit.dart';
import 'package:orbit/utils/app_haptics.dart';

class HabitItemCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const HabitItemCard({
    super.key,
    required this.habit,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDone = habit.isCompletedToday;
    final accentColor = Color(habit.colorValue);

    return Dismissible(
      key: ValueKey(habit.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        AppHaptics.mediumImpact();
        onDelete?.call();
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDone
              ? (isDark
                    ? const Color(0xFF16171B).withValues(alpha: 0.7)
                    : const Color(0xFFF6F6F2))
              : (isDark ? const Color(0xFF18191E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? (isDark ? const Color(0xFF222329) : const Color(0xFFE8E8E2))
                : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
            width: 1.2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
          // Category Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDone ? 0.08 : 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                Habit.iconFor(habit.iconCodePoint),
                color: isDone
                    ? accentColor.withValues(alpha: 0.5)
                    : accentColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Progress Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: isDark
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                    color: isDone
                        ? (isDark ? Colors.grey.shade500 : Colors.grey.shade500)
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${habit.currentCount}/${habit.targetCount} ${habit.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Streak Badge
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: Color(0xFFFF6B2B),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${habit.streak}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF6B2B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Check-in Circle Button
          GestureDetector(
            onTap: () {
              AppHaptics.lightImpact();
              onToggle();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? (isDark ? Colors.white : const Color(0xFF18181B))
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04)),
                border: Border.all(
                  color: isDone
                      ? Colors.transparent
                      : (isDark
                            ? const Color(0xFF383A44)
                            : const Color(0xFFD4D4CE)),
                  width: 1.8,
                ),
              ),
              child: Center(
                child: AnimatedScale(
                  scale: isDone ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.check_rounded,
                    color: isDark ? const Color(0xFF141517) : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
