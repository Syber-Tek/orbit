import 'package:flutter/material.dart';

enum TaskPriority {
  low('Low', Color(0xFF6B7280)),
  medium('Medium', Color(0xFFF59E0B)),
  high('High', Color(0xFFEF4444));

  final String label;
  final Color color;
  const TaskPriority(this.label, this.color);
}

enum TaskCategory {
  work('Work', Icons.work_outline_rounded, 0xFF3B82F6),
  personal('Personal', Icons.person_outline_rounded, 0xFF8B5CF6),
  health('Health', Icons.favorite_outline_rounded, 0xFF10B981),
  study('Study', Icons.menu_book_rounded, 0xFFF59E0B),
  general('General', Icons.task_alt_rounded, 0xFF6B7280);

  final String label;
  final IconData icon;
  final int colorValue;
  const TaskCategory(this.label, this.icon, this.colorValue);
}

class TaskItem {
  final String id;
  final String title;
  final String? description;
  final DateTime scheduledDate;
  final TimeOfDay? scheduledTime;
  final bool hasAlarm;
  final TaskPriority priority;
  final TaskCategory category;
  final bool isCompleted;
  final DateTime createdAt;

  const TaskItem({
    required this.id,
    required this.title,
    this.description,
    required this.scheduledDate,
    this.scheduledTime,
    this.hasAlarm = false,
    this.priority = TaskPriority.medium,
    this.category = TaskCategory.general,
    this.isCompleted = false,
    required this.createdAt,
  });

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? scheduledDate,
    TimeOfDay? scheduledTime,
    bool? clearScheduledTime,
    bool? hasAlarm,
    TaskPriority? priority,
    TaskCategory? category,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: clearScheduledTime == true ? null : (scheduledTime ?? this.scheduledTime),
      hasAlarm: hasAlarm ?? this.hasAlarm,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduledDate': scheduledDate.toIso8601String(),
      'scheduledTimeHour': scheduledTime?.hour,
      'scheduledTimeMinute': scheduledTime?.minute,
      'hasAlarm': hasAlarm,
      'priority': priority.name,
      'category': category.name,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    TimeOfDay? time;
    if (json['scheduledTimeHour'] != null && json['scheduledTimeMinute'] != null) {
      time = TimeOfDay(
        hour: json['scheduledTimeHour'] as int,
        minute: json['scheduledTimeMinute'] as int,
      );
    }

    return TaskItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      scheduledTime: time,
      hasAlarm: json['hasAlarm'] as bool? ?? false,
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      category: TaskCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => TaskCategory.general,
      ),
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
