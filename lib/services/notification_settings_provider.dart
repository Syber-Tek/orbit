import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing alarm and notification preferences, persisted so they survive
/// relaunch. Android notification channels freeze their sound and vibration
/// the first time they are created, so these are applied to the channel id as
/// well (see [NotificationChannelRevision] in notification_service.dart).
class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  static const _kVibration = 'orbit.notif.vibration';
  static const _kSound = 'orbit.notif.sound';
  static const _kSnoozeMinutes = 'orbit.notif.snooze_minutes';
  static const _kBypassDnd = 'orbit.notif.bypass_dnd';

  static const int defaultSnoozeMinutes = 10;

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
      bypassDnd: prefs.getBool(_kBypassDnd) ?? false,
    );
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

  Future<void> setBypassDnd(bool value) async {
    state = state.copyWith(bypassDnd: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBypassDnd, value);
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
  final bool bypassDnd;

  const NotificationSettings({
    this.vibrationEnabled = true,
    this.soundEnabled = true,
    this.snoozeMinutes = NotificationSettingsNotifier.defaultSnoozeMinutes,
    this.bypassDnd = false,
  });

  NotificationSettings copyWith({
    bool? vibrationEnabled,
    bool? soundEnabled,
    int? snoozeMinutes,
    bool? bypassDnd,
  }) {
    return NotificationSettings(
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      bypassDnd: bypassDnd ?? this.bypassDnd,
    );
  }
}
