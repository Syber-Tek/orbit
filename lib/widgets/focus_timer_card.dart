import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/services/screen_time_provider.dart';

class FocusTimerCard extends ConsumerWidget {
  const FocusTimerCard({super.key});

  void _showCustomDurationSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    final focus = ref.read(focusSessionProvider);
    int tempMinutes = focus.targetMinutes;
    final titleController = TextEditingController(text: focus.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16171B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Customize Focus Timer',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          letterSpacing: -0.3,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set custom duration and session focus goal.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Session Label
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Session Name',
                      hintText: 'e.g. Deep Work, Coding, Reading',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Duration Display & Stepper
                  Text(
                    'DURATION (MINUTES)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1F26) : const Color(0xFFF6F6F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E303A) : const Color(0xFFDFDFD8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: tempMinutes > 5
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      setModalState(() => tempMinutes = (tempMinutes - 5).clamp(1, 180));
                                    }
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 24),
                            ),
                            IconButton(
                              onPressed: tempMinutes > 1
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      setModalState(() => tempMinutes = (tempMinutes - 1).clamp(1, 180));
                                    }
                                  : null,
                              icon: const Icon(Icons.remove_rounded, size: 20),
                            ),
                          ],
                        ),
                        Text(
                          '$tempMinutes min',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: tempMinutes < 180
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      setModalState(() => tempMinutes = (tempMinutes + 1).clamp(1, 180));
                                    }
                                  : null,
                              icon: const Icon(Icons.add_rounded, size: 20),
                            ),
                            IconButton(
                              onPressed: tempMinutes <= 175
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      setModalState(() => tempMinutes = (tempMinutes + 5).clamp(1, 180));
                                    }
                                  : null,
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Suggestion Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [10, 20, 25, 30, 45, 60, 90].map((mins) {
                      final isSelected = tempMinutes == mins;
                      return ChoiceChip(
                        label: Text('${mins}m'),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            HapticFeedback.selectionClick();
                            setModalState(() => tempMinutes = mins);
                          }
                        },
                        selectedColor: isDark ? Colors.white : const Color(0xFF18181B),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? (isDark ? const Color(0xFF141517) : Colors.white)
                              : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
                          ),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        final title = titleController.text.trim();
                        ref.read(focusSessionProvider.notifier).setCustomMinutes(
                              tempMinutes,
                              title: title.isNotEmpty ? title : 'Focus Session',
                            );
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : const Color(0xFF18181B),
                        foregroundColor: isDark ? const Color(0xFF141517) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Set Timer',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final focus = ref.watch(focusSessionProvider);
    final focusNotifier = ref.read(focusSessionProvider.notifier);

    final standardPresets = [15, 25, 45, 60];
    final isPresetSelected = standardPresets.contains(focus.targetMinutes);

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
                        'POMODORO FOCUS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            focus.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          if (!focus.isRunning) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _showCustomDurationSheet(context, ref),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 13,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
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
                        'Restricted',
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

          // Timer Display and Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Timer Digits with Quick Steppers when paused/idle
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: focus.isRunning ? null : () => _showCustomDurationSheet(context, ref),
                    child: Text(
                      focus.formattedRemaining,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                        letterSpacing: -1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (!focus.isRunning) ...[
                    const SizedBox(width: 6),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            focusNotifier.adjustMinutes(5);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('+5m', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: focus.targetMinutes > 5
                              ? () {
                                  HapticFeedback.selectionClick();
                                  focusNotifier.adjustMinutes(-5);
                                }
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('-5m', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              // Action Buttons
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

          // Progress Bar
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

          // Preset Selection Chips & Custom Picker
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip(
                  context,
                  focusNotifier,
                  label: '15m Quick',
                  title: 'Quick Focus',
                  minutes: 15,
                  isSelected: focus.targetMinutes == 15,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildPresetChip(
                  context,
                  focusNotifier,
                  label: '25m Pomodoro',
                  title: 'Pomodoro',
                  minutes: 25,
                  isSelected: focus.targetMinutes == 25,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildPresetChip(
                  context,
                  focusNotifier,
                  label: '45m Study',
                  title: 'Deep Study',
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
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showCustomDurationSheet(context, ref),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: !isPresetSelected
                          ? (isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !isPresetSelected
                            ? (isDark ? Colors.white24 : Colors.black12)
                            : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 13,
                          color: !isPresetSelected
                              ? (isDark ? Colors.white : const Color(0xFF18181B))
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          !isPresetSelected ? '${focus.targetMinutes}m (Custom)' : 'Custom...',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: !isPresetSelected ? FontWeight.w700 : FontWeight.w500,
                            color: !isPresetSelected
                                ? (isDark ? Colors.white : const Color(0xFF18181B))
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
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
