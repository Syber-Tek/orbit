import 'package:flutter/services.dart';

/// Bridges the native task-alarm scheduler (AlarmManager + [RingAlarmService]).
///
/// Task alarms no longer rely on the notification channel sound: when an alarm
/// is due a native foreground service loops the alarm mp3 for exactly the
/// configured duration (default 2 minutes), which OEM builds otherwise cut
/// short. This side only pushes schedule/cancel commands and receives
/// Snooze / Mark done / body-tap actions from the native notification.
class NativeAlarmService {
  NativeAlarmService._();

  static final NativeAlarmService instance = NativeAlarmService._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.orbit/native_alarms',
  );

  Future<void> scheduleTaskAlarm({
    required String taskId,
    required String title,
    required int whenMs,
  }) async {
    try {
      await _channel.invokeMethod<void>('scheduleTask', {
        'taskId': taskId,
        'title': title,
        'whenMs': whenMs,
      });
    } on MissingPluginException {
      // Desktop/web builds have no native scheduler; alarms still work there
      // through the plugin path.
    } on PlatformException {
      // Scheduling rejected (e.g. limit reached) — the alarm is simply not armed.
    }
  }

  Future<void> cancelTaskAlarm(String taskId) async {
    try {
      await _channel.invokeMethod<void>('cancelTask', {'taskId': taskId});
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }

  /// Silences a currently ringing alarm for [taskId] (used by Mark done and
  /// task cancellation so the sound cannot outlive the alarm).
  Future<void> stopRinging(String taskId) async {
    try {
      await _channel.invokeMethod<void>('stopRinging', {'taskId': taskId});
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }
}
