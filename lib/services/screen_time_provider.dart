import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/screen_time.dart';

class ScreenTimeState {
  final List<AppUsageItem> apps;
  final int dailyGoalMinutes;
  final int pickupsToday;
  final List<int> hourlyUsage; // 6 intervals (6am, 9am, 12pm, 3pm, 6pm, 9pm)

  const ScreenTimeState({
    required this.apps,
    this.dailyGoalMinutes = 240, // 4 hours
    this.pickupsToday = 42,
    this.hourlyUsage = const [15, 28, 42, 35, 14, 0],
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
  @override
  ScreenTimeState build() {
    return const ScreenTimeState(
      apps: [
        AppUsageItem(
          id: 'instagram',
          name: 'Instagram',
          packageName: 'com.instagram.android',
          category: AppCategory.social,
          timeSpentMinutes: 52,
          limitMinutes: 60, // 8 mins left -> triggers 10-min warning!
          notifyAt10Min: true,
          notifyAt5Min: true,
          isStrictLock: true,
          iconCodePoint: 0xe11e, // Icons.camera_alt_rounded
          colorValue: 0xFFE1306C,
        ),
        AppUsageItem(
          id: 'tiktok',
          name: 'TikTok',
          packageName: 'com.zhiliaoapp.musically',
          category: AppCategory.entertainment,
          timeSpentMinutes: 45,
          limitMinutes: 45, // Reached limit -> LOCKED!
          notifyAt10Min: true,
          notifyAt5Min: true,
          isStrictLock: true,
          iconCodePoint: 0xe4d2, // Icons.play_circle_fill_rounded
          colorValue: 0xFF000000,
        ),
        AppUsageItem(
          id: 'youtube',
          name: 'YouTube',
          packageName: 'com.google.android.youtube',
          category: AppCategory.entertainment,
          timeSpentMinutes: 38,
          limitMinutes: 90,
          notifyAt10Min: true,
          notifyAt5Min: true,
          iconCodePoint: 0xf37f, // Icons.smart_display_rounded
          colorValue: 0xFFFF0000,
        ),
        AppUsageItem(
          id: 'x_twitter',
          name: 'X (Twitter)',
          packageName: 'com.twitter.android',
          category: AppCategory.social,
          timeSpentMinutes: 26,
          limitMinutes: 30, // 4 mins left -> triggers 5-min final warning!
          notifyAt10Min: true,
          notifyAt5Min: true,
          iconCodePoint: 0xe618, // Icons.tag_rounded
          colorValue: 0xFF1DA1F2,
        ),
        AppUsageItem(
          id: 'chrome',
          name: 'Google Chrome',
          packageName: 'com.android.chrome',
          category: AppCategory.utilities,
          timeSpentMinutes: 18,
          limitMinutes: null, // No limit
          iconCodePoint: 0xe4f7, // Icons.public_rounded
          colorValue: 0xFF4285F4,
        ),
      ],
      dailyGoalMinutes: 240, // 4 hours
      pickupsToday: 42,
      hourlyUsage: [15, 32, 45, 28, 14, 0],
    );
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
  }

  void addMinutesToApp(String id, int minutes) {
    state = state.copyWith(
      apps: state.apps.map((app) {
        if (app.id != id) return app;
        return app.copyWith(
          timeSpentMinutes: app.timeSpentMinutes + minutes,
        );
      }).toList(),
    );
  }

  void addApp(AppUsageItem app) {
    state = state.copyWith(apps: [...state.apps, app]);
  }

  void deleteApp(String id) {
    state = state.copyWith(
      apps: state.apps.where((app) => app.id != id).toList(),
    );
  }

  void setDailyGoal(int minutes) {
    state = state.copyWith(dailyGoalMinutes: minutes);
  }
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
