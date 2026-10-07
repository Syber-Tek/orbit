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
        streak: 0,
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
        streak: 0,
        timeOfDay: HabitTimeOfDay.anytime,
        completedDates: const [],
        createdAt: now,
      ),
    ];
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void toggleHabit(String id) {
    final today = _dateKey(DateTime.now());
    Habit? completed;

    state = state.map((habit) {
      if (habit.id == id) {
        final isDone = habit.completedDates.contains(today);
        final newDates = List<String>.from(habit.completedDates);

        if (isDone) {
          newDates.remove(today);
          return habit.copyWith(
            completedDates: newDates,
            streak: habit.streak > 0 ? habit.streak - 1 : 0,
            currentCount: 0,
          );
        } else {
          newDates.add(today);
          final updated = habit.copyWith(
            completedDates: newDates,
            streak: habit.streak + 1,
            currentCount: habit.targetCount,
          );
          completed = updated;
          return updated;
        }
      }
      return habit;
    }).toList();
    PersistenceService.instance.saveHabits(state);

    // Celebrate milestone streaks when a habit crosses one.
    final done = completed;
    if (done != null) {
      unawaited(
        NotificationService.instance.showStreakMilestone(done),
      );
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

final filteredHabitsProvider = Provider<List<Habit>>((ref) {
  final habits = ref.watch(habitListProvider);
  final filter = ref.watch(selectedHabitFilterProvider);

  if (filter == null) return habits;
  return habits.where((h) => h.timeOfDay == filter || h.timeOfDay == HabitTimeOfDay.anytime).toList();
});

final overallStreakProvider = Provider<int>((ref) {
  final habits = ref.watch(habitListProvider);
  if (habits.isEmpty) return 0;
  return habits.map((h) => h.streak).reduce((a, b) => a > b ? a : b);
});

final dailyCompletionRateProvider = Provider<double>((ref) {
  final habits = ref.watch(habitListProvider);
  if (habits.isEmpty) return 0.0;
  final done = habits.where((h) => h.isCompletedToday).length;
  return done / habits.length;
});
