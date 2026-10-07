import 'package:flutter/material.dart';
import 'package:orbit/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/screen_time.dart';
import 'package:orbit/services/screen_time_provider.dart';
import 'package:orbit/widgets/add_custom_app_sheet.dart';
import 'package:orbit/widgets/app_limit_tile.dart';
import 'package:orbit/widgets/app_lockout_sheet.dart';
import 'package:orbit/widgets/focus_timer_card.dart';
import 'package:orbit/widgets/progress_dial.dart';
import 'package:orbit/widgets/screen_time_chart.dart';
import 'package:orbit/widgets/set_app_limit_sheet.dart';

class ScreenTimeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSettingsTap;

  const ScreenTimeScreen({
    super.key,
    this.onSettingsTap,
  });

  @override
  ConsumerState<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends ConsumerState<ScreenTimeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      ref.read(screenTimeProvider.notifier).refreshPermissionsAndUsage();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(screenTimeProvider.notifier).refreshPermissionsAndUsage();
    }
  }

  void _openAddCustomApp(BuildContext context) {
    AppHaptics.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddCustomAppSheet(),
    );
  }

  void _openSetLimit(BuildContext context, AppUsageItem app) {
    AppHaptics.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SetAppLimitSheet(app: app),
    );
  }

  void _openLockoutSheet(BuildContext context, AppUsageItem app) {
    AppHaptics.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppLockoutSheet(
        app: app,
        onEditLimit: () => _openSetLimit(context, app),
      ),
    );
  }

  Widget _buildBanner({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screenTimeState = ref.watch(screenTimeProvider);
    final warningApps = screenTimeState.warningApps;
    final lockedApps = screenTimeState.lockedApps;

    return CustomScrollView(
      key: const PageStorageKey('screentime_scroll'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Permission Banners (Top of Screen Time screen)
        if (!screenTimeState.hasUsagePermission)
          SliverToBoxAdapter(
            child: _buildBanner(
              context: context,
              icon: Icons.security_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Usage Access Required',
              message:
                  'Grant usage access so Orbit can track accurate screen time and manage app allowances.',
              actionLabel: 'Grant',
              onTap: () =>
                  ref.read(screenTimeProvider.notifier).openUsageSettings(),
            ),
          ),
        if (!screenTimeState.hasAccessibility)
          SliverToBoxAdapter(
            child: _buildBanner(
              context: context,
              icon: Icons.block_rounded,
              color: const Color(0xFFEF4444),
              title: 'App Blocker Disabled',
              message:
                  'Enable Orbit Screen Time Blocker in Accessibility so apps are actively closed when daily limits expire.',
              actionLabel: 'Enable',
              onTap: () => ref
                  .read(screenTimeProvider.notifier)
                  .openAccessibilitySettings(),
            ),
          ),
        if (screenTimeState.hasUsagePermission &&
            screenTimeState.apps.any((a) => a.hasLimit) &&
            !screenTimeState.isMonitorRunning)
          SliverToBoxAdapter(
            child: _buildBanner(
              context: context,
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFF97316),
              title: 'Monitor Service Stopped',
              message:
                  'The background service was stopped. Tap to resume automatic monitoring.',
              actionLabel: 'Restart',
              onTap: () => ref
                  .read(screenTimeProvider.notifier)
                  .restartMonitorService(),
            ),
          ),
        // Daily Screen Time Overview Bento Card (Image 1 & 3 style)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18191E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  // Text and Stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Screen Time Today',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          screenTimeState.formattedTotalSpent,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 26,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              IconlyLight.timeCircle,
                              size: 13,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'of ${screenTimeState.formattedDailyGoal} daily goal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Pickups Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                IconlyLight.chart,
                                size: 12,
                                color: isDark ? Colors.white : const Color(0xFF18181B),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${screenTimeState.pickupsToday} pickups today',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF18181B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Large Circular Progress Dial
                  ProgressDial(
                    value: screenTimeState.goalProgress,
                    size: 76,
                    progressColor: screenTimeState.goalProgress >= 1.0
                        ? const Color(0xFFEF4444)
                        : (isDark ? Colors.white : const Color(0xFF18181B)),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Urgent 10-min / 5-min Closing Warning Banner
        if (warningApps.isNotEmpty || lockedApps.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: lockedApps.isNotEmpty
                      ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.16 : 0.08)
                      : const Color(0xFFFF5500).withValues(alpha: isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: lockedApps.isNotEmpty
                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                        : const Color(0xFFFF5500).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      lockedApps.isNotEmpty
                          ? Icons.lock_clock_rounded
                          : Icons.warning_amber_rounded,
                      color: lockedApps.isNotEmpty
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFFF5500),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lockedApps.isNotEmpty
                                ? '${lockedApps.first.name} limit reached (Closed)'
                                : '${warningApps.first.name} closing in ${warningApps.first.remainingMinutes}m',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: lockedApps.isNotEmpty
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFFF5500),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lockedApps.isNotEmpty
                                ? 'App is locked to preserve your daily limit.'
                                : 'You will be locked out when the timer expires.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Activity Bar Chart
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ScreenTimeChart(
              hourlyUsage: screenTimeState.hourlyUsage,
            ),
          ),
        ),

        // Focus Mode Timer Card
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: FocusTimerCard(),
          ),
        ),

        // App Limits Section Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'App Limits & Usage',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${screenTimeState.apps.where((a) => a.hasLimit).length} active',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _openAddCustomApp(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: isDark ? Colors.white : const Color(0xFF18181B),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Add App',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF18181B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // App Limits List or Empty State
        if (screenTimeState.apps.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18191E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      IconlyLight.chart,
                      size: 36,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No apps tracked yet',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add a custom app to track usage and set closing alerts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _openAddCustomApp(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add App'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : const Color(0xFF18181B),
                        foregroundColor: isDark ? const Color(0xFF141517) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final app = screenTimeState.apps[index];
                  return AppLimitTile(
                    app: app,
                    onTap: () => _openSetLimit(context, app),
                    onLockedTap: () => _openLockoutSheet(context, app),
                  );
                },
                childCount: screenTimeState.apps.length,
              ),
            ),
          ),

        // Bottom Spacing for floating navbar
        const SliverToBoxAdapter(
          child: SizedBox(height: 110),
        ),
      ],
    );
  }
}
