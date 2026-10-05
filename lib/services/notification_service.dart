import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:orbit/models/screen_time.dart';
import 'package:orbit/models/task.dart';
import 'package:orbit/services/persistence_service.dart';

/// Android raw resource for the alarm beep. Kept in
/// `android/app/src/main/res/raw/orbit_alarm.wav`; the pattern is baked into
/// the file because neither platform loops a notification sound.
const String _kAlarmSoundResource = 'orbit_alarm';

const String _kLimitWarningChannelBase = 'orbit_limit_warnings';

/// Action identifiers used by the alarm notification buttons. They must match
/// the ids in [_kAlarmCategoryId] and [_androidActions].
const String kActionSnooze = 'orbit_snooze';
const String kActionDismiss = 'orbit_dismiss';

/// iOS binds categories once per app launch, so changing the action set later
/// requires a reinstall or a new category identifier.
const String _kAlarmCategoryId = 'orbit_alarm_v1';

const String _kPayloadTaskPrefix = 'task:';

/// Stable notification id namespaces so a task alarm can never collide with
/// a screen time warning notification.
const int _kTaskAlarmIdBase = 1000000;
const int _kLimitWarningIdBase = 2000000;
const int _kIdSpace = 900000;

/// Deterministic FNV-1a hash. [String.hashCode] is not guaranteed to be
/// identical across runs or platforms, which would orphan already-scheduled
/// notifications on every relaunch.
int _stableId(String seed) {
  var hash = 0x811c9dc5;
  for (final unit in seed.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash % _kIdSpace;
}

/// Invoked when an action fires while the main isolate is alive, so the
/// Riverpod layer can refresh in memory instead of only on disk.
typedef NotificationActionHandler =
    Future<void> Function(String actionId, String taskId);

/// Android freezes a channel's sound and vibration the first time it is
/// created, so toggling either setting is expressed as a distinct channel id
/// rather than an in-place update.
String _alarmChannelId({required bool sound, required bool vibration}) {
  return 'orbit_alarms_${sound ? 'snd' : 'mut'}_${vibration ? 'vib' : 'novib'}';
}

/// The concrete instant a task alarm should fire, or null when the task has no
/// alarm, no time, or its time has already passed.
tz.TZDateTime? alarmDateTimeFor(TaskItem task) {
  if (!task.hasAlarm || task.isCompleted) return null;
  final time = task.scheduledTime;
  if (time == null) return null;

  final date = task.scheduledDate;
  final scheduled = tz.TZDateTime(
    tz.local,
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );

  // A minute of slack avoids cancelling an alarm the user just set for "now".
  final now = tz.TZDateTime.now(tz.local);
  if (scheduled.isAfter(now.subtract(const Duration(minutes: 1)))) {
    return scheduled;
  }
  return null;
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  bool _timezoneResolved = false;
  bool _permissionGranted = false;

  /// Set by the app layer. When null the action is applied straight to disk,
  /// which is the path taken when the process was killed.
  NotificationActionHandler? actionHandler;

  bool get isReady => _initialised;
  bool get hasPermission => _permissionGranted;

  static int taskNotificationId(String taskId) =>
      _kTaskAlarmIdBase + _stableId(taskId);

  static int limitWarningNotificationId(String appId) =>
      _kLimitWarningIdBase + _stableId(appId);

  static String? taskIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(_kPayloadTaskPrefix)) return null;
    return payload.substring(_kPayloadTaskPrefix.length);
  }

  /// Prepares the timezone database and the OS plugin. Safe to call repeatedly.
  Future<void> init() async {
    if (_initialised) return;

    tz_data.initializeTimeZones();
    await _resolveLocalTimezone();

    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            _kAlarmCategoryId,
            actions: [
              DarwinNotificationAction.plain(
                kActionSnooze,
                'Snooze 10m',
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                kActionDismiss,
                'Mark done',
                options: {
                  DarwinNotificationActionOption.foreground,
                  DarwinNotificationActionOption.destructive,
                },
              ),
            ],
          ),
        ],
      ),
    );

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onForegroundResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      _initialised = true;
    } catch (error, stack) {
      debugPrint('NotificationService init failed: $error\n$stack');
    }
  }

  Future<void> _resolveLocalTimezone() async {
    if (_timezoneResolved) return;
    _timezoneResolved = true;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error) {
      debugPrint('Falling back to UTC timezone: $error');
    }
  }

  void _onForegroundResponse(NotificationResponse response) {
    final actionId = response.actionId;
    // Empty actionId means the body was tapped, which has no meaning yet.
    if (actionId == null || actionId.isEmpty) return;

    final taskId = taskIdFromPayload(response.payload);
    if (taskId == null) return;
    unawaited(_dispatchAction(actionId, taskId));
  }

  Future<void> _dispatchAction(String actionId, String taskId) async {
    final handler = actionHandler;
    if (handler != null) {
      await handler(actionId, taskId);
      return;
    }
    await applyActionToDisk(actionId, taskId);
  }

  /// Applies a snooze or dismiss directly against storage. Safe to call from a
  /// background isolate, which is why it does not touch Riverpod.
  static Future<void> applyActionToDisk(
    String actionId,
    String taskId, {
    int snoozeMinutes = 10,
  }) async {
    final service = NotificationService.instance;
    await service.init();

    final tasks = await PersistenceService.instance.loadTasks();
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) return;

    if (actionId == kActionDismiss) {
      final done = tasks[index].copyWith(isCompleted: true);
      await PersistenceService.instance.saveTasks([
        for (var i = 0; i < tasks.length; i++) i == index ? done : tasks[i],
      ]);
      await service.cancelTaskAlarm(taskId);
      return;
    }

    if (actionId == kActionSnooze) {
      // Keep the task untouched; just push the alarm out.
      await service.scheduleSnooze(tasks[index], snoozeMinutes);
    }
  }

  /// Prompts for notification permission. Returns true when notifications may
  /// be posted.
  Future<bool> requestPermission() async {
    await init();
    if (!_initialised) return false;

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      var granted = true;
      if (android != null) {
        granted = await android.requestNotificationsPermission() ?? true;
        // Exact alarms keep task reminders on the intended minute.
        await android.requestExactAlarmsPermission();
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        granted =
            await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }

      _permissionGranted = granted;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      _permissionGranted = false;
    }
    return _permissionGranted;
  }

  /// Reads the persisted preferences directly so this works in any isolate.
  Future<_AlarmPrefs> _readPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _AlarmPrefs(
        vibration: prefs.getBool('orbit.notif.vibration') ?? true,
        sound: prefs.getBool('orbit.notif.sound') ?? true,
        snoozeMinutes: prefs.getInt('orbit.notif.snooze_minutes') ?? 10,
        bypassDnd: prefs.getBool('orbit.notif.bypass_dnd') ?? false,
      );
    } catch (error) {
      debugPrint('Failed to read notification prefs: $error');
      return const _AlarmPrefs();
    }
  }

  /// Arms (or re-arms) the OS alarm for a single task.
  Future<void> scheduleTaskAlarm(TaskItem task) async {
    await init();
    if (!_initialised) return;

    final id = taskNotificationId(task.id);
    await _safeCancel(id);

    final when = alarmDateTimeFor(task);
    if (when == null) return;
    if (!_permissionGranted && !await requestPermission()) return;

    final prefs = await _readPrefs();
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: task.title,
        body: _taskBody(task),
        scheduledDate: when,
        notificationDetails: _alarmDetails(prefs),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$_kPayloadTaskPrefix${task.id}',
      );
    } catch (error) {
      debugPrint('Failed to schedule alarm for task ${task.id}: $error');
    }
  }

  /// Re-arms the same task id for [minutes] from now.
  Future<void> scheduleSnooze(TaskItem task, int minutes) async {
    await init();
    if (!_initialised) return;

    final prefs = await _readPrefs();
    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    try {
      await _plugin.zonedSchedule(
        id: taskNotificationId(task.id),
        title: task.title,
        body: 'Snoozed ${prefs.snoozeMinutes}m • ${task.title}',
        scheduledDate: when,
        notificationDetails: _alarmDetails(prefs),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$_kPayloadTaskPrefix${task.id}',
      );
    } catch (error) {
      debugPrint('Failed to snooze task ${task.id}: $error');
    }
  }

  NotificationDetails _alarmDetails(_AlarmPrefs prefs) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _alarmChannelId(sound: prefs.sound, vibration: prefs.vibration),
        'Task Alarms',
        channelDescription: 'Reminders for scheduled Orbit tasks',
        importance: Importance.max,
        priority: Priority.high,
        playSound: prefs.sound,
        sound: prefs.sound
            ? const RawResourceAndroidNotificationSound(_kAlarmSoundResource)
            : null,
        enableVibration: prefs.vibration,
        vibrationPattern: prefs.vibration ? _alarmVibration : null,
        channelBypassDnd: prefs.bypassDnd,
        // Stay on screen until snoozed or dismissed, like a real alarm.
        ongoing: true,
        autoCancel: false,
        actions: _androidActions(prefs.snoozeMinutes),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: prefs.sound,
        categoryIdentifier: _kAlarmCategoryId,
        interruptionLevel: prefs.bypassDnd
            ? InterruptionLevel.critical
            : InterruptionLevel.timeSensitive,
      ),
    );
  }

  List<AndroidNotificationAction> _androidActions(int snoozeMinutes) {
    return [
      AndroidNotificationAction(
        kActionSnooze,
        'Snooze ${snoozeMinutes}m',
        cancelNotification: true,
        showsUserInterface: false,
      ),
      AndroidNotificationAction(
        kActionDismiss,
        'Mark done',
        cancelNotification: true,
        showsUserInterface: false,
      ),
    ];
  }

  Future<void> cancelTaskAlarm(String taskId) async {
    await init();
    if (!_initialised) return;
    await _safeCancel(taskNotificationId(taskId));
  }

  /// Rebuilds every armed alarm from scratch. Used on launch so the OS queue
  /// stays in step with persisted state after a reboot or reinstall.
  Future<void> syncTaskAlarms(List<TaskItem> tasks) async {
    await init();
    if (!_initialised) return;

    final armed = <int>{};
    for (final task in tasks) {
      final id = taskNotificationId(task.id);
      armed.add(id);
      if (alarmDateTimeFor(task) != null) {
        await scheduleTaskAlarm(task);
      } else {
        await _safeCancel(id);
      }
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.id < _kTaskAlarmIdBase) continue;
        if (request.id < _kTaskAlarmIdBase + _kIdSpace &&
            !armed.contains(request.id)) {
          await _safeCancel(request.id);
        }
      }
    } catch (error) {
      debugPrint('Failed to prune orphaned task alarms: $error');
    }
  }

  /// Posts an immediate screen time warning. Called the moment an app crosses
  /// its 10 or 5 minute remaining threshold.
  Future<void> showLimitWarning({
    required String appId,
    required String appName,
    required int minutesRemaining,
    required bool isLocked,
  }) async {
    await init();
    if (!_initialised) return;
    if (!_permissionGranted && !await requestPermission()) return;

    final (title, body) = isLocked
        ? ('$appName limit reached', '$appName is now locked for today.')
        : (
            '$appName closing in ${minutesRemaining}m',
            'You have $minutesRemaining minute${minutesRemaining == 1 ? '' : 's'} '
                'left on $appName today.',
          );

    try {
      await _plugin.show(
        id: limitWarningNotificationId(appId),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _kLimitWarningChannelBase,
            'App Limit Warnings',
            channelDescription: 'Warnings as apps approach their daily limit',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFFFF5500),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'screentime:$appId',
      );
    } catch (error) {
      debugPrint('Failed to show limit warning for $appId: $error');
    }
  }

  Future<void> cancelAll() async {
    await init();
    if (!_initialised) return;
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Failed to cancel all notifications: $error');
    }
  }

  Future<void> _safeCancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (error) {
      debugPrint('Failed to cancel notification $id: $error');
    }
  }

  String _taskBody(TaskItem task) {
    final priority = task.priority == TaskPriority.high ? ' (High)' : '';
    return '${task.category.label}$priority • ${task.title}';
  }

  /// Double-tap-then-pause buzz, repeated, so it is distinguishable from a
  /// message notification.
  static final Int64List _alarmVibration = Int64List.fromList([
    0,
    400,
    200,
    400,
    1000,
  ]);
}

class _AlarmPrefs {
  final bool vibration;
  final bool sound;
  final int snoozeMinutes;
  final bool bypassDnd;

  const _AlarmPrefs({
    this.vibration = true,
    this.sound = true,
    this.snoozeMinutes = 10,
    this.bypassDnd = false,
  });
}

/// Entry point for alarm actions when the app process is not running. Runs in
/// its own isolate, so it must not touch Riverpod or any in-memory state.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final actionId = response.actionId;
  if (actionId == null || actionId.isEmpty) return;

  final taskId = NotificationService.taskIdFromPayload(response.payload);
  if (taskId == null) return;

  unawaited(
    NotificationService.applyActionToDisk(actionId, taskId).catchError(
      (Object error) => debugPrint('Background alarm action failed: $error'),
    ),
  );
}

/// Convenience for callers that only have an [AppUsageItem].
extension ScreenTimeNotification on AppUsageItem {
  Future<void> notifyLimitWarning() {
    return NotificationService.instance.showLimitWarning(
      appId: id,
      appName: name,
      minutesRemaining: remainingMinutes,
      isLocked: isLocked,
    );
  }
}
