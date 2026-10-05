import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orbit/models/habit.dart';
import 'package:orbit/models/ledger.dart';
import 'package:orbit/models/note.dart';
import 'package:orbit/models/screen_time.dart';
import 'package:orbit/models/task.dart';
import 'package:orbit/services/screen_time_provider.dart' show ScreenTimeState;

/// Centralized offline persistence for all Orbit features.
///
/// Keeps Habits, Tasks/Alarms, Ledger, Notes, and Screen Time limits
/// persistent across app restarts and device reboots.
class PersistenceService {
  PersistenceService._();

  static final PersistenceService instance = PersistenceService._();

  static const _kTasksKey = 'orbit.tasks.v1';
  static const _kScreenTimeKey = 'orbit.screen_time.v1';
  static const _kHabitsKey = 'orbit.habits.v1';
  static const _kTransactionsKey = 'orbit.transactions.v1';
  static const _kMonthlyBudgetKey = 'orbit.monthly_budget.v1';
  static const _kDailyBudgetKey = 'orbit.daily_budget.v1';
  static const _kNotesKey = 'orbit.notes.v1';
  static const _kNativeAppLimitsKey = 'app_limits_json';
  static const _kNavBarOpacityKey = 'orbit.nav_bar_opacity.v1';
  static const _kHapticsEnabledKey = 'orbit.haptics_enabled.v1';
  static const _kThemeModeKey = 'orbit.theme_mode.v1';
  static const _kActiveTabKey = 'orbit.active_tab.v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> init() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('PersistenceService must be initialized before use.');
    }
    return _prefs!;
  }

  // --- Habits ---

  List<Habit>? loadHabits() {
    try {
      final raw = _prefs?.getString(_kHabitsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Habit.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('Failed to decode stored habits: $error');
      return null;
    }
  }

  Future<void> saveHabits(List<Habit> habits) async {
    try {
      final p = _prefs ?? await init();
      await p.setString(
        _kHabitsKey,
        jsonEncode(habits.map((h) => h.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('Failed to save habits: $error');
    }
  }

  // --- Tasks ---

  Future<List<TaskItem>> loadTasks() async {
    final p = _prefs ?? await init();
    final raw = p.getString(_kTasksKey);
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
    try {
      final p = _prefs ?? await init();
      await p.setString(
        _kTasksKey,
        jsonEncode(tasks.map((task) => task.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('Failed to save tasks: $error');
    }
  }

  // --- Ledger / Budget ---

  List<TransactionItem>? loadTransactions() {
    try {
      final raw = _prefs?.getString(_kTransactionsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('Failed to decode stored transactions: $error');
      return null;
    }
  }

  Future<void> saveTransactions(List<TransactionItem> items) async {
    try {
      final p = _prefs ?? await init();
      await p.setString(
        _kTransactionsKey,
        jsonEncode(items.map((i) => i.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('Failed to save transactions: $error');
    }
  }

  double? loadMonthlyBudget() {
    return _prefs?.getDouble(_kMonthlyBudgetKey);
  }

  Future<void> saveMonthlyBudget(double amount) async {
    final p = _prefs ?? await init();
    await p.setDouble(_kMonthlyBudgetKey, amount);
  }

  double? loadDailyBudget() {
    return _prefs?.getDouble(_kDailyBudgetKey);
  }

  Future<void> saveDailyBudget(double amount) async {
    final p = _prefs ?? await init();
    await p.setDouble(_kDailyBudgetKey, amount);
  }

  // --- Notes ---

  List<Note>? loadNotes() {
    try {
      final raw = _prefs?.getString(_kNotesKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Note.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('Failed to decode stored notes: $error');
      return null;
    }
  }

  Future<void> saveNotes(List<Note> notes) async {
    try {
      final p = _prefs ?? await init();
      await p.setString(
        _kNotesKey,
        jsonEncode(notes.map((n) => n.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('Failed to save notes: $error');
    }
  }

  // --- Screen time ---

  Future<ScreenTimeState?> loadScreenTime() async {
    final p = _prefs ?? await init();
    final raw = p.getString(_kScreenTimeKey);
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
    try {
      final p = _prefs ?? await init();
      await p.setString(
        _kScreenTimeKey,
        jsonEncode({
          'apps': state.apps.map((app) => app.toJson()).toList(),
          'dailyGoalMinutes': state.dailyGoalMinutes,
          'pickupsToday': state.pickupsToday,
          'hourlyUsage': state.hourlyUsage,
        }),
      );
      await syncLimitsToNative(state.apps);
    } catch (error) {
      debugPrint('Failed to save screen time: $error');
    }
  }

  /// Mirrors configured app limits to [app_limits_json] for the Kotlin
  /// AppMonitorService and ScreenTimeAccessibilityService background daemons.
  Future<void> syncLimitsToNative(List<AppUsageItem> apps) async {
    try {
      final p = _prefs ?? await init();
      final nativeLimits = apps
          .where((a) => a.hasLimit)
          .map((a) => {
                'packageName': a.packageName,
                'appName': a.name,
                'limitMinutes': a.limitMinutes ?? 0,
                'isEnabled': true,
              })
          .toList();
      await p.setString(_kNativeAppLimitsKey, jsonEncode(nativeLimits));
    } catch (error) {
      debugPrint('Failed to sync limits to native mirror: $error');
    }
  }

  // --- UI Settings ---

  double loadNavBarOpacity() {
    return _prefs?.getDouble(_kNavBarOpacityKey) ?? 0.70;
  }

  Future<void> saveNavBarOpacity(double opacity) async {
    final p = _prefs ?? await init();
    await p.setDouble(_kNavBarOpacityKey, opacity);
  }

  bool loadHapticsEnabled() {
    return _prefs?.getBool(_kHapticsEnabledKey) ?? true;
  }

  Future<void> saveHapticsEnabled(bool enabled) async {
    final p = _prefs ?? await init();
    await p.setBool(_kHapticsEnabledKey, enabled);
  }

  ThemeMode loadThemeMode() {
    final raw = _prefs?.getString(_kThemeModeKey);
    if (raw == 'light') return ThemeMode.light;
    if (raw == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final p = _prefs ?? await init();
    String val = 'system';
    if (mode == ThemeMode.light) val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    await p.setString(_kThemeModeKey, val);
  }

  int loadActiveTab() {
    return _prefs?.getInt(_kActiveTabKey) ?? 0;
  }

  Future<void> saveActiveTab(int tabIndex) async {
    final p = _prefs ?? await init();
    await p.setInt(_kActiveTabKey, tabIndex);
  }
}
