import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/screens/habits_screen.dart';
import 'package:orbit/screens/ledger_screen.dart';
import 'package:orbit/screens/screen_time_screen.dart';
import 'package:orbit/screens/tasks_screen.dart';
import 'package:orbit/services/nav_bar_settings_provider.dart';
import 'package:orbit/services/notification_service.dart';
import 'package:orbit/services/notification_settings_provider.dart';
import 'package:orbit/services/persistence_service.dart';
import 'package:orbit/services/task_provider.dart';
import 'package:orbit/utils/app_haptics.dart';
import 'package:orbit/utils/theme_provider.dart';
import 'package:orbit/widgets/add_custom_app_sheet.dart';
import 'package:orbit/widgets/add_habit_sheet.dart';
import 'package:orbit/widgets/add_task_sheet.dart';
import 'package:orbit/widgets/add_transaction_sheet.dart';
import 'package:orbit/widgets/liquid_glass_nav_bar.dart';
import 'package:orbit/widgets/note_editor_sheet.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late int _currentIndex = PersistenceService.instance.loadActiveTab().clamp(
    0,
    3,
  );
  late final PageController _pageController = PageController(
    initialPage: _currentIndex,
  );

  @override
  void initState() {
    super.initState();
    _setupNotificationActionHandler();
    _startAlwaysOnMonitoring();
    _requestSystemNotificationPermission();
    _requestBatteryExemption();
  }

  /// Starts the foreground monitor service so Orbit keeps running in the
  /// background with a permanent status notification, like a system service.
  Future<void> _startAlwaysOnMonitoring() async {
    try {
      await const MethodChannel(
        'com.example.orbit/usage_stats',
      ).invokeMethod('startMonitorService');
    } catch (_) {
      // Best-effort; the service also restarts on boot.
    }
  }

  /// One-time system prompt asking to exempt Orbit from battery optimizations
  /// so the OEM never freezes or kills it in the background.
  Future<void> _requestBatteryExemption() async {
    final prefs = await PersistenceService.instance.init();
    if (prefs.getBool('orbit.battery_exemption_prompted') ?? false) return;
    await prefs.setBool('orbit.battery_exemption_prompted', true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await const MethodChannel(
          'com.example.orbit/usage_stats',
        ).invokeMethod('requestIgnoreBatteryOptimizations');
      } catch (_) {
        // Ignored when the OS dialog cannot be shown.
      }
    });
  }

  void _setupNotificationActionHandler() {
    NotificationService.instance.actionHandler = (actionId, taskId) async {
      if (actionId == kActionDismiss) {
        ref.read(taskListProvider.notifier).markTaskDone(taskId);
      } else if (actionId == kActionSnooze) {
        final settings = ref.read(notificationSettingsProvider);
        final tasks = ref.read(taskListProvider);
        for (final task in tasks) {
          if (task.id == taskId) {
            await NotificationService.instance.scheduleSnooze(
              task,
              minutes: settings.snoozeMinutes,
            );
            break;
          }
        }
      }
    };
    NotificationService.instance.payloadHandler = (payload) async {
      if (payload.startsWith('screentime:')) {
        _switchToTab(2);
        return;
      }
      // Notes and streak reminders open the home tab, which hosts them.
      _switchToTab(0);
    };
  }

  void _switchToTab(int index) {
    if (!mounted) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
    PersistenceService.instance.saveActiveTab(index);
  }

  /// Asks via the OS permission dialog only — no custom onboarding UI.
  Future<void> _requestSystemNotificationPermission() async {
    await NotificationService.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await NotificationService.instance.notificationsEnabled()) return;
      await NotificationService.instance.requestPermission();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<LiquidNavItem> _navItems = [
    const LiquidNavItem(
      icon: IconlyLight.home,
      activeIcon: IconlyBold.home,
      label: 'Home',
    ),
    const LiquidNavItem(
      icon: IconlyLight.timeCircle,
      activeIcon: IconlyBold.timeCircle,
      label: 'Tasks',
    ),
    const LiquidNavItem(
      icon: IconlyLight.chart,
      activeIcon: IconlyBold.chart,
      label: 'Screen Time',
    ),
    const LiquidNavItem(
      icon: IconlyLight.wallet,
      activeIcon: IconlyBold.wallet,
      label: 'Ledger',
    ),
  ];

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SettingsSheet(),
    );
  }

  void _showAddHabit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddHabitSheet(),
    );
  }

  void _showAddTask(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTaskSheet(),
    );
  }

  void _showAddExpense(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTransactionSheet(),
    );
  }

  void _showAddNote(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NoteEditorSheet(),
    );
  }

  void _showAddAppLimit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddCustomAppSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBarOpacity = ref.watch(navBarOpacityProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
          );
        } else {
          // Move task to background without killing activity
          const MethodChannel(
            'com.example.orbit/usage_stats',
          ).invokeMethod('moveTaskToBack').catchError((_) {});
        }
      },
      child: Scaffold(
        extendBody: true,
        appBar: _currentIndex == 0
            ? null
            : AppBar(
                title: Text(
                  _navItems[_currentIndex].label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(IconlyLight.setting, size: 22),
                    onPressed: () => _showSettingsSheet(context),
                    tooltip: 'Settings & Theme',
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF1E1F25)
                          : const Color(0xFFEEEEEE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
        body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            PersistenceService.instance.saveActiveTab(index);
          },
          children: [
            HabitsScreen(
              key: const PageStorageKey('tab_habits'),
              onNavigateTab: (index) {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                );
              },
              onSettingsTap: () => _showSettingsSheet(context),
            ),
            TasksScreen(
              key: const PageStorageKey('tab_tasks'),
              onSettingsTap: () => _showSettingsSheet(context),
            ),
            ScreenTimeScreen(
              key: const PageStorageKey('tab_screen_time'),
              onSettingsTap: () => _showSettingsSheet(context),
            ),
            LedgerScreen(
              key: const PageStorageKey('tab_ledger'),
              onSettingsTap: () => _showSettingsSheet(context),
            ),
          ],
        ),
        bottomNavigationBar: LiquidGlassNavBar(
          currentIndex: _currentIndex,
          opacity: navBarOpacity,
          onTap: (index) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
            );
          },
          items: _navItems,
          onAddHabit: () => _showAddHabit(context),
          onAddExpense: () => _showAddExpense(context),
          onAddTodo: () => _showAddTask(context),
          onAddAppLimit: () => _showAddAppLimit(context),
          onAddNote: () => _showAddNote(context),
        ),
      ),
    );
  }
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final navBarOpacity = ref.watch(navBarOpacityProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);
    final notifSettings = ref.watch(notificationSettingsProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settings & Preferences',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // --- 1. Appearance Section ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 20,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Appearance',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildThemeOption(
                          context: context,
                          ref: ref,
                          mode: ThemeMode.light,
                          label: 'Light',
                          icon: Icons.light_mode_outlined,
                          selected: themeMode == ThemeMode.light,
                        ),
                        const SizedBox(width: 8),
                        _buildThemeOption(
                          context: context,
                          ref: ref,
                          mode: ThemeMode.dark,
                          label: 'Dark',
                          icon: Icons.dark_mode_outlined,
                          selected: themeMode == ThemeMode.dark,
                        ),
                        const SizedBox(width: 8),
                        _buildThemeOption(
                          context: context,
                          ref: ref,
                          mode: ThemeMode.system,
                          label: 'Auto',
                          icon: Icons.brightness_auto_outlined,
                          selected: themeMode == ThemeMode.system,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // --- 2. Navigation Bar Transparency Section ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Icon(
                            //   Icons.view_compact_rounded,
                            //   size: 20,
                            //   color: theme.colorScheme.onSurface,
                            // ),
                            // const SizedBox(width: 10),
                            Text(
                              'Navbar Transparency',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(navBarOpacity * 100).toInt()}% Opacity',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Control the frosted glass translucency of the bottom navigation bar.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: theme.colorScheme.primary,
                        inactiveTrackColor: theme.colorScheme.outlineVariant,
                        thumbColor: theme.colorScheme.primary,
                        overlayColor: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: navBarOpacity,
                        min: 0.20,
                        max: 1.0,
                        divisions: 16,
                        label: '${(navBarOpacity * 100).toInt()}%',
                        onChanged: (val) {
                          ref
                              .read(navBarOpacityProvider.notifier)
                              .setOpacity(val);
                        },
                      ),
                    ),
                    Row(
                      children: [
                        _buildOpacityPreset(
                          context: context,
                          ref: ref,
                          label: 'Glass 40%',
                          targetValue: 0.40,
                          currentValue: navBarOpacity,
                        ),
                        const SizedBox(width: 8),
                        _buildOpacityPreset(
                          context: context,
                          ref: ref,
                          label: 'Frosted 70%',
                          targetValue: 0.70,
                          currentValue: navBarOpacity,
                        ),
                        const SizedBox(width: 8),
                        _buildOpacityPreset(
                          context: context,
                          ref: ref,
                          label: 'Solid 100%',
                          targetValue: 1.0,
                          currentValue: navBarOpacity,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // --- 3. Vibration & Haptics Section ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.vibration_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Vibration & Haptics',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Touch Haptic Feedback',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Vibrate on nav taps and button interactions',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: hapticsEnabled,
                          activeTrackColor: theme.colorScheme.primary,
                          onChanged: (val) {
                            ref
                                .read(hapticsEnabledProvider.notifier)
                                .setEnabled(val);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alarm & Reminder Vibration',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Vibrate when alarms and reminders trigger',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: notifSettings.vibrationEnabled,
                          activeTrackColor: theme.colorScheme.primary,
                          onChanged: (val) {
                            ref
                                .read(notificationSettingsProvider.notifier)
                                .setVibrationEnabled(val);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alarm Sound',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Play audio chime when alarms trigger',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: notifSettings.soundEnabled,
                          activeTrackColor: theme.colorScheme.primary,
                          onChanged: (val) {
                            ref
                                .read(notificationSettingsProvider.notifier)
                                .setSoundEnabled(val);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Alarm Ring Duration Selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alarm Ring Duration',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rings continuously until snoozed, marked done, or duration ends',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildOptionChip(
                              context: context,
                              label: '1 min',
                              isSelected:
                                  notifSettings.alarmDurationMinutes == 1,
                              onTap: () {
                                ref
                                    .read(notificationSettingsProvider.notifier)
                                    .setAlarmDurationMinutes(1);
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildOptionChip(
                              context: context,
                              label: '2 mins',
                              isSelected:
                                  notifSettings.alarmDurationMinutes == 2,
                              onTap: () {
                                ref
                                    .read(notificationSettingsProvider.notifier)
                                    .setAlarmDurationMinutes(2);
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildOptionChip(
                              context: context,
                              label: '3 mins',
                              isSelected:
                                  notifSettings.alarmDurationMinutes == 3,
                              onTap: () {
                                ref
                                    .read(notificationSettingsProvider.notifier)
                                    .setAlarmDurationMinutes(3);
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildOptionChip(
                              context: context,
                              label: '5 mins',
                              isSelected:
                                  notifSettings.alarmDurationMinutes == 5,
                              onTap: () {
                                ref
                                    .read(notificationSettingsProvider.notifier)
                                    .setAlarmDurationMinutes(5);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Snooze Duration Selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Snooze Duration',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Minutes before a snoozed alarm alerts again',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildOptionChip(
                              context: context,
                              label: '5 mins',
                              isSelected: notifSettings.snoozeMinutes == 5,
                              onTap: () {
                                ref
                                    .read(notificationSettingsProvider.notifier)
                                    .setSnoozeMinutes(5);
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildOptionChip(
                              context: context,
                              label: '10 mins',
                              isSelected: notifSettings.snoozeMinutes == 10,
                              onTap: () {
                                ref
                                    .read(notificationSettingsProvider.notifier)
                                    .setSnoozeMinutes(10);
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildOptionChip(
                              context: context,
                              label: '15 mins',
                              isSelected: notifSettings.snoozeMinutes == 15,
                              onTap: () {
                                ref
                                    .read(notificationSettingsProvider.notifier)
                                    .setSnoozeMinutes(15);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Streak Reminder
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Streak Reminder',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Daily nudge to finish today\'s habits before the day ends',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: notifSettings.streakReminderEnabled,
                              activeTrackColor: theme.colorScheme.primary,
                              onChanged: (val) {
                                ref
                                    .read(notificationSettingsProvider.notifier)
                                    .setStreakReminderEnabled(val);
                              },
                            ),
                          ],
                        ),
                        if (notifSettings.streakReminderEnabled) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildOptionChip(
                                context: context,
                                label: '6 PM',
                                isSelected:
                                    notifSettings.streakReminderHour == 18,
                                onTap: () {
                                  ref
                                      .read(
                                        notificationSettingsProvider.notifier,
                                      )
                                      .setStreakReminderHour(18);
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildOptionChip(
                                context: context,
                                label: '8 PM',
                                isSelected:
                                    notifSettings.streakReminderHour == 20,
                                onTap: () {
                                  ref
                                      .read(
                                        notificationSettingsProvider.notifier,
                                      )
                                      .setStreakReminderHour(20);
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildOptionChip(
                                context: context,
                                label: '10 PM',
                                isSelected:
                                    notifSettings.streakReminderHour == 22,
                                onTap: () {
                                  ref
                                      .read(
                                        notificationSettingsProvider.notifier,
                                      )
                                      .setStreakReminderHour(22);
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.16)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpacityPreset({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required double targetValue,
    required double currentValue,
  }) {
    final theme = Theme.of(context);
    final isSelected = (currentValue - targetValue).abs() < 0.05;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selectionClick();
          ref.read(navBarOpacityProvider.notifier).setOpacity(targetValue);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.16)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeMode mode,
    required String label,
    required IconData icon,
    required bool selected,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selectionClick();
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
