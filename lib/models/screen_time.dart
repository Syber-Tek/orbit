import 'package:flutter/material.dart';

enum AppCategory {
  social,
  entertainment,
  productivity,
  gaming,
  reading,
  utilities,
}

extension AppCategoryX on AppCategory {
  String get label {
    switch (this) {
      case AppCategory.social:
        return 'Social';
      case AppCategory.entertainment:
        return 'Entertainment';
      case AppCategory.productivity:
        return 'Productivity';
      case AppCategory.gaming:
        return 'Gaming';
      case AppCategory.reading:
        return 'Reading';
      case AppCategory.utilities:
        return 'Utilities';
    }
  }

  Color get color {
    switch (this) {
      case AppCategory.social:
        return const Color(0xFF8B5CF6); // Purple
      case AppCategory.entertainment:
        return const Color(0xFFEC4899); // Pink
      case AppCategory.productivity:
        return const Color(0xFF3B82F6); // Blue
      case AppCategory.gaming:
        return const Color(0xFFF97316); // Orange
      case AppCategory.reading:
        return const Color(0xFF10B981); // Emerald
      case AppCategory.utilities:
        return const Color(0xFF6B7280); // Slate
    }
  }
}

class AppUsageItem {
  final String id;
  final String name;
  final String packageName;
  final AppCategory category;
  final int timeSpentMinutes;
  final int? limitMinutes;
  final bool notifyAt10Min;
  final bool notifyAt5Min;
  final bool isStrictLock;
  final int iconCodePoint;
  final int colorValue;

  static const int defaultIconCodePoint = 0xe0a0; // Icons.apps_rounded

  const AppUsageItem({
    required this.id,
    required this.name,
    required this.packageName,
    required this.category,
    required this.timeSpentMinutes,
    this.limitMinutes,
    this.notifyAt10Min = true,
    this.notifyAt5Min = true,
    this.isStrictLock = false,
    this.iconCodePoint = defaultIconCodePoint,
    this.colorValue = 0xFF18181B,
  });

  bool get hasLimit => limitMinutes != null && limitMinutes! > 0;

  int get remainingMinutes {
    if (!hasLimit) return 9999;
    final left = limitMinutes! - timeSpentMinutes;
    return left < 0 ? 0 : left;
  }

  bool get isLocked => hasLimit && timeSpentMinutes >= limitMinutes!;

  bool get is5MinWarning =>
      hasLimit && !isLocked && notifyAt5Min && remainingMinutes <= 5;

  bool get is10MinWarning =>
      hasLimit && !isLocked && notifyAt10Min && remainingMinutes <= 10;

  double get progress {
    if (!hasLimit) return 0.0;
    return (timeSpentMinutes / limitMinutes!).clamp(0.0, 1.0);
  }

  String get formattedTimeSpent {
    final hours = timeSpentMinutes ~/ 60;
    final minutes = timeSpentMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedLimit {
    if (!hasLimit) return 'No limit';
    final hours = limitMinutes! ~/ 60;
    final minutes = limitMinutes! % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    }
    return '${minutes}m';
  }

  AppUsageItem copyWith({
    String? id,
    String? name,
    String? packageName,
    AppCategory? category,
    int? timeSpentMinutes,
    int? limitMinutes,
    bool? notifyAt10Min,
    bool? notifyAt5Min,
    bool? isStrictLock,
    int? iconCodePoint,
    int? colorValue,
  }) {
    return AppUsageItem(
      id: id ?? this.id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      category: category ?? this.category,
      timeSpentMinutes: timeSpentMinutes ?? this.timeSpentMinutes,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      notifyAt10Min: notifyAt10Min ?? this.notifyAt10Min,
      notifyAt5Min: notifyAt5Min ?? this.notifyAt5Min,
      isStrictLock: isStrictLock ?? this.isStrictLock,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'packageName': packageName,
      'category': category.name,
      'timeSpentMinutes': timeSpentMinutes,
      'limitMinutes': limitMinutes,
      'notifyAt10Min': notifyAt10Min,
      'notifyAt5Min': notifyAt5Min,
      'isStrictLock': isStrictLock,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
    };
  }

  factory AppUsageItem.fromJson(Map<String, dynamic> json) {
    return AppUsageItem(
      id: json['id'] as String,
      name: json['name'] as String,
      packageName: json['packageName'] as String,
      category: AppCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => AppCategory.social,
      ),
      timeSpentMinutes: json['timeSpentMinutes'] as int? ?? 0,
      limitMinutes: json['limitMinutes'] as int?,
      notifyAt10Min: json['notifyAt10Min'] as bool? ?? true,
      notifyAt5Min: json['notifyAt5Min'] as bool? ?? true,
      isStrictLock: json['isStrictLock'] as bool? ?? false,
      iconCodePoint: json['iconCodePoint'] as int? ?? Icons.apps.codePoint,
      colorValue: json['colorValue'] as int? ?? 0xFF8B5CF6,
    );
  }
}

class FocusSession {
  final String id;
  final String title;
  final int targetMinutes;
  final int elapsedSeconds;
  final bool isRunning;
  final bool isCompleted;

  const FocusSession({
    required this.id,
    required this.title,
    required this.targetMinutes,
    this.elapsedSeconds = 0,
    this.isRunning = false,
    this.isCompleted = false,
  });

  int get remainingSeconds {
    final total = targetMinutes * 60;
    final left = total - elapsedSeconds;
    return left < 0 ? 0 : left;
  }

  double get progress {
    final total = targetMinutes * 60;
    if (total == 0) return 0.0;
    return (elapsedSeconds / total).clamp(0.0, 1.0);
  }

  String get formattedRemaining {
    final mins = remainingSeconds ~/ 60;
    final secs = remainingSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  FocusSession copyWith({
    String? id,
    String? title,
    int? targetMinutes,
    int? elapsedSeconds,
    bool? isRunning,
    bool? isCompleted,
  }) {
    return FocusSession(
      id: id ?? this.id,
      title: title ?? this.title,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isRunning: isRunning ?? this.isRunning,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
