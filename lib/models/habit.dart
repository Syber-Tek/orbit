import 'package:flutter/material.dart';

/// How a habit's repeat interval is measured.
enum HabitRepeatUnit { days, weeks, months, once }

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

  static const List<String> weekdayShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> weekdayLetter = [
    'Mo',
    'Tu',
    'We',
    'Th',
    'Fr',
    'Sa',
    'Su',
  ];

  static const List<String> monthShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final String id;
  final String title;
  final String category;
  final int iconCodePoint;
  final int colorValue;
  final int currentCount;
  final int targetCount;
  final String unit;
  final HabitTimeOfDay timeOfDay;
  final List<String> completedDates; // Stored as 'yyyy-MM-dd'
  final DateTime createdAt;

  /// Repeat interval. `1` means every day/week/month depending on [repeatUnit].
  final int repeatEvery;

  /// Unit the interval is measured in. Presets (daily/weekdays/weekends) are
  /// just shortcuts over this same engine.
  final HabitRepeatUnit repeatUnit;

  /// Weekdays the habit is due on when [repeatUnit] is weeks. Values are
  /// `DateTime.monday` (1) through `DateTime.sunday` (7).
  final List<int> repeatWeekdays;

  /// Day of the month when [repeatUnit] is months. `-1` means the last day of
  /// the month, which also clamps months that are too short.
  final int? repeatDayOfMonth;

  /// Anchor date used to decide which week/month counts. Falls back to
  /// [createdAt] so existing habits keep a stable schedule.
  final DateTime? repeatStart;

  /// Optional inclusive end date.
  final DateTime? repeatEnd;

  const Habit({
    required this.id,
    required this.title,
    required this.category,
    required this.iconCodePoint,
    required this.colorValue,
    this.currentCount = 0,
    required this.targetCount,
    this.unit = 'times',
    this.timeOfDay = HabitTimeOfDay.anytime,
    this.completedDates = const [],
    required this.createdAt,
    this.repeatEvery = 1,
    this.repeatUnit = HabitRepeatUnit.days,
    this.repeatWeekdays = const [],
    this.repeatDayOfMonth,
    this.repeatStart,
    this.repeatEnd,
  }) : assert(repeatEvery > 0);

  // --- Date helpers -------------------------------------------------------

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime addDays(DateTime date, int days) {
    // UTC has no DST, so adding exact days never slips an hour across a
    // daylight-saving boundary.
    final shifted = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(Duration(days: days));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static DateTime startOfWeek(DateTime date) {
    final day = dateOnly(date);
    return addDays(day, -(day.weekday - DateTime.monday));
  }

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static String formatShortDate(DateTime date) =>
      '${date.day} ${monthShort[date.month - 1]} ${date.year}';

  static String ordinal(int value) {
    if (value % 100 >= 11 && value % 100 <= 13) return '${value}th';
    switch (value % 10) {
      case 1:
        return '${value}st';
      case 2:
        return '${value}nd';
      case 3:
        return '${value}rd';
      default:
        return '${value}th';
    }
  }

  /// Human summary shared by the habit card and the add/edit sheet.
  static String describeSchedule({
    required int every,
    required HabitRepeatUnit unit,
    List<int> weekdays = const [],
    int? dayOfMonth,
    DateTime? start,
  }) {
    switch (unit) {
      case HabitRepeatUnit.days:
        return every == 1 ? 'Daily' : 'Every $every days';

      case HabitRepeatUnit.weeks:
        final days = weekdays.isEmpty
            ? <int>[]
            : (weekdays.toList()..sort());
        final isWeekdays =
            every == 1 && _sameDays(days, const [1, 2, 3, 4, 5]);
        final isWeekends = every == 1 && _sameDays(days, const [6, 7]);
        if (isWeekdays) return 'Weekdays';
        if (isWeekends) return 'Weekends';

        final everyLabel = every == 1 ? 'Weekly' : 'Every $every weeks';
        if (days.isEmpty) return everyLabel;
        if (every == 1 && days.length == 1) {
          return 'Every ${weekdayShort[days.first - 1]}';
        }
        final dayLabel = days.map((d) => weekdayShort[d - 1]).join(', ');
        return '$everyLabel · $dayLabel';

      case HabitRepeatUnit.months:
        final dayLabel = dayOfMonth == null
            ? ''
            : dayOfMonth == -1
            ? ' · Last day'
            : ' · ${ordinal(dayOfMonth)}';
        return every == 1 ? 'Monthly$dayLabel' : 'Every $every months$dayLabel';

      case HabitRepeatUnit.once:
        return start == null
            ? 'One time'
            : 'Once · ${formatShortDate(start)}';
    }
  }

  static bool _sameDays(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // --- Schedule -----------------------------------------------------------

  DateTime get scheduleStart => dateOnly(repeatStart ?? createdAt);

  bool get isPlainDaily =>
      repeatUnit == HabitRepeatUnit.days && repeatEvery == 1;

  /// Whether this habit is due on [date].
  bool isScheduledOn(DateTime date) {
    final day = dateOnly(date);
    final start = scheduleStart;
    if (day.isBefore(start)) return false;

    final end = repeatEnd;
    if (end != null && day.isAfter(dateOnly(end))) return false;

    switch (repeatUnit) {
      case HabitRepeatUnit.once:
        return isSameDay(day, start);

      case HabitRepeatUnit.days:
        final offset = daysBetween(start, day);
        return offset % repeatEvery == 0;

      case HabitRepeatUnit.weeks:
        final days = repeatWeekdays.isEmpty
            ? <int>[start.weekday]
            : repeatWeekdays;
        if (!days.contains(day.weekday)) return false;
        // Anchor the cadence to the first actual occurrence, not the creation
        // week, so creating an "every 2 weeks on Monday" habit on a Wednesday
        // still starts next Monday instead of skipping it.
        final firstDue = _firstWeeklyOccurrence(start, days);
        final weeks = daysBetween(startOfWeek(firstDue), startOfWeek(day)) ~/ 7;
        return weeks % repeatEvery == 0;

      case HabitRepeatUnit.months:
        final target = repeatDayOfMonth;
        if (target == null) return false;
        final firstDue = _firstMonthlyOccurrence(start, target);
        final monthOffset =
            (day.year - firstDue.year) * 12 + (day.month - firstDue.month);
        if (monthOffset < 0 || monthOffset % repeatEvery != 0) return false;
        final lastDay = daysInMonth(day.year, day.month);
        final expected = target == -1 ? lastDay : target.clamp(1, lastDay);
        return day.day == expected;
    }
  }

  static DateTime _firstWeeklyOccurrence(DateTime start, List<int> days) {
    var cursor = start;
    for (var i = 0; i < 7; i++) {
      if (days.contains(cursor.weekday)) return cursor;
      cursor = addDays(cursor, 1);
    }
    return start;
  }

  static DateTime _firstMonthlyOccurrence(DateTime start, int target) {
    var year = start.year;
    var month = start.month;
    var lastDay = daysInMonth(year, month);
    var expected = target == -1 ? lastDay : target.clamp(1, lastDay);
    if (start.day > expected) {
      month += 1;
      if (month > 12) {
        month = 1;
        year += 1;
      }
      lastDay = daysInMonth(year, month);
      expected = target == -1 ? lastDay : target.clamp(1, lastDay);
    }
    return DateTime(year, month, expected);
  }

  bool get isDueToday => isScheduledOn(DateTime.now());

  /// First occurrence on or after [from]. Returns null for a finished one-off
  /// or when nothing is due within a ten year window.
  DateTime? nextDueDate({DateTime? from}) {
    final base = dateOnly(from ?? DateTime.now());
    if (repeatUnit == HabitRepeatUnit.once && base.isAfter(scheduleStart)) {
      return null;
    }
    final end = repeatEnd;
    if (end != null && base.isAfter(dateOnly(end))) return null;

    var cursor = base;
    for (var i = 0; i < 3660; i++) {
      if (isScheduledOn(cursor)) return cursor;
      cursor = addDays(cursor, 1);
    }
    return null;
  }

  /// Most recent occurrence strictly before [date].
  DateTime? previousDueDate(DateTime date) {
    var cursor = addDays(dateOnly(date), -1);
    if (cursor.isBefore(scheduleStart)) return null;
    for (var i = 0; i < 3660; i++) {
      if (isScheduledOn(cursor)) return cursor;
      cursor = addDays(cursor, -1);
      if (cursor.isBefore(scheduleStart)) return null;
    }
    return null;
  }

  // --- Completion / streak ------------------------------------------------

  bool isCompletedOn(DateTime date) =>
      completedDates.contains(dateKey(date));

  bool get isCompletedToday => isCompletedOn(DateTime.now());

  /// Consecutive completed occurrences ending at the latest due date.
  ///
  /// If today is due but not completed yet, the streak so far still reflects
  /// the previous occurrence, so checking in late in the day does not make the
  /// number flicker to zero.
  int get currentStreak => streakAsOf(DateTime.now());

  int streakAsOf(DateTime asOf) {
    final today = dateOnly(asOf);
    final completed = completedDates.toSet();

    DateTime? cursor;
    for (var i = 0; i < 3661; i++) {
      final candidate = addDays(today, -i);
      if (isScheduledOn(candidate)) {
        cursor = candidate;
        break;
      }
    }
    if (cursor == null) return 0;

    if (isSameDay(cursor, today) && !completed.contains(dateKey(cursor))) {
      cursor = previousDueDate(cursor);
      if (cursor == null) return 0;
    }

    var streak = 0;
    for (var i = 0; i < 3660; i++) {
      if (cursor == null || !completed.contains(dateKey(cursor))) break;
      streak++;
      cursor = previousDueDate(cursor);
    }
    return streak;
  }

  // --- Display ------------------------------------------------------------

  String get scheduleSummary => describeSchedule(
    every: repeatEvery,
    unit: repeatUnit,
    weekdays: repeatWeekdays,
    dayOfMonth: repeatDayOfMonth,
    start: repeatStart ?? createdAt,
  );

  /// Short date of the next occurrence, or null when it is today / has passed.
  String? get nextDueLabel {
    final next = nextDueDate();
    if (next == null || isSameDay(next, DateTime.now())) return null;
    return formatShortDate(next);
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
    HabitTimeOfDay? timeOfDay,
    List<String>? completedDates,
    DateTime? createdAt,
    int? repeatEvery,
    HabitRepeatUnit? repeatUnit,
    List<int>? repeatWeekdays,
    int? repeatDayOfMonth,
    bool clearRepeatDayOfMonth = false,
    DateTime? repeatStart,
    bool clearRepeatStart = false,
    DateTime? repeatEnd,
    bool clearRepeatEnd = false,
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
      timeOfDay: timeOfDay ?? this.timeOfDay,
      completedDates: completedDates ?? this.completedDates,
      createdAt: createdAt ?? this.createdAt,
      repeatEvery: repeatEvery ?? this.repeatEvery,
      repeatUnit: repeatUnit ?? this.repeatUnit,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      repeatDayOfMonth: clearRepeatDayOfMonth
          ? null
          : (repeatDayOfMonth ?? this.repeatDayOfMonth),
      repeatStart: clearRepeatStart ? null : (repeatStart ?? this.repeatStart),
      repeatEnd: clearRepeatEnd ? null : (repeatEnd ?? this.repeatEnd),
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
      'timeOfDay': timeOfDay.index,
      'completedDates': completedDates,
      'createdAt': createdAt.toIso8601String(),
      // Kept for rollback compatibility with builds that only understand the
      // old three-value enum.
      'frequency': _legacyFrequencyIndex,
      'repeatEvery': repeatEvery,
      'repeatUnit': repeatUnit.index,
      'repeatWeekdays': repeatWeekdays,
      'repeatDayOfMonth': repeatDayOfMonth,
      'repeatStart': repeatStart?.toIso8601String(),
      'repeatEnd': repeatEnd?.toIso8601String(),
    };
  }

  int get _legacyFrequencyIndex {
    if (repeatUnit == HabitRepeatUnit.days) return 0;
    if (repeatUnit == HabitRepeatUnit.weeks && repeatEvery == 1) {
      final days = repeatWeekdays.toList()..sort();
      if (_sameDays(days, const [1, 2, 3, 4, 5])) return 1;
      if (_sameDays(days, const [6, 7])) return 2;
    }
    return 0;
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    final legacyFrequency = json['frequency'] as int? ?? 0;
    final hasSchedule = json.containsKey('repeatUnit');

    var repeatUnit = HabitRepeatUnit.days;
    var repeatEvery = 1;
    var repeatWeekdays = const <int>[];
    int? repeatDayOfMonth;

    if (hasSchedule) {
      final rawUnit = json['repeatUnit'] as int? ?? 0;
      repeatUnit = rawUnit >= 0 && rawUnit < HabitRepeatUnit.values.length
          ? HabitRepeatUnit.values[rawUnit]
          : HabitRepeatUnit.days;
      repeatEvery = (json['repeatEvery'] as int? ?? 1).clamp(1, 1000);
      repeatWeekdays =
          (json['repeatWeekdays'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .where((d) => d >= 1 && d <= 7)
              .toList() ??
          const <int>[];
      final rawDay = (json['repeatDayOfMonth'] as num?)?.toInt();
      repeatDayOfMonth =
          rawDay != null && (rawDay == -1 || (rawDay >= 1 && rawDay <= 31))
          ? rawDay
          : null;
    } else if (legacyFrequency == 1) {
      repeatUnit = HabitRepeatUnit.weeks;
      repeatWeekdays = const [1, 2, 3, 4, 5];
    } else if (legacyFrequency == 2) {
      repeatUnit = HabitRepeatUnit.weeks;
      repeatWeekdays = const [6, 7];
    }

    DateTime? parseDate(Object? value) {
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    return Habit(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      currentCount: json['currentCount'] as int? ?? 0,
      targetCount: json['targetCount'] as int,
      unit: json['unit'] as String? ?? 'times',
      timeOfDay: HabitTimeOfDay.values[json['timeOfDay'] as int? ?? 0],
      completedDates:
          (json['completedDates'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      repeatEvery: repeatEvery,
      repeatUnit: repeatUnit,
      repeatWeekdays: repeatWeekdays,
      repeatDayOfMonth: repeatDayOfMonth,
      repeatStart: parseDate(json['repeatStart']),
      repeatEnd: parseDate(json['repeatEnd']),
    );
  }
}
