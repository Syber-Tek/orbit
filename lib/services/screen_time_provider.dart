import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/screen_time.dart';
import 'package:orbit/services/notification_service.dart';
import 'package:orbit/services/persistence_service.dart';

class ScreenTimeState {
  final List<AppUsageItem> apps;
  final int dailyGoalMinutes;
  final int pickupsToday;
  final List<int> hourlyUsage; // 6 intervals (6am, 9am, 12pm, 3pm, 6pm, 9pm)

  const ScreenTimeState({
    required this.apps,
    this.dailyGoalMinutes = 240, // 4 hours
    this.pickupsToday = 0,
    this.hourlyUsage = const [0, 0, 0, 0, 0, 0],
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
      .where((app) => !app.isLocked && (app.is5MinWarning || app.is10MinWarning))
      .toList();

  ScreenTimeState copyWith({
    List<AppUsageItem>? apps,
    int? dailyGoalMinutes,
    int? pickupsToday,
    List<int>? hourlyUsage,
  }) {
    return ScreenTimeState(
      apps: apps ?? this.apps,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      pickupsToday: pickupsToday ?? this.pickupsToday,
      hourlyUsage: hourlyUsage ?? this.hourlyUsage,
    );
  }
}

class ScreenTimeNotifier extends Notifier<ScreenTimeState> {
  /// Tracks which threshold warnings have already fired today so a single
  /// crossing does not produce repeated notifications.
  final Set<String> _firedWarnings = {};

  /// Remaining-minutes thresholds that trigger a warning.
  static const int _warnAtTen = 10;
  static const int _warnAtFive = 5;

  @override
  ScreenTimeState build() {
    unawaited(_restore());
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
    if (stored != null) state = stored;
  }

  void setAppLimit(
    String id,
    int? limitMinutes, {
    bool? notifyAt10Min,
    bool? notifyAt5Min,
    bool? isStrictLock,
  }) {
    state = state.copyWith(
      apps: state.apps.map((app) {
        if (app.id != id) return app;
        return app.copyWith(
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
        return app.copyWith(
          limitMinutes: app.limitMinutes! + extensionMinutes,
        );
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
        return app.copyWith(
          timeSpentMinutes: app.timeSpentMinutes + minutes,
        );
      }).toList(),
    );

    final after = state.apps.where((app) => app.id == id).firstOrNull;
    if (after != null) unawaited(_notifyOnCrossing(before, after));
    unawaited(_persist());
  }

  /// Posts a real OS notification when usage moves past the 10, 5 or lock
  /// threshold, so the warning reaches the user even when the app is
  /// backgrounded.
  Future<void> _notifyOnCrossing(AppUsageItem before, AppUsageItem after) async {
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

    return const FocusSession(
      id: 'focus_1',
      title: 'Deep Work',
      targetMinutes: 25,
    );
  }

  void setPreset({required String title, required int minutes}) {
    _timer?.cancel();
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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
  }

  void reset() {
    _timer?.cancel();
    state = state.copyWith(
      elapsedSeconds: 0,
      isRunning: false,
      isCompleted: false,
    );
  }
}

final focusSessionProvider =
    NotifierProvider<FocusSessionNotifier, FocusSession>(
  FocusSessionNotifier.new,
);
