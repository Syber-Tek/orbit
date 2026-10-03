import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/task.dart';
import 'package:orbit/services/task_provider.dart';
import 'package:orbit/widgets/add_task_sheet.dart';
import 'package:orbit/widgets/task_item_card.dart';

class TasksScreen extends ConsumerWidget {
  final VoidCallback? onSettingsTap;

  const TasksScreen({
    super.key,
    this.onSettingsTap,
  });

  void _openAddTask(BuildContext context, {TaskItem? initialTask, DateTime? defaultDate}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskSheet(
        initialTask: initialTask,
        defaultDate: defaultDate,
      ),
    );
  }

  String _formatHeaderDate(DateTime dt) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekday = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];
    return '$weekday, $month ${dt.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedDate = ref.watch(selectedTaskDateProvider);
    final selectedFilter = ref.watch(selectedTaskFilterProvider);
    final tasks = ref.watch(tasksForSelectedDateProvider);
    final stats = ref.watch(selectedDateStatsProvider);
    final taskCounts = ref.watch(taskCountByDateProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Anchor week around selected date or current week
    final weekStart = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tasks',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatHeaderDate(selectedDate),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Add Task Button
                        IconButton(
                          onPressed: () => _openAddTask(context, defaultDate: selectedDate),
                          icon: const Icon(Icons.add_rounded, size: 22),
                          tooltip: 'Add Task',
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF1E1F25)
                                : const Color(0xFFEEEEEE),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Settings Button
                        if (onSettingsTap != null)
                          IconButton(
                            onPressed: onSettingsTap,
                            icon: const Icon(IconlyLight.setting, size: 20),
                            tooltip: 'Settings',
                            style: IconButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF1E1F25)
                                  : const Color(0xFFEEEEEE),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Daily Progress Overview Bento Card (Image 1 & 3 inspired)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18191E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Progress Ring / Arc
                      SizedBox(
                        width: 62,
                        height: 62,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: stats.rate,
                              strokeWidth: 6,
                              backgroundColor: isDark
                                  ? const Color(0xFF272830)
                                  : const Color(0xFFE5E5DF),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? Colors.white : const Color(0xFF18181B),
                              ),
                            ),
                            Text(
                              '${(stats.rate * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),

                      // Text and Alarm stats
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Goal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stats.completed}/${stats.total} tasks completed',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  IconlyBold.notification,
                                  size: 13,
                                  color: stats.alarmsActive > 0
                                      ? const Color(0xFFFF6B2B)
                                      : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  stats.alarmsActive > 0
                                      ? '${stats.alarmsActive} active alarms today'
                                      : 'No pending alarms',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: stats.alarmsActive > 0
                                        ? const Color(0xFFFF6B2B)
                                        : (isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Horizontal Week Calendar Strip (Image 3 & 4 inspired)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141519) : const Color(0xFFF6F6F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF222329) : const Color(0xFFE8E8E2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final dayDate = weekStart.add(Duration(days: index));
                      final isSelected = dayDate.year == selectedDate.year &&
                          dayDate.month == selectedDate.month &&
                          dayDate.day == selectedDate.day;
                      final isCurrentToday = dayDate.year == today.year &&
                          dayDate.month == today.month &&
                          dayDate.day == today.day;

                      final dayKey = '${dayDate.year}-${dayDate.month}-${dayDate.day}';
                      final count = taskCounts[dayKey] ?? 0;
                      final label = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index];

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(selectedTaskDateProvider.notifier).selectDate(dayDate);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? Colors.white : const Color(0xFF18181B))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF141517) : Colors.white)
                                      : (isCurrentToday
                                          ? const Color(0xFFFF6B2B)
                                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${dayDate.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF141517) : Colors.white)
                                      : (isCurrentToday
                                          ? const Color(0xFFFF6B2B)
                                          : theme.colorScheme.onSurface),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Task presence dot indicator
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: count > 0
                                      ? (isSelected
                                          ? (isDark ? const Color(0xFF141517) : Colors.white)
                                          : const Color(0xFFFF6B2B))
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),

            // Filter Tabs (Image 2 inspired: All, To Do, Done, High Priority)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        context: context,
                        ref: ref,
                        filter: TaskFilter.all,
                        label: 'All',
                        isSelected: selectedFilter == TaskFilter.all,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        context: context,
                        ref: ref,
                        filter: TaskFilter.todo,
                        label: 'To Do',
                        isSelected: selectedFilter == TaskFilter.todo,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        context: context,
                        ref: ref,
                        filter: TaskFilter.done,
                        label: 'Done',
                        isSelected: selectedFilter == TaskFilter.done,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        context: context,
                        ref: ref,
                        filter: TaskFilter.highPriority,
                        label: 'High Priority',
                        isSelected: selectedFilter == TaskFilter.highPriority,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tasks List or Empty State
            if (tasks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18191E) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          IconlyLight.timeCircle,
                          size: 40,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No tasks for this day',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + to schedule an alarm or to-do.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openAddTask(context, defaultDate: selectedDate),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : const Color(0xFF18181B),
                            foregroundColor: isDark ? const Color(0xFF141517) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final task = tasks[index];
                      return TaskItemCard(
                        task: task,
                        onToggle: () => ref.read(taskListProvider.notifier).toggleTask(task.id),
                        onEdit: () => _openAddTask(context, initialTask: task),
                        onDelete: () => ref.read(taskListProvider.notifier).deleteTask(task.id),
                      );
                    },
                    childCount: tasks.length,
                  ),
                ),
              ),

            // Bottom Spacing for floating navbar
            const SliverToBoxAdapter(
              child: SizedBox(height: 110),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required WidgetRef ref,
    required TaskFilter filter,
    required String label,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(selectedTaskFilterProvider.notifier).setFilter(filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF18181B))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? (isDark ? const Color(0xFF141517) : Colors.white)
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}
