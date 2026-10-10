import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:orbit/models/habit.dart';
import 'package:orbit/models/note.dart';
import 'package:orbit/models/screen_time.dart';
import 'package:orbit/models/task.dart';
import 'package:orbit/services/native_alarm_service.dart';
import 'package:orbit/services/persistence_service.dart';

/// Android raw resource note: task alarms now ring through the native
/// [RingAlarmService] MediaPlayer loop so the configured duration (default
/// 2 minutes) is honoured on every device. This file keeps the constant out of
/// the way of the notification plugin.
const String _kLimitWarningChannelBase = 'orbit_limit_warnings';
const String _kNoteReminderChannel = 'orbit_note_reminders';
const String _kStreakChannel = 'orbit_streak_reminders';

/// Action identifiers used by the alarm notification buttons. They must match
/// the ids in [_kAlarmCategoryId] and [_androidActions].
const String kActionSnooze = 'orbit_snooze';
const String kActionDismiss = 'orbit_dismiss';

/// iOS binds categories once per app launch, so changing the action set later
/// requires a reinstall or a new category identifier.
const String _kAlarmCategoryId = 'orbit_alarm_v1';

const String _kPayloadTaskPrefix = 'task:';
const String _kPayloadNotePrefix = 'note:';
const String _kPayloadStreak = 'streak';

/// Stable notification id namespaces so a task alarm can never collide with a
/// screen time warning, a note reminder or the streak reminder. Every
/// [_kIdSpace] sized block must stay disjoint, and blocks above
/// `_kTaskAlarmIdBase + _kIdSpace` are ignored by [syncTaskAlarms] pruning.
const int _kTaskAlarmIdBase = 1000000;
const int _kLimitWarningIdBase = 2000000;
const int _kNoteReminderIdBase = 3000000;
const int _kStreakReminderId = 3900000;
const int _kStreakMilestoneIdBase = 4000000;
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

/// Invoked when the notification body is tapped (a plain open, no button).
/// Lets the app jump to the tab the notification belongs to.
typedef NotificationPayloadHandler = Future<void> Function(String payload);

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

  MethodChannel? _actionsChannel;

  bool _initialised = false;
  bool _timezoneResolved = false;
  bool _permissionGranted = false;

  /// Set by the app layer. When null the action is applied straight to disk,
  /// which is the path taken when the process was killed.
  NotificationActionHandler? actionHandler;

  /// Set by the app layer to handle body taps on a notification.
  NotificationPayloadHandler? payloadHandler;

  bool get isReady => _initialised;
  bool get hasPermission => _permissionGranted;

  static int taskNotificationId(String taskId) =>
      _kTaskAlarmIdBase + _stableId(taskId);

  static int limitWarningNotificationId(String appId) =>
      _kLimitWarningIdBase + _stableId(appId);

  static int noteReminderNotificationId(String noteId) =>
      _kNoteReminderIdBase + _stableId(noteId);

  static String? taskIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(_kPayloadTaskPrefix))
      return null;
    return payload.substring(_kPayloadTaskPrefix.length);
  }

  static String? noteIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(_kPayloadNotePrefix))
      return null;
    return payload.substring(_kPayloadNotePrefix.length);
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

    // Actions from the native ring notification (Snooze handled natively;
    // Mark done and body taps route here for persistence and UI navigation).
    _actionsChannel = MethodChannel('com.example.orbit/alarm_actions');
    _actionsChannel!.setMethodCallHandler((call) async {
      if (call.method != 'applyAction') return null;
      final args = call.arguments;
      if (args is! Map) return null;
      final action = args['action']?.toString() ?? '';
      final taskId = args['taskId']?.toString() ?? '';
      if (taskId.isEmpty) return null;

      if (action == 'done') {
        await applyActionToDisk(kActionDismiss, taskId);
        final handler = actionHandler;
        if (handler != null) {
          await handler(kActionDismiss, taskId);
        }
      } else if (action == 'open') {
        final handler = payloadHandler;
        if (handler != null) {
          await handler('task:$taskId');
        }
      }
      return null;
    });

    // Older builds scheduled task alarms through the notification plugin;
    // clear any that may still be pending so a stale beep never rings twice.
    unawaited(_purgeLegacyTaskAlarms());
  }

  /// Removes pending plugin-scheduled task alarms that predate the native
  /// scheduler. Task ids always live in [_kTaskAlarmIdBase, +_kIdSpace).
  Future<void> _purgeLegacyTaskAlarms() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.id >= _kTaskAlarmIdBase &&
            request.id < _kTaskAlarmIdBase + _kIdSpace) {
          await _safeCancel(request.id);
        }
      }
    } catch (error) {
      debugPrint('Failed to purge legacy task alarms: $error');
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
    final payload = response.payload;

    // A body tap (no action) routes the notification's payload to the app.
    if (actionId == null || actionId.isEmpty) {
      if (payload == null || payload.isEmpty) return;
      unawaited(_dispatchPayload(payload));
      return;
    }

    final taskId = taskIdFromPayload(payload);
    if (taskId == null) return;
    unawaited(_dispatchAction(actionId, taskId));
  }

  Future<void> _dispatchPayload(String payload) async {
    final handler = payloadHandler;
    if (handler != null) {
      await handler(payload);
    }
  }

  Future<void> _dispatchAction(String actionId, String taskId) async {
    await applyActionToDisk(actionId, taskId);
    final handler = actionHandler;
    if (handler != null) {
      await handler(actionId, taskId);
    }
  }

  /// Applies a snooze or dismiss directly against storage. Safe to call from a
  /// background isolate, which is why it does not touch Riverpod.
  static Future<void> applyActionToDisk(
    String actionId,
    String taskId, {
    int? snoozeMinutes,
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
      // Keep the task untouched; just push the alarm out. When no duration is
      // supplied the configured snooze length is read from preferences, so the
      // background isolate honours the same setting as the foreground one.
      await service.scheduleSnooze(tasks[index], minutes: snoozeMinutes);
    }
  }

  /// Prompts for the notification permission only. Returns true when
  /// notifications may be posted.
  ///
  /// Exact-alarm access is deliberately *not* requested here: it is a
  /// restricted permission that Android shows as a settings screen, so the app
  /// explains itself first (see the onboarding sheet) and the user taps
  /// through to [requestExactAlarmPermission].
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
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        granted =
            await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      _permissionGranted = granted;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      _permissionGranted = false;
    }
    return _permissionGranted;
  }

  /// True when the OS already reports notifications as enabled, without
  /// prompting. Used by the onboarding sheet to decide what to show.
  Future<bool> notificationsEnabled() async {
    await init();
    if (!_initialised) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.checkPermissions() != null;
      }
    } catch (error) {
      debugPrint('Failed to read notification permission state: $error');
    }
    return true;
  }

  /// True when Android will honour `exactAllowWhileIdle` scheduling. Defaults
  /// to true on platforms without the restriction.
  Future<bool> canScheduleExact() async {
    await init();
    if (!_initialised) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      return await android.canScheduleExactNotifications() ?? false;
    } catch (error) {
      debugPrint('Failed to read exact alarm permission: $error');
      return false;
    }
  }

  /// Opens Android's "Alarms & reminders" settings screen so the user can
  /// grant exact alarms. Never call this unprompted: it navigates away from
  /// the app.
  Future<bool> requestExactAlarmPermission() async {
    await init();
    if (!_initialised) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      return await android.requestExactAlarmsPermission() ??
          await canScheduleExact();
    } catch (error) {
      debugPrint('Exact alarm permission request failed: $error');
      return false;
    }
  }

  /// Picks the schedule mode the OS will actually accept. Scheduling an exact
  /// alarm without the restricted permission throws and the alarm is silently
  /// lost, so we check first and degrade to inexact instead of dropping it.
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!await canScheduleExact()) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  /// Schedules at [when], retrying inexact when the OS rejects an exact
  /// alarm. An alarm is never silently dropped.
  Future<bool> _scheduleAt({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    String? payload,
    DateTimeComponents? match,
  }) async {
    final mode = await _scheduleMode();
    if (await _trySchedule(
      id: id,
      title: title,
      body: body,
      when: when,
      details: details,
      payload: payload,
      match: match,
      mode: mode,
    )) {
      return true;
    }
    if (mode != AndroidScheduleMode.exactAllowWhileIdle) return false;
    // Exact was rejected anyway (permission revoked between check and call).
    return _trySchedule(
      id: id,
      title: title,
      body: body,
      when: when,
      details: details,
      payload: payload,
      match: match,
      mode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<bool> _trySchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required AndroidScheduleMode mode,
    String? payload,
    DateTimeComponents? match,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: mode,
        payload: payload,
        matchDateTimeComponents: match,
      );
      return true;
    } catch (error) {
      debugPrint('Failed to schedule notification $id ($mode): $error');
      return false;
    }
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

  /// Arms (or re-arms) the OS alarm for a single task via the native
  /// AlarmManager scheduler, which rings through a foreground service loop.
  ///
  /// [promptPermission] is set only for explicit user actions (creating,
  /// editing or toggling an alarm) so the one-time notification prompt lands
  /// while the user is looking at it. Bulk syncs stay silent.
  Future<void> scheduleTaskAlarm(
    TaskItem task, {
    bool promptPermission = false,
  }) async {
    await init();
    if (!_initialised) return;

    // Drop any plugin-scheduled alarm that predates the native scheduler.
    await _safeCancel(taskNotificationId(task.id));

    final when = alarmDateTimeFor(task);
    if (when == null) {
      await NativeAlarmService.instance.cancelTaskAlarm(task.id);
      return;
    }
    if (!_permissionGranted && promptPermission && !await requestPermission()) {
      return;
    }

    await NativeAlarmService.instance.scheduleTaskAlarm(
      taskId: task.id,
      title: task.title,
      whenMs: when.millisecondsSinceEpoch,
    );
  }

  /// Re-arms the same task id for [minutes] from now. Falls back to the
  /// configured snooze duration when [minutes] is omitted, which is what the
  /// background action path does.
  Future<void> scheduleSnooze(TaskItem task, {int? minutes}) async {
    await init();
    if (!_initialised) return;

    final prefs = await _readPrefs();
    final snoozeFor = minutes ?? prefs.snoozeMinutes;
    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: snoozeFor));
    await _safeCancel(taskNotificationId(task.id));
    await NativeAlarmService.instance.scheduleTaskAlarm(
      taskId: task.id,
      title: task.title,
      whenMs: when.millisecondsSinceEpoch,
    );
  }

  Future<void> cancelTaskAlarm(String taskId) async {
    await init();
    if (!_initialised) return;
    await _safeCancel(taskNotificationId(taskId));
    await NativeAlarmService.instance.cancelTaskAlarm(taskId);
  }

  /// Rebuilds every armed alarm from scratch. Used on launch so the OS queue
  /// stays in step with persisted state after a reboot or reinstall.
  Future<void> syncTaskAlarms(List<TaskItem> tasks) async {
    await init();
    if (!_initialised) return;

    for (final task in tasks) {
      if (alarmDateTimeFor(task) != null) {
        await scheduleTaskAlarm(task);
      } else {
        await cancelTaskAlarm(task.id);
      }
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
    // Never prompt from here: this fires from a usage poll, so the sheet the
    // user would see has nothing to do with notifications.
    if (!_permissionGranted && !await notificationsEnabled()) return;
    _permissionGranted = true;

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

  /// Schedules (or reschedules) the single notification [note] asks for.
  /// Past reminders and notes without a reminder clear the slot instead.
  Future<void> scheduleNoteReminder(Note note) async {
    await init();
    if (!_initialised) return;

    final id = noteReminderNotificationId(note.id);
    await _safeCancel(id);

    final when = note.reminderAt;
    if (when == null || !when.isAfter(tz.TZDateTime.now(tz.local).toLocal())) {
      return;
    }

    final prefs = await _readPrefs();
    await _scheduleAt(
      id: id,
      title: note.title.isEmpty ? 'Note reminder' : note.title,
      body: _noteBody(note),
      when: tz.TZDateTime.from(when, tz.local),
      details: _reminderDetails(prefs),
      payload: '$_kPayloadNotePrefix${note.id}',
    );
  }

  Future<void> cancelNoteReminder(String noteId) async {
    await init();
    if (!_initialised) return;
    await _safeCancel(noteReminderNotificationId(noteId));
  }

  /// Reconciles the OS queue with persisted notes. Called on launch and after
  /// any write so a reminder cannot outlive the note it belongs to.
  Future<void> syncNoteReminders(List<Note> notes) async {
    await init();
    if (!_initialised) return;

    final armed = <int>{};
    for (final note in notes) {
      final id = noteReminderNotificationId(note.id);
      armed.add(id);
      await scheduleNoteReminder(note);
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.id < _kNoteReminderIdBase) continue;
        if (request.id < _kNoteReminderIdBase + _kIdSpace &&
            !armed.contains(request.id)) {
          await _safeCancel(request.id);
        }
      }
    } catch (error) {
      debugPrint('Failed to prune orphaned note reminders: $error');
    }
  }

  /// Arms the repeating evening reminder, or removes it when [enabled] is
  /// false. [matchDateTimeComponents] makes the OS repeat at [hour]:[minute]
  /// every day, so one scheduled entry covers every future evening.
  Future<void> syncStreakReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await init();
    if (!_initialised) return;

    if (!enabled) {
      await _safeCancel(_kStreakReminderId);
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }

    final prefs = await _readPrefs();
    await _scheduleAt(
      id: _kStreakReminderId,
      title: 'Keep your streaks alive',
      body: 'Check in on today\'s habits before midnight.',
      when: when,
      details: _reminderDetails(prefs, streak: true),
      payload: _kPayloadStreak,
      match: DateTimeComponents.time,
    );
  }

  /// One-off celebration when a habit crosses a milestone length.
  Future<void> showStreakMilestone(Habit habit) async {
    await init();
    if (!_initialised) return;
    if (!_streakMilestones.contains(habit.streak)) return;
    if (!_permissionGranted && !await notificationsEnabled()) return;
    _permissionGranted = true;

    final prefs = await _readPrefs();
    try {
      await _plugin.show(
        id: _kStreakMilestoneIdBase + _stableId(habit.id),
        title: '${habit.streak} day streak!',
        body:
            '${habit.title} has run for ${habit.streak} days in a row. Keep it going.',
        notificationDetails: _reminderDetails(prefs, streak: true),
        payload: _kPayloadStreak,
      );
    } catch (error) {
      debugPrint('Failed to show streak milestone for ${habit.id}: $error');
    }
  }

  NotificationDetails _reminderDetails(
    _AlarmPrefs prefs, {
    bool streak = false,
  }) {
    final channel = streak ? _kStreakChannel : _kNoteReminderChannel;
    final name = streak ? 'Streak Reminders' : 'Note Reminders';
    final description = streak
        ? 'Evening check-in and streak milestones'
        : 'Reminders attached to saved notes';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        name,
        channelDescription: description,
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFF7C5CFF),
        playSound: prefs.sound,
        enableVibration: prefs.vibration,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: prefs.sound,
        interruptionLevel: prefs.bypassDnd
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );
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

  static const Set<int> _streakMilestones = {
    3,
    7,
    14,
    21,
    30,
    50,
    75,
    100,
    150,
    200,
    365,
  };

  String _noteBody(Note note) {
    final text = note.content.trim();
    if (text.isEmpty) return 'Your note is waiting.';
    return text.length > 120 ? '${text.substring(0, 117)}…' : text;
  }
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
