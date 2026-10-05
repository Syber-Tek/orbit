import 'package:flutter/material.dart';

enum HabitFrequency { daily, weekdays, weekends }

enum HabitTimeOfDay { morning, afternoon, evening, anytime }

class Habit {
  /// Compile-time lookup from the persisted icon code point to its [IconData].
  ///
  /// The code point is stored as an int so it survives JSON, but rebuilding an
  /// `IconData` at runtime defeats release icon tree-shaking and fails the
  /// release build. Every reachable icon is registered here as a const.
  static const Map<int, IconData> iconByCodePoint = <int, IconData>{
    0xf738: Icons.favorite_rounded,
    0xf0144: Icons.self_improvement_rounded,
    0xf767: Icons.fitness_center_rounded,
    0xf8b4: Icons.menu_book_rounded,
    0xf023c: Icons.timer_rounded,
    0xf03b4: Icons.water_drop_rounded,
    0xf634: Icons.check_circle_outline_rounded,
  };

  static IconData iconFor(int codePoint) =>
      iconByCodePoint[codePoint] ?? Icons.check_circle_outline_rounded;

  final String id;
  final String title;
  final String category;
  final int iconCodePoint;
  final int colorValue;
  final int currentCount;
  final int targetCount;
  final String unit;
  final int streak;
  final HabitFrequency frequency;
  final HabitTimeOfDay timeOfDay;
  final List<String> completedDates; // Stored as 'yyyy-MM-dd'
  final DateTime createdAt;

  const Habit({
    required this.id,
    required this.title,
    required this.category,
    required this.iconCodePoint,
    required this.colorValue,
    this.currentCount = 0,
    required this.targetCount,
    this.unit = 'times',
    this.streak = 0,
    this.frequency = HabitFrequency.daily,
    this.timeOfDay = HabitTimeOfDay.anytime,
    this.completedDates = const [],
    required this.createdAt,
  });

  bool get isCompletedToday {
    final today = _dateKey(DateTime.now());
    return completedDates.contains(today);
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Habit copyWith({
    String? id,
    String? title,
    String? category,
    int? iconCodePoint,
    int? colorValue,
    int? currentCount,
    int? targetCount,
    String? unit,
    int? streak,
    HabitFrequency? frequency,
    HabitTimeOfDay? timeOfDay,
    List<String>? completedDates,
    DateTime? createdAt,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      currentCount: currentCount ?? this.currentCount,
      targetCount: targetCount ?? this.targetCount,
      unit: unit ?? this.unit,
      streak: streak ?? this.streak,
      frequency: frequency ?? this.frequency,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      completedDates: completedDates ?? this.completedDates,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'currentCount': currentCount,
      'targetCount': targetCount,
      'unit': unit,
      'streak': streak,
      'frequency': frequency.index,
      'timeOfDay': timeOfDay.index,
      'completedDates': completedDates,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      currentCount: json['currentCount'] as int? ?? 0,
      targetCount: json['targetCount'] as int,
      unit: json['unit'] as String? ?? 'times',
      streak: json['streak'] as int? ?? 0,
      frequency: HabitFrequency.values[json['frequency'] as int? ?? 0],
      timeOfDay: HabitTimeOfDay.values[json['timeOfDay'] as int? ?? 0],
      completedDates: (json['completedDates'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
