import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/habit.dart';

Habit _habit({
  String id = 'h1',
  DateTime? createdAt,
  DateTime? start,
  int every = 1,
  HabitRepeatUnit unit = HabitRepeatUnit.days,
  List<int> weekdays = const [],
  int? dayOfMonth,
  DateTime? end,
  List<String> completed = const [],
}) {
  return Habit(
    id: id,
    title: 'Test habit',
    category: 'Health',
    iconCodePoint: Icons.favorite_rounded.codePoint,
    colorValue: 0xFF10B981,
    targetCount: 1,
    unit: 'times',
    completedDates: completed,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    repeatEvery: every,
    repeatUnit: unit,
    repeatWeekdays: weekdays,
    repeatDayOfMonth: dayOfMonth,
    repeatStart: start,
    repeatEnd: end,
  );
}

void main() {
  group('daily schedule', () {
    test('is due every day on and after the start', () {
      final habit = _habit(createdAt: DateTime(2026, 1, 1));

      expect(habit.isScheduledOn(DateTime(2025, 12, 31)), isFalse);
      expect(habit.isScheduledOn(DateTime(2026, 1, 1)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 1, 2)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 3, 15)), isTrue);
    });

    test('honours the every-N-days interval', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 1),
        every: 3,
      );

      expect(habit.isScheduledOn(DateTime(2026, 1, 1)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 1, 2)), isFalse);
      expect(habit.isScheduledOn(DateTime(2026, 1, 4)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 1, 7)), isTrue);
    });
  });

  group('week schedule', () {
    test('weekdays preset only matches Mon-Fri', () {
      final habit = _habit(
        unit: HabitRepeatUnit.weeks,
        weekdays: const [1, 2, 3, 4, 5],
      );

      expect(habit.isScheduledOn(DateTime(2026, 1, 5)), isTrue); // Mon
      expect(habit.isScheduledOn(DateTime(2026, 1, 9)), isTrue); // Fri
      expect(habit.isScheduledOn(DateTime(2026, 1, 10)), isFalse); // Sat
      expect(habit.isScheduledOn(DateTime(2026, 1, 11)), isFalse); // Sun
    });

    test('every 2 weeks on Tuesday skips the in-between week', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 5), // Monday
        unit: HabitRepeatUnit.weeks,
        every: 2,
        weekdays: const [DateTime.tuesday],
      );

      expect(habit.isScheduledOn(DateTime(2026, 1, 6)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 1, 13)), isFalse);
      expect(habit.isScheduledOn(DateTime(2026, 1, 20)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 2, 3)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 1, 7)), isFalse);
    });

    test('multiple weekdays share the same interval week', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 5), // Monday
        unit: HabitRepeatUnit.weeks,
        every: 3,
        weekdays: const [DateTime.monday, DateTime.thursday],
      );

      expect(habit.isScheduledOn(DateTime(2026, 1, 5)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 1, 8)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 1, 12)), isFalse);
      expect(habit.isScheduledOn(DateTime(2026, 1, 26)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 1, 29)), isTrue);
    });

    test('anchors the interval to the first occurrence, not creation week', () {
      // Created on a Wednesday, due Mondays every 2 weeks.
      final habit = _habit(
        createdAt: DateTime(2026, 1, 7), // Wednesday
        unit: HabitRepeatUnit.weeks,
        every: 2,
        weekdays: const [DateTime.monday],
      );

      expect(habit.isScheduledOn(DateTime(2026, 1, 5)), isFalse);
      expect(habit.isScheduledOn(DateTime(2026, 1, 12)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 1, 19)), isFalse);
      expect(habit.isScheduledOn(DateTime(2026, 1, 26)), isTrue);
    });
  });

  group('month schedule', () {
    test('every month on the 15th', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 15),
        unit: HabitRepeatUnit.months,
        dayOfMonth: 15,
      );

      expect(habit.isScheduledOn(DateTime(2026, 1, 15)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 2, 15)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 3, 15)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 2, 14)), isFalse);
    });

    test('every 2 months skips the odd months', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 15),
        unit: HabitRepeatUnit.months,
        every: 2,
        dayOfMonth: 15,
      );

      expect(habit.isScheduledOn(DateTime(2026, 1, 15)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 2, 15)), isFalse);
      expect(habit.isScheduledOn(DateTime(2026, 3, 15)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 5, 15)), isTrue);
    });

    test('anchors the interval to the first occurrence month', () {
      // Created on the 20th, due on the 15th every 2 months.
      final habit = _habit(
        createdAt: DateTime(2026, 1, 20),
        unit: HabitRepeatUnit.months,
        every: 2,
        dayOfMonth: 15,
      );

      expect(habit.isScheduledOn(DateTime(2026, 1, 15)), isFalse);
      expect(habit.isScheduledOn(DateTime(2026, 2, 15)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 3, 15)), isFalse);
      expect(habit.isScheduledOn(DateTime(2026, 4, 15)), isTrue);
    });

    test('day 31 clamps to the last day of shorter months', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 31),
        unit: HabitRepeatUnit.months,
        dayOfMonth: 31,
      );

      expect(habit.isScheduledOn(DateTime(2026, 1, 31)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 2, 28)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 3, 31)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 4, 30)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 4, 31)), isFalse);
    });

    test('last-day option follows February in a leap year', () {
      final habit = _habit(
        createdAt: DateTime(2028, 1, 31),
        unit: HabitRepeatUnit.months,
        dayOfMonth: -1,
      );

      expect(habit.isScheduledOn(DateTime(2028, 2, 29)), isTrue);
      expect(habit.isScheduledOn(DateTime(2028, 2, 28)), isFalse);
      expect(habit.isScheduledOn(DateTime(2028, 4, 30)), isTrue);
    });
  });

  group('one-off schedule', () {
    test('only matches the chosen date', () {
      final habit = _habit(
        unit: HabitRepeatUnit.once,
        start: DateTime(2026, 6, 12),
      );

      expect(habit.isScheduledOn(DateTime(2026, 6, 11)), isFalse);
      expect(habit.isScheduledOn(DateTime(2026, 6, 12)), isTrue);
      expect(habit.isScheduledOn(DateTime(2026, 6, 13)), isFalse);
      expect(habit.nextDueDate(from: DateTime(2026, 6, 13)), isNull);
    });
  });

  test('end date stops future occurrences', () {
    final habit = _habit(
      createdAt: DateTime(2026, 1, 1),
      end: DateTime(2026, 1, 3),
    );

    expect(habit.isScheduledOn(DateTime(2026, 1, 3)), isTrue);
    expect(habit.isScheduledOn(DateTime(2026, 1, 4)), isFalse);
  });

  group('next due date', () {
    test('returns the next weekly occurrence', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 5),
        unit: HabitRepeatUnit.weeks,
        weekdays: const [DateTime.tuesday],
      );

      expect(habit.nextDueDate(from: DateTime(2026, 1, 7)), DateTime(2026, 1, 13));
      expect(habit.nextDueDate(from: DateTime(2026, 1, 13)), DateTime(2026, 1, 13));
    });

    test('returns the next monthly occurrence', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 15),
        unit: HabitRepeatUnit.months,
        dayOfMonth: 15,
      );

      expect(habit.nextDueDate(from: DateTime(2026, 1, 16)), DateTime(2026, 2, 15));
    });
  });

  group('streak', () {
    test('counts consecutive daily completions', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 1),
        completed: const ['2026-01-01', '2026-01-02', '2026-01-03'],
      );

      expect(habit.streakAsOf(DateTime(2026, 1, 3)), 3);
    });

    test('today not completed yet keeps the previous streak', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 1),
        completed: const ['2026-01-01', '2026-01-02', '2026-01-03'],
      );

      expect(habit.streakAsOf(DateTime(2026, 1, 4)), 3);
    });

    test('a missed occurrence resets the streak', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 1),
        completed: const ['2026-01-01', '2026-01-02', '2026-01-04'],
      );

      expect(habit.streakAsOf(DateTime(2026, 1, 4)), 1);
      expect(habit.streakAsOf(DateTime(2026, 1, 5)), 1);
    });

    test('weekly streaks count occurrences, not days', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 5),
        unit: HabitRepeatUnit.weeks,
        weekdays: const [DateTime.tuesday],
        completed: const ['2026-01-06', '2026-01-13'],
      );

      expect(habit.streakAsOf(DateTime(2026, 1, 19)), 2);
    });

    test('off-schedule days do not break a streak', () {
      final habit = _habit(
        createdAt: DateTime(2026, 1, 5),
        unit: HabitRepeatUnit.weeks,
        weekdays: const [DateTime.tuesday],
        completed: const ['2026-01-06', '2026-01-13'],
      );

      // Wednesday through Monday are not due at all.
      expect(habit.streakAsOf(DateTime(2026, 1, 14)), 2);
    });
  });

  group('display', () {
    test('summarises presets and custom schedules', () {
      expect(
        Habit.describeSchedule(every: 1, unit: HabitRepeatUnit.days),
        'Daily',
      );
      expect(
        Habit.describeSchedule(
          every: 1,
          unit: HabitRepeatUnit.weeks,
          weekdays: const [1, 2, 3, 4, 5],
        ),
        'Weekdays',
      );
      expect(
        Habit.describeSchedule(
          every: 2,
          unit: HabitRepeatUnit.weeks,
          weekdays: const [DateTime.tuesday],
        ),
        'Every 2 weeks · Tue',
      );
      expect(
        Habit.describeSchedule(
          every: 1,
          unit: HabitRepeatUnit.months,
          dayOfMonth: 15,
        ),
        'Monthly · 15th',
      );
      expect(
        Habit.describeSchedule(
          every: 1,
          unit: HabitRepeatUnit.months,
          dayOfMonth: -1,
        ),
        'Monthly · Last day',
      );
    });
  });

  group('persistence', () {
    test('round-trips the new schedule fields', () {
      final original = _habit(
        id: 'abc',
        unit: HabitRepeatUnit.weeks,
        every: 2,
        weekdays: const [DateTime.monday, DateTime.friday],
        start: DateTime(2026, 2, 2),
        end: DateTime(2026, 12, 31),
        completed: const ['2026-02-02'],
      );

      final restored = Habit.fromJson(original.toJson());

      expect(restored.repeatUnit, HabitRepeatUnit.weeks);
      expect(restored.repeatEvery, 2);
      expect(restored.repeatWeekdays, const [1, 5]);
      expect(restored.repeatStart, DateTime(2026, 2, 2));
      expect(restored.repeatEnd, DateTime(2026, 12, 31));
      expect(restored.completedDates, const ['2026-02-02']);
    });

    test('migrates legacy frequency values', () {
      Map<String, dynamic> legacy(int frequency) => {
        'id': 'old',
        'title': 'Legacy',
        'category': 'Health',
        'iconCodePoint': Icons.favorite_rounded.codePoint,
        'colorValue': 0xFF10B981,
        'targetCount': 1,
        'frequency': frequency,
        'timeOfDay': 0,
        'completedDates': <String>[],
        'createdAt': '2026-01-01T00:00:00.000',
      };

      final daily = Habit.fromJson(legacy(0));
      expect(daily.repeatUnit, HabitRepeatUnit.days);
      expect(daily.repeatEvery, 1);

      final weekdays = Habit.fromJson(legacy(1));
      expect(weekdays.repeatUnit, HabitRepeatUnit.weeks);
      expect(weekdays.repeatWeekdays, const [1, 2, 3, 4, 5]);

      final weekends = Habit.fromJson(legacy(2));
      expect(weekends.repeatUnit, HabitRepeatUnit.weeks);
      expect(weekends.repeatWeekdays, const [6, 7]);
    });

    test('survives a corrupt repeat unit index', () {
      final json = _habit().toJson();
      json['repeatUnit'] = 99;

      final restored = Habit.fromJson(json);
      expect(restored.repeatUnit, HabitRepeatUnit.days);
    });
  });
}
