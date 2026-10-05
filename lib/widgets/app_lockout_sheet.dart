import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/screen_time.dart';
import 'package:orbit/services/screen_time_provider.dart';

class AppLockoutSheet extends ConsumerWidget {
  final AppUsageItem app;
  final VoidCallback onEditLimit;

  const AppLockoutSheet({
    super.key,
    required this.app,
    required this.onEditLimit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16171B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Lock Icon in circular container
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.12),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.lock_rounded,
                size: 34,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // App Name and Limit Alert
          Text(
            "Time's Up!",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${app.name} is locked for today",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF27272A),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "You have reached your ${app.formattedLimit} limit on ${app.name}. This app is closed and restricted until midnight to keep your screen time in orbit.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Action 1: Grant 5 More Minutes (Emergency extension)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(screenTimeProvider.notifier).grantEmergencyTime(app.id, extensionMinutes: 5);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('+5 minutes granted for ${app.name}'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(IconlyLight.timeCircle, size: 18),
              label: const Text(
                'Request 5 More Minutes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : const Color(0xFF18181B),
                foregroundColor: isDark ? const Color(0xFF141517) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Action 2: Edit Limit or Close
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onEditLimit();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : const Color(0xFF18181B),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF2E303A) : const Color(0xFFD4D4CE),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Adjust Limit',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Keep Closed',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
