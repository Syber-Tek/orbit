import 'dart:async';
import 'package:flutter/services.dart';

/// Callback for events pushed from the native focus service while the app is
/// alive. `event` is one of: paused, resumed, stopped, completed.
typedef FocusEventCallback =
    void Function(
      String event,
      int totalSeconds,
      int remainingSeconds,
      bool running,
    );

/// Bridges the Android [FocusTimerService] so the focus session keeps counting
/// down (with a lock-screen notification and Pause/Resume/Stop actions) even
/// after the Flutter engine is closed.
class FocusForegroundService {
  FocusForegroundService._();

  static final FocusForegroundService instance = FocusForegroundService._();

  static const MethodChannel _focus = MethodChannel('com.example.orbit/focus');
  static const EventChannel _events = EventChannel(
    'com.example.orbit/focus_events',
  );

  FocusEventCallback? _onEvent;
  StreamSubscription<dynamic>? _sub;

  void listen(FocusEventCallback onEvent) {
    _onEvent = onEvent;
    _sub ??= _events.receiveBroadcastStream().listen(
      (event) => _dispatch(event),
      onError: (_) {},
    );
  }

  void _dispatch(dynamic event) {
    final handler = _onEvent;
    if (handler == null || event is! Map) return;
    final name = event['event']?.toString() ?? '';
    final total = event['totalSeconds'];
    final remaining = event['remainingSeconds'];
    final running = event['running'];
    handler(
      name,
      total is int ? total : 0,
      remaining is int ? remaining : 0,
      running == true,
    );
  }

  Future<void> start({
    required String title,
    required int totalSeconds,
    required int remainingSeconds,
  }) async {
    try {
      await _focus.invokeMethod<void>('startFocus', {
        'title': title,
        'totalSeconds': totalSeconds,
        'remainingSeconds': remainingSeconds,
      });
    } on PlatformException {
      // Ignored on unsupported platforms; the Dart timer stays authoritative.
    } on MissingPluginException {
      // Ignored on unsupported platforms.
    }
  }

  Future<void> pause() async {
    try {
      await _focus.invokeMethod<void>('pauseFocus');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  Future<void> resume() async {
    try {
      await _focus.invokeMethod<void>('resumeFocus');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  Future<void> stop() async {
    try {
      await _focus.invokeMethod<void>('stopFocus');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  /// Returns the currently persisted native session, or null when idle.
  Future<Map<String, Object>?> state() async {
    try {
      final raw = await _focus.invokeMethod<Map<Object?, Object?>>(
        'getFocusState',
      );
      if (raw == null) return null;
      return raw.map((k, v) => MapEntry(k.toString(), v!));
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
