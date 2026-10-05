import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/screen_time.dart';
import 'package:orbit/services/screen_time_provider.dart';
import 'package:orbit/widgets/add_custom_app_sheet.dart';
import 'package:orbit/widgets/app_limit_tile.dart';
import 'package:orbit/widgets/app_lockout_sheet.dart';
import 'package:orbit/widgets/focus_timer_card.dart';
import 'package:orbit/widgets/screen_time_chart.dart';
import 'package:orbit/widgets/set_app_limit_sheet.dart';

class ScreenTimeScreen extends ConsumerWidget {
  final VoidCallback? onSettingsTap;

  const ScreenTimeScreen({
    super.key,
    this.onSettingsTap,
  });

  void _openAddCustomApp(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddCustomAppSheet(),
    );
  }

  void _openSetLimit(BuildContext context, AppUsageItem app) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SetAppLimitSheet(app: app),
    );
  }

  void _openLockoutSheet(BuildContext context, AppUsageItem app) {
    HapticFeedback.heavyImpact();
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screenTimeState = ref.watch(screenTimeProvider);
    final warningApps = screenTimeState.warningApps;
    final lockedApps = screenTimeState.lockedApps;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
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
                          'SCREEN TIME TODAY',
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
                              const Icon(IconlyLight.chart, size: 12, color: Color(0xFF8B5CF6)),
                              const SizedBox(width: 5),
                              Text(
                                '${screenTimeState.pickupsToday} pickups today',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Large Circular Progress Dial (Matching Tasks Dial: 76x76)
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: screenTimeState.goalProgress,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          backgroundColor: isDark
                              ? const Color(0xFF272830)
                              : const Color(0xFFE5E5DF),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            screenTimeState.goalProgress >= 1.0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF8B5CF6),
                          ),
                        ),
                        Text(
                          '${(screenTimeState.goalProgress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
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
                  'APP LIMITS & USAGE',
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
