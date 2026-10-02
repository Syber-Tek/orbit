import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/utils/theme_provider.dart';
import 'package:orbit/widgets/liquid_glass_nav_bar.dart';

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
      icon: IconlyLight.wallet,
      activeIcon: IconlyBold.wallet,
      label: 'Expenses',
    ),
    LiquidNavItem(
      builder: (context, isSelected, color) => TargetArrowIcon(
        color: color,
        isSelected: isSelected,
      ),
      label: 'Goals',
    ),
    const LiquidNavItem(
      icon: IconlyLight.profile,
      activeIcon: IconlyBold.profile,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _TabPlaceholder(title: 'Home', icon: IconlyLight.home),
          _TabPlaceholder(title: 'Expenses', icon: IconlyLight.wallet),
          _TabPlaceholder(title: 'Goals', icon: IconlyLight.discovery),
          _ProfileTab(),
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
        onAddExpense: () {
          // TODO: Open add expense workflow
        },
        onAddTodo: () {
          // TODO: Open add todo workflow
        },
        onAddNote: () {
          // TODO: Open add note workflow
        },
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Appearance & Preferences',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
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
                        'Theme Mode',
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
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

class _TabPlaceholder extends StatelessWidget {
  final String title;
  final IconData icon;

  const _TabPlaceholder({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
