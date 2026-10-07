import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orbit/services/notification_service.dart';

/// User-facing alarm and notification preferences, persisted so they survive
/// relaunch. Android notification channels freeze their sound and vibration
/// the first time they are created, so these are applied to the channel id as
/// well (see [NotificationChannelRevision] in notification_service.dart).
class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  static const _kVibration = 'orbit.notif.vibration';
  static const _kSound = 'orbit.notif.sound';
  static const _kSnoozeMinutes = 'orbit.notif.snooze_minutes';
  static const _kAlarmDurationMinutes = 'orbit.notif.alarm_duration_minutes';
  static const _kBypassDnd = 'orbit.notif.bypass_dnd';
  static const _kStreakReminderEnabled = 'orbit.notif.streak_reminder_enabled';
  static const _kStreakReminderHour = 'orbit.notif.streak_reminder_hour';

  static const int defaultSnoozeMinutes = 10;
  static const int defaultAlarmDurationMinutes = 2;
  static const int defaultStreakReminderHour = 20;

  @override
  NotificationSettings build() {
    unawaited(_restore());
    return const NotificationSettings();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      vibrationEnabled: prefs.getBool(_kVibration) ?? true,
      soundEnabled: prefs.getBool(_kSound) ?? true,
      snoozeMinutes: prefs.getInt(_kSnoozeMinutes) ?? defaultSnoozeMinutes,
      alarmDurationMinutes:
          prefs.getInt(_kAlarmDurationMinutes) ?? defaultAlarmDurationMinutes,
      bypassDnd: prefs.getBool(_kBypassDnd) ?? false,
      streakReminderEnabled:
          prefs.getBool(_kStreakReminderEnabled) ?? true,
      streakReminderHour:
          prefs.getInt(_kStreakReminderHour) ?? defaultStreakReminderHour,
    );
    await _rescheduleStreak();
  }

  Future<void> setVibrationEnabled(bool value) async {
    state = state.copyWith(vibrationEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibration, value);
  }

  Future<void> setSoundEnabled(bool value) async {
    state = state.copyWith(soundEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSound, value);
  }

  Future<void> setSnoozeMinutes(int minutes) async {
    state = state.copyWith(snoozeMinutes: minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSnoozeMinutes, minutes);
  }

  Future<void> setAlarmDurationMinutes(int minutes) async {
    state = state.copyWith(alarmDurationMinutes: minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAlarmDurationMinutes, minutes);
  }

  Future<void> setBypassDnd(bool value) async {
    state = state.copyWith(bypassDnd: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBypassDnd, value);
  }

  Future<void> setStreakReminderEnabled(bool value) async {
    state = state.copyWith(streakReminderEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStreakReminderEnabled, value);
    await _rescheduleStreak();
  }

  Future<void> setStreakReminderHour(int hour) async {
    state = state.copyWith(streakReminderHour: hour);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStreakReminderHour, hour);
    await _rescheduleStreak();
  }

  Future<void> _rescheduleStreak() async {
    final settings = state;
    await NotificationService.instance.syncStreakReminder(
      enabled: settings.streakReminderEnabled,
      hour: settings.streakReminderHour,
      minute: 0,
    );
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  NotificationSettingsNotifier.new,
);

class NotificationSettings {
  final bool vibrationEnabled;
  final bool soundEnabled;
  final int snoozeMinutes;
  final int alarmDurationMinutes;
  final bool bypassDnd;
  final bool streakReminderEnabled;
  final int streakReminderHour;

  const NotificationSettings({
    this.vibrationEnabled = true,
    this.soundEnabled = true,
    this.snoozeMinutes = NotificationSettingsNotifier.defaultSnoozeMinutes,
    this.alarmDurationMinutes =
        NotificationSettingsNotifier.defaultAlarmDurationMinutes,
    this.bypassDnd = false,
    this.streakReminderEnabled = true,
    this.streakReminderHour = NotificationSettingsNotifier.defaultStreakReminderHour,
  });

  NotificationSettings copyWith({
    bool? vibrationEnabled,
    bool? soundEnabled,
    int? snoozeMinutes,
    int? alarmDurationMinutes,
    bool? bypassDnd,
    bool? streakReminderEnabled,
    int? streakReminderHour,
  }) {
    return NotificationSettings(
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      alarmDurationMinutes: alarmDurationMinutes ?? this.alarmDurationMinutes,
      bypassDnd: bypassDnd ?? this.bypassDnd,
      streakReminderEnabled:
          streakReminderEnabled ?? this.streakReminderEnabled,
      streakReminderHour: streakReminderHour ?? this.streakReminderHour,
    );
  }
}
