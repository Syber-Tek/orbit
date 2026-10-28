import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/habit.dart';
import 'package:orbit/services/notification_service.dart';
import 'package:orbit/services/persistence_service.dart';

class HabitListNotifier extends Notifier<List<Habit>> {
  @override
  List<Habit> build() {
    final saved = PersistenceService.instance.loadHabits();
    if (saved != null) return saved;

    final now = DateTime.now();
    return [
      Habit(
        id: '1',
        title: 'Daily Workout',
        category: 'Fitness',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
        colorValue: 0xFFEC4899, // Pink / Coral
        targetCount: 45,
        currentCount: 0,
        unit: 'mins',
        timeOfDay: HabitTimeOfDay.morning,
        completedDates: const [],
        createdAt: now,
      ),
      Habit(
        id: '2',
        title: 'Drink 2.5L Water',
        category: 'Health',
        iconCodePoint: Icons.water_drop_rounded.codePoint,
        colorValue: 0xFF3B82F6, // Blue
        targetCount: 2500,
        currentCount: 0,
        unit: 'ml',
        timeOfDay: HabitTimeOfDay.anytime,
        completedDates: const [],
        createdAt: now,
      ),
    ];
  }

  void toggleHabit(String id) {
    final now = DateTime.now();
    final today = Habit.dateKey(now);
    Habit? completed;

    state = state.map((habit) {
      if (habit.id != id) return habit;
      // Off-schedule days cannot be checked in; the card is read-only there.
      if (!habit.isScheduledOn(now)) return habit;

      final isDone = habit.completedDates.contains(today);
      final newDates = List<String>.from(habit.completedDates);

      if (isDone) {
        newDates.remove(today);
        return habit.copyWith(completedDates: newDates, currentCount: 0);
      }

      newDates.add(today);
      final updated = habit.copyWith(
        completedDates: newDates,
        currentCount: habit.targetCount,
      );
      completed = updated;
      return updated;
    }).toList();
    PersistenceService.instance.saveHabits(state);

    // Celebrate milestone streaks when a habit crosses one.
    final done = completed;
    if (done != null) {
      unawaited(NotificationService.instance.showStreakMilestone(done));
    }
  }

  void addHabit(Habit habit) {
    state = [habit, ...state];
    PersistenceService.instance.saveHabits(state);
  }

  void updateHabit(Habit updated) {
    state = state.map((h) => h.id == updated.id ? updated : h).toList();
    PersistenceService.instance.saveHabits(state);
  }

  void deleteHabit(String id) {
    state = state.where((h) => h.id != id).toList();
    PersistenceService.instance.saveHabits(state);
  }
}

final habitListProvider = NotifierProvider<HabitListNotifier, List<Habit>>(
  HabitListNotifier.new,
);

class HabitFilterNotifier extends Notifier<HabitTimeOfDay?> {
  @override
  HabitTimeOfDay? build() => null;

  void setFilter(HabitTimeOfDay? filter) {
    state = filter;
  }
}

final selectedHabitFilterProvider = NotifierProvider<HabitFilterNotifier, HabitTimeOfDay?>(
  HabitFilterNotifier.new,
);

/// Habits due on the current day, regardless of the time-of-day filter.
final dueTodayHabitsProvider = Provider<List<Habit>>((ref) {
  final habits = ref.watch(habitListProvider);
  final now = DateTime.now();
  return habits.where((h) => h.isScheduledOn(now)).toList();
});

/// Habits that are not due today. Shown in the collapsed "Not today" section.
/// Past one-off habits drop out once their date has passed.
final offDayHabitsProvider = Provider<List<Habit>>((ref) {
  final habits = ref.watch(habitListProvider);
  final now = DateTime.now();
  final today = Habit.dateOnly(now);
  return habits.where((h) {
    if (h.isScheduledOn(now)) return false;
    if (h.repeatUnit == HabitRepeatUnit.once &&
        h.scheduleStart.isBefore(today)) {
      return false;
    }
    return true;
  }).toList();
});

/// The list rendered under "Today's Habits": due today + time-of-day filter.
final filteredHabitsProvider = Provider<List<Habit>>((ref) {
  final habits = ref.watch(dueTodayHabitsProvider);
  final filter = ref.watch(selectedHabitFilterProvider);

  if (filter == null) return habits;
  return habits.where((h) => h.timeOfDay == filter || h.timeOfDay == HabitTimeOfDay.anytime).toList();
});

final overallStreakProvider = Provider<int>((ref) {
  final habits = ref.watch(habitListProvider);
  if (habits.isEmpty) return 0;
  return habits.map((h) => h.currentStreak).reduce((a, b) => a > b ? a : b);
});

final dailyCompletionRateProvider = Provider<double>((ref) {
  final habits = ref.watch(dueTodayHabitsProvider);
  if (habits.isEmpty) return 0.0;
  final done = habits.where((h) => h.isCompletedToday).length;
  return done / habits.length;
});
