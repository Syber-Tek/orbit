import 'package:flutter/material.dart';

import 'package:orbit/services/notification_service.dart';
import 'package:orbit/utils/app_haptics.dart';

/// One-time onboarding dialog shown on first launch.
///
/// Step one explains why Orbit posts notifications and asks for the standard
/// notification permission. Step two (Android only) explains the restricted
/// "Alarms & reminders" permission and sends the user to the system settings
/// screen to grant it, so task alarms can fire on the exact minute.
class NotificationPermissionSheet extends StatefulWidget {
  const NotificationPermissionSheet({
    super.key,
    required this.onNotNow,
    required this.onEnable,
  });

  final Future<void> Function() onNotNow;
  final Future<void> Function() onEnable;

  @override
  State<NotificationPermissionSheet> createState() =>
      _NotificationPermissionSheetState();
}

class _NotificationPermissionSheetState
    extends State<NotificationPermissionSheet> {
  bool _showExactAlarmStep = false;

  Future<void> _requestStepOne() async {
    // The OS permission dialog appears over this sheet and resolves to the
    // exact-alarm explanation afterwards.
    await NotificationService.instance.requestPermission();
    if (!mounted) return;
    final canExact = await NotificationService.instance.canScheduleExact();
    if (!mounted) return;
    if (canExact) {
      // Already allowed (Android 11 and below) so there is nothing more to ask.
      await _finish();
      return;
    }
    setState(() => _showExactAlarmStep = true);
  }

  Future<void> _requestStepTwo() async {
    await NotificationService.instance.requestExactAlarmPermission();
    await _finish();
  }

  Future<void> _finish() async {
    await widget.onEnable();
  }

  Future<void> _dismiss() async {
    await widget.onNotNow();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final title = _showExactAlarmStep
        ? 'Exact alarm reminders'
        : 'Enable notifications';
    final body = _showExactAlarmStep
        ? 'Task reminders should ring at the exact minute you set. Android '
              'gives apps a special "Alarms & reminders" permission for that.\n\n'
              'Tap Continue to open the system screen and allow it for Orbit. If '
              'you skip, alarms still ring — just not exactly on the minute.'
        : 'Orbit sends notifications so nothing slips: task alarms, note '
              'reminders, habit streak check-ins, and screen time limit warnings.\n\n'
              'Allow notifications to receive these even when the app is closed. '
              'You can change this later in Android settings.';
    final primary = _showExactAlarmStep ? 'Continue' : 'Allow notifications';
    final secondary = _showExactAlarmStep ? 'Skip' : 'Not now';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF18191E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 340, maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.15),
                ),
                child: Icon(
                  _showExactAlarmStep
                      ? Icons.alarm_rounded
                      : Icons.notifications_active_rounded,
                  size: 34,
                  color: const Color(0xFF7C5CFF),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        AppHaptics.selectionClick();
                        if (_showExactAlarmStep) {
                          _finish();
                        } else {
                          _dismiss();
                        }
                      },
                      child: Text(secondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _showExactAlarmStep
                          ? _requestStepTwo
                          : _requestStepOne,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C5CFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        primary,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
