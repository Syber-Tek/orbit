import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/task.dart';

class TaskItemCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskItemCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatTime(TimeOfDay time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDone = task.isCompleted;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDone
              ? (isDark
                  ? const Color(0xFF16171B).withValues(alpha: 0.7)
                  : const Color(0xFFF6F6F2))
              : (isDark ? const Color(0xFF18191E) : Colors.white),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDone
                ? (isDark ? const Color(0xFF222329) : const Color(0xFFE8E8E2))
                : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
            width: 1.2,
          ),
          boxShadow: isDone
              ? []
              : [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onToggle();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
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
                    boxShadow: isDone
                        ? [
                            BoxShadow(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: isDone ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.check_rounded,
                        color: isDark ? const Color(0xFF141517) : Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title, Subtitle, and Time/Tag Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                        color: isDone
                            ? (isDark ? Colors.grey.shade500 : Colors.grey.shade500)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),

                    // Badges row: Scheduled Time / Alarm, Category, Priority
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Scheduled Time Badge
                        if (task.scheduledTime != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: task.hasAlarm
                                  ? const Color(0xFFFF6B2B).withValues(alpha: isDark ? 0.22 : 0.12)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  task.hasAlarm
                                      ? IconlyBold.notification
                                      : IconlyLight.timeCircle,
                                  size: 12,
                                  color: task.hasAlarm
                                      ? const Color(0xFFFF6B2B)
                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(task.scheduledTime!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: task.hasAlarm
                                        ? const Color(0xFFFF6B2B)
                                        : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Category Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color(task.category.colorValue).withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                task.category.icon,
                                size: 11,
                                color: Color(task.category.colorValue),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.category.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(task.category.colorValue),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Priority Flag
                        if (task.priority != TaskPriority.low)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: task.priority.color.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flag_rounded,
                                  size: 11,
                                  color: task.priority.color,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  task.priority.label,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: task.priority.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Arrow / Menu
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, size: 18),
                onPressed: () {
                  _showTaskOptions(context);
                },
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskOptions(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(IconlyLight.edit),
              title: const Text('Edit Task'),
              onTap: () {
                Navigator.pop(ctx);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
              title: const Text('Delete Task', style: TextStyle(color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
