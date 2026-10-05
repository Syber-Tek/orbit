import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/services/screen_time_provider.dart';

class FocusTimerCard extends ConsumerWidget {
  const FocusTimerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final focus = ref.watch(focusSessionProvider);
    final focusNotifier = ref.read(focusSessionProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focus.isRunning
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        size: 17,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FOCUS MODE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        focus.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (focus.isRunning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_clock_rounded, size: 12, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 4),
                      Text(
                        'Apps Restricted',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Timer Display and Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                focus.formattedRemaining,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  letterSpacing: -1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Row(
                children: [
                  if (focus.elapsedSeconds > 0)
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        focusNotifier.reset();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'Reset',
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      if (focus.isRunning) {
                        focusNotifier.pause();
                      } else {
                        focusNotifier.start();
                      }
                    },
                    icon: Icon(
                      focus.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 20,
                    ),
                    label: Text(
                      focus.isRunning ? 'Pause' : 'Start Focus',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : const Color(0xFF18181B),
                      foregroundColor: isDark ? const Color(0xFF141517) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: focus.progress,
              minHeight: 5,
              backgroundColor: isDark
                  ? const Color(0xFF242630)
                  : const Color(0xFFEBEBE6),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(height: 14),

          // Preset Selection Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip(
                  context,
                  focusNotifier,
                  label: '25m Pomodoro',
                  title: 'Deep Work',
                  minutes: 25,
                  isSelected: focus.targetMinutes == 25,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildPresetChip(
                  context,
                  focusNotifier,
                  label: '45m Study',
                  title: 'Focused Study',
                  minutes: 45,
                  isSelected: focus.targetMinutes == 45,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildPresetChip(
                  context,
                  focusNotifier,
                  label: '60m Flow',
                  title: 'Flow State',
                  minutes: 60,
                  isSelected: focus.targetMinutes == 60,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(
    BuildContext context,
    FocusSessionNotifier notifier, {
    required String label,
    required String title,
    required int minutes,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        notifier.setPreset(title: title, minutes: minutes);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white24 : Colors.black12)
                : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF18181B))
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}
