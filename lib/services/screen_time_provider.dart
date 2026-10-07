import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/screen_time.dart';
import 'package:orbit/services/focus_foreground_service.dart';
import 'package:orbit/services/notification_service.dart';
import 'package:orbit/services/persistence_service.dart';

class ScreenTimeState {
  final List<AppUsageItem> apps;
  final int dailyGoalMinutes;
  final int pickupsToday;
  final List<int> hourlyUsage; // 6 intervals (6am, 9am, 12pm, 3pm, 6pm, 9pm)
  final bool hasUsagePermission;
  final bool hasAccessibility;
  final bool isMonitorRunning;

  /// `yyyy-MM-dd` of the last usage refresh. Usage is reset when it no longer
  /// matches today so stale values cannot carry a limit into the next day.
  final String? day;

  const ScreenTimeState({
    required this.apps,
    this.dailyGoalMinutes = 240, // 4 hours
    this.pickupsToday = 0,
    this.hourlyUsage = const [0, 0, 0, 0, 0, 0],
    this.hasUsagePermission = false,
    this.hasAccessibility = false,
    this.isMonitorRunning = false,
    this.day,
  });

  int get totalMinutesSpent =>
      apps.fold(0, (sum, app) => sum + app.timeSpentMinutes);

  String get formattedTotalSpent {
    final h = totalMinutesSpent ~/ 60;
    final m = totalMinutesSpent % 60;
    return '${h}h ${m}m';
  }

  String get formattedDailyGoal {
    final h = dailyGoalMinutes ~/ 60;
    final m = dailyGoalMinutes % 60;
    if (m > 0) return '${h}h ${m}m';
    return '${h}h';
  }

  double get goalProgress {
    if (dailyGoalMinutes <= 0) return 0.0;
    return (totalMinutesSpent / dailyGoalMinutes).clamp(0.0, 1.0);
  }

  List<AppUsageItem> get lockedApps =>
      apps.where((app) => app.isLocked).toList();

  List<AppUsageItem> get warningApps => apps
      .where(
        (app) => !app.isLocked && (app.is5MinWarning || app.is10MinWarning),
      )
      .toList();

  ScreenTimeState copyWith({
    List<AppUsageItem>? apps,
    int? dailyGoalMinutes,
    int? pickupsToday,
    List<int>? hourlyUsage,
    bool? hasUsagePermission,
    bool? hasAccessibility,
    bool? isMonitorRunning,
    String? day,
  }) {
    return ScreenTimeState(
      apps: apps ?? this.apps,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      pickupsToday: pickupsToday ?? this.pickupsToday,
      hourlyUsage: hourlyUsage ?? this.hourlyUsage,
      hasUsagePermission: hasUsagePermission ?? this.hasUsagePermission,
      hasAccessibility: hasAccessibility ?? this.hasAccessibility,
      isMonitorRunning: isMonitorRunning ?? this.isMonitorRunning,
      day: day ?? this.day,
    );
  }
}

class ScreenTimeNotifier extends Notifier<ScreenTimeState> {
  static const MethodChannel _platform = MethodChannel(
    'com.example.orbit/usage_stats',
  );
  Timer? _pollTimer;

  /// Tracks which threshold warnings have already fired today so a single
  /// crossing does not produce repeated notifications.
  final Set<String> _firedWarnings = {};

  /// Remaining-minutes thresholds that trigger a warning.
  static const int _warnAtTen = 10;
  static const int _warnAtFive = 5;

  @override
  ScreenTimeState build() {
    unawaited(_restore());

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      refreshPermissionsAndUsage();
    });

    ref.onDispose(() {
      _pollTimer?.cancel();
    });

    Future.microtask(() => refreshPermissionsAndUsage());

    return const ScreenTimeState(
      apps: [
        AppUsageItem(
          id: 'whatsapp',
          name: 'WhatsApp',
          packageName: 'com.whatsapp',
          category: AppCategory.social,
          timeSpentMinutes: 0,
          limitMinutes: 300, // 300 mins default limit
          notifyAt10Min: true,
          notifyAt5Min: true,
          isStrictLock: true,
        ),
        AppUsageItem(
          id: 'tiktok',
          name: 'TikTok',
          packageName: 'com.zhiliaoapp.musically',
          category: AppCategory.entertainment,
          timeSpentMinutes: 0,
          limitMinutes: 45,
          notifyAt10Min: true,
          notifyAt5Min: true,
          isStrictLock: true,
        ),
        AppUsageItem(
          id: 'instagram',
          name: 'Instagram',
          packageName: 'com.instagram.android',
          category: AppCategory.social,
          timeSpentMinutes: 0,
          limitMinutes: 60,
          notifyAt10Min: true,
          notifyAt5Min: true,
          isStrictLock: true,
        ),
        AppUsageItem(
          id: 'snapchat',
          name: 'Snapchat',
          packageName: 'com.snapchat.android',
          category: AppCategory.social,
          timeSpentMinutes: 0,
          limitMinutes: 30,
          notifyAt10Min: true,
          notifyAt5Min: true,
          isStrictLock: true,
        ),
        AppUsageItem(
          id: 'youtube',
          name: 'YouTube',
          packageName: 'com.google.android.youtube',
          category: AppCategory.entertainment,
          timeSpentMinutes: 0,
          limitMinutes: 120,
          notifyAt10Min: true,
          notifyAt5Min: true,
        ),
        AppUsageItem(
          id: 'linkedin',
          name: 'LinkedIn',
          packageName: 'com.linkedin.android',
          category: AppCategory.social,
          timeSpentMinutes: 0,
          limitMinutes: 45,
          notifyAt10Min: true,
          notifyAt5Min: true,
        ),
      ],
      dailyGoalMinutes: 480, // 8 hours
      pickupsToday: 0,
      hourlyUsage: [0, 0, 0, 0, 0, 0],
    );
  }

  Future<void> _restore() async {
    final stored = await PersistenceService.instance.loadScreenTime();
    if (stored != null) {
      state = stored;
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Polls real OS usage stats and system permission statuses from the native
  /// Kotlin engine.
  Future<void> refreshPermissionsAndUsage() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final hasUsage =
          await _platform.invokeMethod<bool>('checkUsagePermission') ?? false;
      final hasA11y =
          await _platform.invokeMethod<bool>('checkAccessibilityEnabled') ??
          false;
      final isRunning =
          await _platform.invokeMethod<bool>('isMonitorServiceRunning') ??
          false;

      Map<String, int> nativeUsage = {};
      List<int> hourly = const [0, 0, 0, 0, 0, 0];
      int pickups = 0;
      if (hasUsage) {
        final rawMap = await _platform.invokeMethod<Map<Object?, Object?>>(
          'getTodayUsageStats',
        );
        if (rawMap != null) {
          nativeUsage = rawMap.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          );
        }
        final stats = await _platform.invokeMethod<Map<Object?, Object?>>(
          'getScreenTimeStats',
        );
        if (stats != null) {
          final rawHourly = stats['hourlyUsage'];
          if (rawHourly is List && rawHourly.length == 6) {
            hourly = rawHourly.map((e) => (e as num).toInt()).toList();
          }
          pickups = (stats['pickups'] as num?)?.toInt() ?? 0;
        }
      }

      // A new day starts fresh: zero any usage that persisted from yesterday
      // so limits are never stuck "locked" across midnight.
      final today = _todayKey();
      var baseline = state.apps;
      if (state.day != today) {
        _firedWarnings.clear();
        baseline = baseline
            .map((app) => app.copyWith(timeSpentMinutes: 0))
            .toList();
        hourly = const [0, 0, 0, 0, 0, 0];
        pickups = 0;
      }

      final List<AppUsageItem> merged;
      if (hasUsage) {
        merged = baseline
            .map(
              (app) => app.copyWith(
                timeSpentMinutes: nativeUsage[app.packageName] ?? 0,
              ),
            )
            .toList();
      } else {
        // Without usage access there is nothing fresher than the stored value.
        merged = baseline;
      }

      // Detect limit crossings, but only when the native monitor is not the
      // one posting warnings — otherwise the same limit notifies twice.
      if (!isRunning) {
        for (var i = 0; i < merged.length; i++) {
          final before = baseline[i];
          final after = merged[i];
          if (before.timeSpentMinutes != after.timeSpentMinutes) {
            await _notifyOnCrossing(before, after);
          }
        }
      }

      state = state.copyWith(
        apps: merged,
        day: today,
        pickupsToday: pickups,
        hourlyUsage: hourly,
        hasUsagePermission: hasUsage,
        hasAccessibility: hasA11y,
        isMonitorRunning: isRunning,
      );

      // If user enabled limits and granted usage access, make sure monitor service is running
      if (hasUsage && merged.any((a) => a.hasLimit) && !isRunning) {
        await _platform.invokeMethod<bool>('startMonitorService');
      }
      unawaited(_persist());
    } catch (e) {
      debugPrint('ScreenTimeNotifier.refreshPermissionsAndUsage error: $e');
    }
  }

  Future<void> openUsageSettings() async {
    try {
      await _platform.invokeMethod('openUsageSettings');
    } catch (e) {
      debugPrint('openUsageSettings error: $e');
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('openAccessibilitySettings error: $e');
    }
  }

  Future<void> restartMonitorService() async {
    try {
      await _platform.invokeMethod('startMonitorService');
      await refreshPermissionsAndUsage();
    } catch (e) {
      debugPrint('restartMonitorService error: $e');
    }
  }

  bool isLimitLocked(String id) {
    final app = state.apps.where((a) => a.id == id).firstOrNull;
    return app?.isLocked ?? false;
  }

  void setAppLimit(
    String id,
    int? limitMinutes, {
    String? packageName,
    bool? notifyAt10Min,
    bool? notifyAt5Min,
    bool? isStrictLock,
  }) {
    if (isLimitLocked(id)) {
      debugPrint('Cannot change limit: app $id is locked until midnight');
      return;
    }

    state = state.copyWith(
      apps: state.apps.map((app) {
        if (app.id != id) return app;
        return app.copyWith(
          packageName: packageName?.trim().isNotEmpty == true
              ? packageName!.trim()
              : app.packageName,
          limitMinutes: limitMinutes,
          notifyAt10Min: notifyAt10Min ?? app.notifyAt10Min,
          notifyAt5Min: notifyAt5Min ?? app.notifyAt5Min,
          isStrictLock: isStrictLock ?? app.isStrictLock,
        );
      }).toList(),
    );
    // A new limit restarts the countdown, so warnings may fire again.
    _firedWarnings.removeWhere((key) => key.startsWith('$id:'));
    unawaited(_persist());
  }

  void grantEmergencyTime(String id, {int extensionMinutes = 5}) {
    state = state.copyWith(
      apps: state.apps.map((app) {
        if (app.id != id) return app;
        if (app.limitMinutes == null) return app;
        return app.copyWith(limitMinutes: app.limitMinutes! + extensionMinutes);
      }).toList(),
    );
    _firedWarnings.removeWhere((key) => key.startsWith('$id:'));
    unawaited(_persist());
  }

  void addMinutesToApp(String id, int minutes) {
    final before = state.apps.where((app) => app.id == id).firstOrNull;
    if (before == null) return;

    state = state.copyWith(
      apps: state.apps.map((app) {
        if (app.id != id) return app;
        return app.copyWith(timeSpentMinutes: app.timeSpentMinutes + minutes);
      }).toList(),
    );

    final after = state.apps.where((app) => app.id == id).firstOrNull;
    if (after != null && !state.isMonitorRunning) {
      unawaited(_notifyOnCrossing(before, after));
    }
    unawaited(_persist());
  }

  /// Posts a real OS notification when usage moves past the 10, 5 or lock
  /// threshold, so the warning reaches the user even when the app is
  /// backgrounded.
  Future<void> _notifyOnCrossing(
    AppUsageItem before,
    AppUsageItem after,
  ) async {
    if (!after.hasLimit) return;

    final wasRemaining = before.remainingMinutes;
    final remaining = after.remainingMinutes;

    if (!before.isLocked && after.isLocked) {
      if (_firedWarnings.add('${after.id}:locked')) {
        await after.notifyLimitWarning();
      }
      return;
    }

    if (after.notifyAt5Min &&
        wasRemaining > _warnAtFive &&
        remaining <= _warnAtFive &&
        _firedWarnings.add('${after.id}:$_warnAtFive')) {
      await after.notifyLimitWarning();
      return;
    }

    if (after.notifyAt10Min &&
        wasRemaining > _warnAtTen &&
        remaining <= _warnAtTen &&
        _firedWarnings.add('${after.id}:$_warnAtTen')) {
      await after.notifyLimitWarning();
    }
  }

  void addApp(AppUsageItem app) {
    state = state.copyWith(apps: [...state.apps, app]);
    unawaited(_persist());
  }

  void deleteApp(String id) {
    state = state.copyWith(
      apps: state.apps.where((app) => app.id != id).toList(),
    );
    _firedWarnings.removeWhere((key) => key.startsWith('$id:'));
    unawaited(_persist());
  }

  void setDailyGoal(int minutes) {
    state = state.copyWith(dailyGoalMinutes: minutes);
    unawaited(_persist());
  }

  Future<void> _persist() => PersistenceService.instance.saveScreenTime(state);
}

final screenTimeProvider =
    NotifierProvider<ScreenTimeNotifier, ScreenTimeState>(
      ScreenTimeNotifier.new,
    );

// Focus Session Notifier
class FocusSessionNotifier extends Notifier<FocusSession> {
  Timer? _timer;

  @override
  FocusSession build() {
    ref.onDispose(() {
      _timer?.cancel();
    });

    FocusForegroundService.instance.listen(_onServiceEvent);
    unawaited(_restoreFromService());

    return const FocusSession(
      id: 'focus_1',
      title: 'Deep Work',
      targetMinutes: 25,
    );
  }

  /// Mirrors the native foreground service state into the UI if the timer was
  /// (or is still) running while the app was away.
  Future<void> _restoreFromService() async {
    final native = await FocusForegroundService.instance.state();
    if (native == null) return;

    final totalSeconds = native['totalSeconds'] as int? ?? 0;
    final remainingSeconds = native['remainingSeconds'] as int? ?? 0;
    final running = native['running'] == true;
    if (totalSeconds <= 0 || remainingSeconds <= 0) return;

    final minutes = (totalSeconds / 60).round().clamp(1, 180);
    state = FocusSession(
      id: state.id,
      title: native['title']?.toString() ?? state.title,
      targetMinutes: minutes,
      elapsedSeconds: totalSeconds - remainingSeconds,
      isRunning: running,
      isCompleted: false,
    );
    if (running) {
      _beginTicking();
    }
  }

  void _onServiceEvent(
    String event,
    int totalSeconds,
    int remainingSeconds,
    bool running,
  ) {
    final total = totalSeconds > 0 ? totalSeconds : state.targetMinutes * 60;
    final elapsed = (total - remainingSeconds).clamp(0, total);
    switch (event) {
      case 'paused':
        _timer?.cancel();
        state = state.copyWith(elapsedSeconds: elapsed, isRunning: false);
      case 'resumed':
        state = state.copyWith(elapsedSeconds: elapsed, isRunning: true);
        _beginTicking();
      case 'stopped':
        _timer?.cancel();
        state = state.copyWith(
          elapsedSeconds: 0,
          isRunning: false,
          isCompleted: false,
        );
      case 'completed':
        _timer?.cancel();
        state = state.copyWith(
          elapsedSeconds: total,
          isRunning: false,
          isCompleted: true,
        );
    }
  }

  void setPreset({required String title, required int minutes}) {
    _timer?.cancel();
    unawaited(FocusForegroundService.instance.stop());
    state = FocusSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      targetMinutes: minutes,
      elapsedSeconds: 0,
      isRunning: false,
      isCompleted: false,
    );
  }

  void adjustMinutes(int delta) {
    if (state.isRunning) return;
    final newMinutes = (state.targetMinutes + delta).clamp(1, 180);
    state = state.copyWith(
      targetMinutes: newMinutes,
      elapsedSeconds: 0,
      isCompleted: false,
    );
  }

  void setCustomMinutes(int minutes, {String? title}) {
    _timer?.cancel();
    unawaited(FocusForegroundService.instance.stop());
    state = FocusSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? state.title,
      targetMinutes: minutes.clamp(1, 180),
      elapsedSeconds: 0,
      isRunning: false,
      isCompleted: false,
    );
  }

  void start() {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true);
    unawaited(
      FocusForegroundService.instance.start(
        title: state.title,
        totalSeconds: state.targetMinutes * 60,
        remainingSeconds: state.remainingSeconds,
      ),
    );
    _beginTicking();
  }

  void _beginTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isRunning) {
        timer.cancel();
        return;
      }
      if (state.elapsedSeconds + 1 >= state.targetMinutes * 60) {
        timer.cancel();
        state = state.copyWith(
          elapsedSeconds: state.targetMinutes * 60,
          isRunning: false,
          isCompleted: true,
        );
      } else {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      }
    });
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
    unawaited(FocusForegroundService.instance.pause());
  }

  void reset() {
    _timer?.cancel();
    state = state.copyWith(
      elapsedSeconds: 0,
      isRunning: false,
      isCompleted: false,
    );
    unawaited(FocusForegroundService.instance.stop());
  }
}

final focusSessionProvider =
    NotifierProvider<FocusSessionNotifier, FocusSession>(
      FocusSessionNotifier.new,
    );
