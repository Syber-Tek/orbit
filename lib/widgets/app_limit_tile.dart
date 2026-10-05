import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/screen_time.dart';

class AppLimitTile extends StatelessWidget {
  final AppUsageItem app;
  final VoidCallback onTap;
  final VoidCallback onLockedTap;

  const AppLimitTile({
    super.key,
    required this.app,
    required this.onTap,
    required this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color progressColor;
    if (app.isLocked) {
      progressColor = const Color(0xFFEF4444); // Red
    } else if (app.is5MinWarning) {
      progressColor = const Color(0xFFFF5500); // Bright Orange Warning
    } else if (app.is10MinWarning) {
      progressColor = const Color(0xFFFFB800); // Amber Warning
    } else {
      progressColor = isDark ? Colors.white : const Color(0xFF18181B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: app.isLocked
              ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.4 : 0.3)
              : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (app.isLocked) {
              onLockedTap();
            } else {
              onTap();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon, App Name, Category, and Status/Time
                Row(
                  children: [
                    // App Icon Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(app.colorValue).withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(
                          IconData(app.iconCodePoint, fontFamily: 'MaterialIcons'),
                          color: Color(app.colorValue),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // App Title & Category Tag
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  app.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (app.isLocked) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.25 : 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_rounded, size: 10, color: Color(0xFFEF4444)),
                                      SizedBox(width: 3),
                                      Text(
                                        "Time's Up",
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (app.is5MinWarning) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5500).withValues(alpha: isDark ? 0.25 : 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "⚠️ 5m left",
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFF5500),
                                    ),
                                  ),
                                ),
                              ] else if (app.is10MinWarning) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB800).withValues(alpha: isDark ? 0.25 : 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "⏳ 10m left",
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFFB800),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            app.category.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Usage / Limit Text & Action Chevron
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          app.formattedTimeSpent,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: app.isLocked ? const Color(0xFFEF4444) : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.hasLimit ? 'of ${app.formattedLimit}' : 'No limit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      IconlyLight.arrowRight2,
                      size: 14,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: app.progress,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? const Color(0xFF242630)
                        : const Color(0xFFEBEBE6),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
