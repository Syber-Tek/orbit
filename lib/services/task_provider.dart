import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/task.dart';

enum TaskFilter { all, todo, done, highPriority }

class TaskListNotifier extends Notifier<List<TaskItem>> {
  @override
  List<TaskItem> build() {
    return const [];
  }

  void toggleTask(String id) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(isCompleted: !task.isCompleted);
      }
      return task;
    }).toList();
  }

  void addTask(TaskItem task) {
    state = [task, ...state];
  }

  void updateTask(TaskItem updatedTask) {
    state = state.map((task) => task.id == updatedTask.id ? updatedTask : task).toList();
  }

  void deleteTask(String id) {
    state = state.where((task) => task.id != id).toList();
  }
}

final taskListProvider = NotifierProvider<TaskListNotifier, List<TaskItem>>(
  TaskListNotifier.new,
);

class SelectedTaskDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void selectDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

final selectedTaskDateProvider = NotifierProvider<SelectedTaskDateNotifier, DateTime>(
  SelectedTaskDateNotifier.new,
);

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.all;

  void setFilter(TaskFilter filter) {
    state = filter;
  }
}

final selectedTaskFilterProvider = NotifierProvider<TaskFilterNotifier, TaskFilter>(
  TaskFilterNotifier.new,
);

/// Tasks scheduled for the currently selected day, with the active filter applied
final tasksForSelectedDateProvider = Provider<List<TaskItem>>((ref) {
  final tasks = ref.watch(taskListProvider);
  final selectedDate = ref.watch(selectedTaskDateProvider);
  final filter = ref.watch(selectedTaskFilterProvider);

  final forDate = tasks.where((task) {
    final d = task.scheduledDate;
    return d.year == selectedDate.year &&
        d.month == selectedDate.month &&
        d.day == selectedDate.day;
  }).toList();

  // Sort by time (tasks with scheduled time first)
  forDate.sort((a, b) {
    if (a.scheduledTime == null && b.scheduledTime == null) return 0;
    if (a.scheduledTime == null) return 1;
    if (b.scheduledTime == null) return -1;
    final aMin = a.scheduledTime!.hour * 60 + a.scheduledTime!.minute;
    final bMin = b.scheduledTime!.hour * 60 + b.scheduledTime!.minute;
    return aMin.compareTo(bMin);
  });

  switch (filter) {
    case TaskFilter.all:
      return forDate;
    case TaskFilter.todo:
      return forDate.where((t) => !t.isCompleted).toList();
    case TaskFilter.done:
      return forDate.where((t) => t.isCompleted).toList();
    case TaskFilter.highPriority:
      return forDate.where((t) => t.priority == TaskPriority.high).toList();
  }
});

/// Map of date string -> number of tasks (for calendar dot indicators)
final taskCountByDateProvider = Provider<Map<String, int>>((ref) {
  final tasks = ref.watch(taskListProvider);
  final map = <String, int>{};

  for (final t in tasks) {
    final key = '${t.scheduledDate.year}-${t.scheduledDate.month}-${t.scheduledDate.day}';
    map[key] = (map[key] ?? 0) + 1;
  }
  return map;
});

class TaskStats {
  final int total;
  final int completed;
  final int alarmsActive;
  final double rate;

  const TaskStats({
    required this.total,
    required this.completed,
    required this.alarmsActive,
    required this.rate,
  });
}

/// Stats for the currently selected date
final selectedDateStatsProvider = Provider<TaskStats>((ref) {
  final tasks = ref.watch(taskListProvider);
  final selectedDate = ref.watch(selectedTaskDateProvider);

  final forDate = tasks.where((task) {
    final d = task.scheduledDate;
    return d.year == selectedDate.year &&
        d.month == selectedDate.month &&
        d.day == selectedDate.day;
  }).toList();

  final total = forDate.length;
  final completed = forDate.where((t) => t.isCompleted).length;
  final alarms = forDate.where((t) => t.hasAlarm && !t.isCompleted).length;
  final rate = total > 0 ? (completed / total) : 0.0;

  return TaskStats(
    total: total,
    completed: completed,
    alarmsActive: alarms,
    rate: rate,
  );
});
