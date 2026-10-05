import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/services/persistence_service.dart';

class HapticsNotifier extends Notifier<bool> {
  @override
  bool build() {
    final enabled = PersistenceService.instance.loadHapticsEnabled();
    AppHaptics.enabled = enabled;
    return enabled;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    AppHaptics.enabled = value;
    await PersistenceService.instance.saveHapticsEnabled(value);
    if (value) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

final hapticsEnabledProvider =
    NotifierProvider<HapticsNotifier, bool>(HapticsNotifier.new);

/// Centralized utility for haptic feedback that respects the user's vibration setting.
class AppHaptics {
  static bool enabled = true;

  static void lightImpact() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  static void selectionClick() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void vibrate() {
    if (enabled) HapticFeedback.vibrate();
  }
}
