import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/screens/habits_screen.dart';
import 'package:orbit/screens/screen_time_screen.dart';
import 'package:orbit/screens/tasks_screen.dart';
import 'package:orbit/utils/theme_provider.dart';
import 'package:orbit/widgets/add_habit_sheet.dart';
import 'package:orbit/widgets/add_task_sheet.dart';
import 'package:orbit/widgets/liquid_glass_nav_bar.dart';
import 'package:orbit/widgets/note_editor_sheet.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

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

  void _showAddNote(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NoteEditorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HabitsScreen(
            onNavigateTab: (index) => setState(() => _currentIndex = index),
            onSettingsTap: () => _showSettingsSheet(context),
          ),
          TasksScreen(
            onSettingsTap: () => _showSettingsSheet(context),
          ),
          ScreenTimeScreen(
            onSettingsTap: () => _showSettingsSheet(context),
          ),
          const _PlaceholderTabView(
            title: 'Ledger',
            subtitle: 'Budget ceiling & expense tracking',
            icon: IconlyLight.wallet,
          ),
        ],
      ),
      bottomNavigationBar: LiquidGlassNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: _navItems,
        onAddHabit: () => _showAddHabit(context),
        onAddExpense: () {
          // TODO: Open add expense modal
        },
        onAddTodo: () => _showAddTask(context),
        onAddNote: () => _showAddNote(context),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
        ],
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

class _PlaceholderTabView extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PlaceholderTabView({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
