import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef NavItemWidgetBuilder = Widget Function(
  BuildContext context,
  bool isSelected,
  Color color,
);

class LiquidNavItem {
  final IconData? icon;
  final IconData? activeIcon;
  final NavItemWidgetBuilder? builder;
  final String label;

  const LiquidNavItem({
    this.icon,
    this.activeIcon,
    this.builder,
    required this.label,
  }) : assert(icon != null || builder != null, 'Either icon or builder must be provided');
}

/// Target Circle with Arrow icon matching reference image ae955170a457f291c2a6c3e2e1d3a231.jpg
class TargetArrowIcon extends StatelessWidget {
  final Color color;
  final double size;
  final bool isSelected;

  const TargetArrowIcon({
    super.key,
    required this.color,
    this.size = 24,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TargetArrowPainter(color: color, isSelected: isSelected),
    );
  }
}

class _TargetArrowPainter extends CustomPainter {
  final Color color;
  final bool isSelected;

  _TargetArrowPainter({required this.color, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width * 0.44, size.height * 0.56);
    final outerRadius = size.width * 0.38;
    final innerRadius = size.width * 0.19;

    // Draw outer arc (leaving opening at top-right where arrow enters)
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    canvas.drawArc(outerRect, -0.25, 2 * 3.14159 - 0.95, false, paint);

    // Draw inner circle
    canvas.drawCircle(center, innerRadius, paint);

    // Draw arrow shaft pointing from top-right into bullseye
    final arrowStart = Offset(size.width * 0.88, size.height * 0.12);
    final arrowTip = center;
    canvas.drawLine(arrowStart, arrowTip, paint);

    // Arrowhead at center
    final headLen = size.width * 0.16;
    final head1 = arrowTip + Offset(headLen * 0.85, -headLen * 0.2);
    final head2 = arrowTip + Offset(headLen * 0.2, -headLen * 0.85);
    canvas.drawLine(arrowTip, head1, paint);
    canvas.drawLine(arrowTip, head2, paint);

    // Small arrow fletching at tail
    final tail1 = arrowStart + Offset(-headLen * 0.55, -headLen * 0.15);
    final tail2 = arrowStart + Offset(headLen * 0.15, headLen * 0.55);
    canvas.drawLine(arrowStart, tail1, paint);
    canvas.drawLine(arrowStart, tail2, paint);
  }

  @override
  bool shouldRepaint(_TargetArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isSelected != isSelected;
}

class LiquidGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LiquidNavItem> items;
  final VoidCallback? onAddHabit;
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddTodo;
  final VoidCallback? onAddNote;

  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.onAddHabit,
    this.onAddExpense,
    this.onAddTodo,
    this.onAddNote,
  });

  void _showQuickActionSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.88),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.7),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quick Action',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.local_fire_department_rounded,
                    title: 'New Habit',
                    subtitle: 'Track a new daily routine or goal',
                    accentColor: const Color(0xFFFF6B2B),
                    onTap: () {
                      Navigator.pop(ctx);
                      onAddHabit?.call();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.savings_rounded,
                    title: 'New Expense / Budget',
                    subtitle: 'Log a payment or manage budget',
                    accentColor: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(ctx);
                      onAddExpense?.call();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.track_changes_rounded,
                    title: 'New Task',
                    subtitle: 'Add a todo or reminder',
                    accentColor: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.pop(ctx);
                      onAddTodo?.call();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.sticky_note_2_rounded,
                    title: 'New Note',
                    subtitle: 'Create a rich-text document',
                    accentColor: const Color(0xFFF59E0B),
                    onTap: () {
                      Navigator.pop(ctx);
                      onAddNote?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(icon, color: accentColor, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: bottomPadding > 0 ? bottomPadding + 4 : 14,
      ),
      child: Row(
        children: [
          // Left: Frosted Glass Floating Navigation Pill (Icon-only)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C1D21).withValues(alpha: 0.82)
                        : const Color(0xFFFFFFFF).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2A2B30)
                          : const Color(0xFFE5E5DF),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.35)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 24,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Smooth Active Capsule Selector Indicator
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment(
                          items.length > 1
                              ? -1.0 + (currentIndex / (items.length - 1)) * 2.0
                              : 0,
                          0,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: 1 / items.length,
                          heightFactor: 0.80,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.black.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.04),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Navigation Icons (No Labels)
                      Row(
                        children: List.generate(items.length, (index) {
                          final isSelected = index == currentIndex;
                          final item = items[index];

                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (!isSelected) {
                                  HapticFeedback.selectionClick();
                                  onTap(index);
                                }
                              },
                              child: Center(
                                child: AnimatedScale(
                                  scale: isSelected ? 1.08 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, anim) =>
                                        ScaleTransition(scale: anim, child: child),
                                    child: item.builder != null
                                        ? KeyedSubtree(
                                            key: ValueKey('${item.label}_$isSelected'),
                                            child: item.builder!(
                                              context,
                                              isSelected,
                                              isSelected
                                                  ? (isDark ? Colors.white : Colors.black87)
                                                  : (isDark
                                                      ? Colors.white.withValues(alpha: 0.40)
                                                      : Colors.black.withValues(alpha: 0.35)),
                                            ),
                                          )
                                        : Icon(
                                            isSelected
                                                ? (item.activeIcon ?? item.icon!)
                                                : item.icon!,
                                            key: ValueKey('${item.label}_$isSelected'),
                                            size: 24,
                                            color: isSelected
                                                ? (isDark
                                                    ? Colors.white
                                                    : Colors.black87)
                                                : (isDark
                                                    ? Colors.white.withValues(alpha: 0.40)
                                                    : Colors.black.withValues(alpha: 0.35)),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Right: Floating Circular "+" Action Button
          GestureDetector(
            onTap: () => _showQuickActionSheet(context),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFFEDEDEA) : const Color(0xFF18181B),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : const Color(0xFF18181B).withValues(alpha: 0.16),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  color: isDark ? const Color(0xFF141517) : Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
