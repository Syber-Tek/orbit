import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
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
          _TabPlaceholder(title: 'Profile', icon: IconlyLight.profile),
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
