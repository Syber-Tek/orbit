import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/habit.dart';
import 'package:orbit/screens/all_notes_screen.dart';
import 'package:orbit/services/habit_provider.dart';
import 'package:orbit/services/note_provider.dart';
import 'package:orbit/widgets/add_habit_sheet.dart';
import 'package:orbit/widgets/daily_pulse_row.dart';
import 'package:orbit/widgets/habit_item_card.dart';
import 'package:orbit/widgets/note_card.dart';
import 'package:orbit/widgets/note_editor_sheet.dart';
import 'package:orbit/widgets/streak_hero_card.dart';

class HabitsScreen extends ConsumerWidget {
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onSettingsTap;

  const HabitsScreen({super.key, this.onNavigateTab, this.onSettingsTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final habits = ref.watch(filteredHabitsProvider);
    final allHabits = ref.watch(habitListProvider);
    final activeFilter = ref.watch(selectedHabitFilterProvider);

    final completedCount = allHabits.where((h) => h.isCompletedToday).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const PageStorageKey('habits_scroll'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Header Greeting & Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Orbit Daily',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      // Top Settings Button (Consistent across app)
                      IconButton(
                        onPressed: onSettingsTap,
                        tooltip: 'Settings & Theme',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF1E1F25)
                              : const Color(0xFFEEEEEE),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(IconlyLight.setting, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Hero Streak Card (Refs 1 & 5)
                  const StreakHeroCard(),
                  const SizedBox(height: 24),

                  // Orbit Pulse Bento Row (Ref 4)
                  DailyPulseRow(
                    onScreenTimeTap: () =>
                        onNavigateTab?.call(2), // Screen Time Tab
                    onAlarmsTap: () =>
                        onNavigateTab?.call(1), // Alarms & Tasks Tab
                    onBudgetTap: () => onNavigateTab?.call(3), // Budget Tab
                  ),
                  const SizedBox(height: 26),

                  // Section Title & Filter Pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s Habits',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '$completedCount/${allHabits.length} Done',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Row (All, Morning, Afternoon, Evening)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill(
                          context: context,
                          ref: ref,
                          label: 'All Habits',
                          isSelected: activeFilter == null,
                          onTap: () => ref
                              .read(selectedHabitFilterProvider.notifier)
                              .setFilter(null),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          context: context,
                          ref: ref,
                          label: 'Morning',
                          isSelected: activeFilter == HabitTimeOfDay.morning,
                          onTap: () => ref
                              .read(selectedHabitFilterProvider.notifier)
                              .setFilter(HabitTimeOfDay.morning),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          context: context,
                          ref: ref,
                          label: 'Afternoon',
                          isSelected: activeFilter == HabitTimeOfDay.afternoon,
                          onTap: () => ref
                              .read(selectedHabitFilterProvider.notifier)
                              .setFilter(HabitTimeOfDay.afternoon),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          context: context,
                          ref: ref,
                          label: 'Evening',
                          isSelected: activeFilter == HabitTimeOfDay.evening,
                          onTap: () => ref
                              .read(selectedHabitFilterProvider.notifier)
                              .setFilter(HabitTimeOfDay.evening),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Habits List
                  if (habits.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          'No habits for this time period.',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    ...habits.map((habit) {
                      return HabitItemCard(
                        habit: habit,
                        onToggle: () {
                          ref
                              .read(habitListProvider.notifier)
                              .toggleHabit(habit.id);
                        },
                        onEdit: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) =>
                                AddHabitSheet(initialHabit: habit),
                          );
                        },
                        onDelete: () {
                          ref
                              .read(habitListProvider.notifier)
                              .deleteHabit(habit.id);
                        },
                      );
                    }),

                  const SizedBox(height: 28),

                  // Quick Notes Section (Inspired by Ref 3)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quick Notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => const NoteEditorSheet(),
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 20),
                            tooltip: 'Add Note',
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(34, 34),
                              backgroundColor: isDark
                                  ? const Color(0xFF1E1F25)
                                  : const Color(0xFFEEEEEE),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AllNotesScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1F25)
                                    : const Color(0xFFEEEEEE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'All Notes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_outward_rounded,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2 Note Cards Preview
                  Builder(
                    builder: (context) {
                      final topNotes = ref.watch(topNotesProvider);
                      if (topNotes.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF18191E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF272830)
                                  : const Color(0xFFE5E5DF),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'No notes yet. Tap + to add one.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 150,
                              child: NoteCard(note: topNotes[0]),
                            ),
                          ),
                          if (topNotes.length > 1) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 150,
                                child: NoteCard(note: topNotes[1]),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark ? const Color(0xFF1E1F25) : const Color(0xFFEEEEEA)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? theme.colorScheme.onPrimary
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}
