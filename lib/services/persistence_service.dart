import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orbit/models/screen_time.dart';
import 'package:orbit/models/task.dart';
import 'package:orbit/services/screen_time_provider.dart' show ScreenTimeState;

/// JSON-backed persistence for the state that must outlive a process restart.
///
/// Alarms are the hard requirement: an OS-scheduled notification is only
/// meaningful if the task it belongs to is still there on next launch, and the
/// screen time limits decide which warnings are pending.
class PersistenceService {
  PersistenceService._();

  static final PersistenceService instance = PersistenceService._();

  static const _kTasksKey = 'orbit.tasks.v1';
  static const _kScreenTimeKey = 'orbit.screen_time.v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _open() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  // --- Tasks ---

  Future<List<TaskItem>> loadTasks() async {
    final prefs = await _open();
    final raw = prefs.getString(_kTasksKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('Failed to decode stored tasks: $error');
      return const [];
    }
  }

  Future<void> saveTasks(List<TaskItem> tasks) async {
    final prefs = await _open();
    await prefs.setString(
      _kTasksKey,
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
  }

  // --- Screen time ---

  /// Returns null when nothing has been stored yet, which lets the caller fall
  /// back to the seeded defaults.
  Future<ScreenTimeState?> loadScreenTime() async {
    final prefs = await _open();
    final raw = prefs.getString(_kScreenTimeKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final apps = (json['apps'] as List<dynamic>)
          .map((e) => AppUsageItem.fromJson(e as Map<String, dynamic>))
          .toList();

      return ScreenTimeState(
        apps: apps,
        dailyGoalMinutes: json['dailyGoalMinutes'] as int? ?? 480,
        pickupsToday: json['pickupsToday'] as int? ?? 0,
        hourlyUsage: (json['hourlyUsage'] as List<dynamic>?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [0, 0, 0, 0, 0, 0],
      );
    } catch (error) {
      debugPrint('Failed to decode stored screen time: $error');
      return null;
    }
  }

  Future<void> saveScreenTime(ScreenTimeState state) async {
    final prefs = await _open();
    await prefs.setString(
      _kScreenTimeKey,
      jsonEncode({
        'apps': state.apps.map((app) => app.toJson()).toList(),
        'dailyGoalMinutes': state.dailyGoalMinutes,
        'pickupsToday': state.pickupsToday,
        'hourlyUsage': state.hourlyUsage,
      }),
    );
  }
}
