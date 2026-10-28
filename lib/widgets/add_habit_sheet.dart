import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/habit.dart';
import 'package:orbit/services/habit_provider.dart';

enum _RepeatPreset { daily, weekdays, weekends, custom }

class AddHabitSheet extends ConsumerStatefulWidget {
  final Habit? initialHabit;

  const AddHabitSheet({super.key, this.initialHabit});

  @override
  ConsumerState<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends ConsumerState<AddHabitSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;
  late final TextEditingController _unitController;

  late String _selectedCategory;
  late HabitTimeOfDay _selectedTimeOfDay;
  late int _selectedColor;
  late int _selectedIconCode;

  late _RepeatPreset _repeatPreset;
  late HabitRepeatUnit _customUnit;
  late int _repeatEvery;
  late Set<int> _repeatWeekdays;
  late int? _repeatDayOfMonth;
  DateTime? _onceDate;

  bool get _isEditing => widget.initialHabit != null;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Health', 'icon': Icons.favorite_rounded, 'color': 0xFF10B981},
    {'name': 'Mind', 'icon': Icons.self_improvement_rounded, 'color': 0xFF8B5CF6},
    {'name': 'Fitness', 'icon': Icons.fitness_center_rounded, 'color': 0xFFEC4899},
    {'name': 'Growth', 'icon': Icons.menu_book_rounded, 'color': 0xFFF59E0B},
    {'name': 'Focus', 'icon': Icons.timer_rounded, 'color': 0xFF3B82F6},
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.initialHabit;
    _titleController = TextEditingController(text: h?.title ?? '');
    _targetController = TextEditingController(
      text: h != null ? h.targetCount.toString() : '1',
    );
    _unitController = TextEditingController(text: h?.unit ?? 'times');
    _selectedCategory = h?.category ?? 'Health';
    _selectedTimeOfDay = h?.timeOfDay ?? HabitTimeOfDay.anytime;
    _selectedColor = h?.colorValue ?? 0xFF10B981;
    _selectedIconCode =
        h?.iconCodePoint ?? Icons.check_circle_outline_rounded.codePoint;

    final unit = h?.repeatUnit ?? HabitRepeatUnit.days;
    _customUnit = unit;
    _repeatEvery = h?.repeatEvery ?? 1;
    _repeatWeekdays = (h?.repeatWeekdays ?? const <int>[]).toSet();
    _repeatDayOfMonth = h?.repeatDayOfMonth;
    _onceDate = unit == HabitRepeatUnit.once
        ? (h?.repeatStart ?? h?.createdAt)
        : null;
    _repeatPreset = _presetFor(unit, _repeatEvery, _repeatWeekdays);
  }

  static _RepeatPreset _presetFor(
    HabitRepeatUnit unit,
    int every,
    Set<int> weekdays,
  ) {
    if (unit == HabitRepeatUnit.once) return _RepeatPreset.custom;
    if (unit == HabitRepeatUnit.days && every == 1) {
      return _RepeatPreset.daily;
    }
    if (unit == HabitRepeatUnit.weeks && every == 1) {
      if (weekdays.length == 5 &&
          weekdays.containsAll(const [1, 2, 3, 4, 5])) {
        return _RepeatPreset.weekdays;
      }
      if (weekdays.length == 2 && weekdays.containsAll(const [6, 7])) {
        return _RepeatPreset.weekends;
      }
    }
    return _RepeatPreset.custom;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _selectPreset(_RepeatPreset preset) {
    setState(() {
      final wasPreset = _repeatPreset != _RepeatPreset.custom;
      _repeatPreset = preset;
      if (preset != _RepeatPreset.custom) return;

      if (wasPreset && _customUnit == HabitRepeatUnit.days) {
        _customUnit = HabitRepeatUnit.weeks;
      }
      if (_repeatEvery < 1) _repeatEvery = 1;
      if (_customUnit == HabitRepeatUnit.weeks && _repeatWeekdays.isEmpty) {
        _repeatWeekdays = {DateTime.now().weekday};
      }
      if (_customUnit == HabitRepeatUnit.months) {
        _repeatDayOfMonth ??= DateTime.now().day;
      }
      if (_customUnit == HabitRepeatUnit.once) {
        _onceDate ??= DateTime.now();
      }
    });
  }

  void _selectUnit(HabitRepeatUnit unit) {
    setState(() {
      _customUnit = unit;
      if (unit == HabitRepeatUnit.weeks && _repeatWeekdays.isEmpty) {
        _repeatWeekdays = {DateTime.now().weekday};
      }
      if (unit == HabitRepeatUnit.months) {
        _repeatDayOfMonth ??= DateTime.now().day;
      }
      if (unit == HabitRepeatUnit.once) {
        _onceDate ??= DateTime.now();
      }
    });
  }

  Future<void> _pickOnceDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _onceDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'One-time habit date',
    );
    if (picked != null) {
      setState(() => _onceDate = picked);
    }
  }

  void _saveHabit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final target = int.tryParse(_targetController.text.trim()) ?? 1;
    final unit = _unitController.text.trim().isEmpty
        ? 'times'
        : _unitController.text.trim();

    final schedule = _resolveSchedule();

    if (_isEditing) {
      final updated = widget.initialHabit!.copyWith(
        title: title,
        category: _selectedCategory,
        iconCodePoint: _selectedIconCode,
        colorValue: _selectedColor,
        targetCount: target,
        unit: unit,
        timeOfDay: _selectedTimeOfDay,
        repeatEvery: schedule.every,
        repeatUnit: schedule.unit,
        repeatWeekdays: schedule.weekdays,
        repeatDayOfMonth: schedule.dayOfMonth,
        clearRepeatDayOfMonth: schedule.dayOfMonth == null,
        repeatStart: schedule.start,
        clearRepeatStart: schedule.start == null,
      );
      ref.read(habitListProvider.notifier).updateHabit(updated);
    } else {
      final now = DateTime.now();
      final newHabit = Habit(
        id: now.millisecondsSinceEpoch.toString(),
        title: title,
        category: _selectedCategory,
        iconCodePoint: _selectedIconCode,
        colorValue: _selectedColor,
        targetCount: target,
        unit: unit,
        timeOfDay: _selectedTimeOfDay,
        createdAt: now,
        repeatEvery: schedule.every,
        repeatUnit: schedule.unit,
        repeatWeekdays: schedule.weekdays,
        repeatDayOfMonth: schedule.dayOfMonth,
        repeatStart: schedule.start,
      );
      ref.read(habitListProvider.notifier).addHabit(newHabit);
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  ({
    int every,
    HabitRepeatUnit unit,
    List<int> weekdays,
    int? dayOfMonth,
    DateTime? start,
  })
  _resolveSchedule() {
    switch (_repeatPreset) {
      case _RepeatPreset.daily:
        return (
          every: 1,
          unit: HabitRepeatUnit.days,
          weekdays: const <int>[],
          dayOfMonth: null,
          start: null,
        );
      case _RepeatPreset.weekdays:
        return (
          every: 1,
          unit: HabitRepeatUnit.weeks,
          weekdays: const [1, 2, 3, 4, 5],
          dayOfMonth: null,
          start: null,
        );
      case _RepeatPreset.weekends:
        return (
          every: 1,
          unit: HabitRepeatUnit.weeks,
          weekdays: const [6, 7],
          dayOfMonth: null,
          start: null,
        );
      case _RepeatPreset.custom:
        List<int> weekdays = const <int>[];
        if (_customUnit == HabitRepeatUnit.weeks) {
          weekdays = _repeatWeekdays.isEmpty
              ? <int>[DateTime.now().weekday]
              : _repeatWeekdays.toList();
          weekdays.sort();
        }
        return (
          every: _repeatEvery < 1 ? 1 : _repeatEvery,
          unit: _customUnit,
          weekdays: weekdays,
          dayOfMonth: _customUnit == HabitRepeatUnit.months
              ? (_repeatDayOfMonth ?? DateTime.now().day)
              : null,
          start: _customUnit == HabitRepeatUnit.once
              ? Habit.dateOnly(_onceDate ?? DateTime.now())
              : null,
        );
    }
  }

  String get _scheduleSummary {
    switch (_repeatPreset) {
      case _RepeatPreset.daily:
        return 'Every day';
      case _RepeatPreset.weekdays:
        return 'Monday to Friday';
      case _RepeatPreset.weekends:
        return 'Saturday and Sunday';
      case _RepeatPreset.custom:
        return Habit.describeSchedule(
          every: _repeatEvery,
          unit: _customUnit,
          weekdays: _repeatWeekdays.toList()..sort(),
          dayOfMonth: _repeatDayOfMonth,
          start: _onceDate,
        );
    }
  }

  void _deleteHabit() {
    if (!_isEditing) return;
    HapticFeedback.mediumImpact();
    ref.read(habitListProvider.notifier).deleteHabit(widget.initialHabit!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Edit Habit' : 'New Habit',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isEditing)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 22,
                          color: Color(0xFFEF4444),
                        ),
                        tooltip: 'Delete Habit',
                        onPressed: _deleteHabit,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Habit Title
            Text('Habit title', style: _labelStyle(isDark)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: _inputDecoration(
                hintText: 'e.g. Morning Walk, Read 20 pages',
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 18),

            // Category Chips
            Text('Category', style: _labelStyle(isDark)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['name'];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat['name'] as String;
                        _selectedColor = cat['color'] as int;
                        _selectedIconCode = (cat['icon'] as IconData).codePoint;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.06))
                            : (isDark ? const Color(0xFF222329) : const Color(0xFFF1F1ED)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? Colors.white : const Color(0xFF18181B))
                              : Colors.transparent,
                          width: 1.4,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 16,
                            color: isSelected
                                ? (isDark ? Colors.white : const Color(0xFF18181B))
                                : (isDark ? Colors.grey : Colors.black54),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['name'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? Colors.white : const Color(0xFF18181B))
                                  : (isDark ? Colors.grey : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            Text('Time of Day', style: _labelStyle(isDark)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTimeChip('Anytime', HabitTimeOfDay.anytime, isDark),
                  const SizedBox(width: 8),
                  _buildTimeChip('Morning', HabitTimeOfDay.morning, isDark),
                  const SizedBox(width: 8),
                  _buildTimeChip('Afternoon', HabitTimeOfDay.afternoon, isDark),
                  const SizedBox(width: 8),
                  _buildTimeChip('Evening', HabitTimeOfDay.evening, isDark),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Repeat schedule
            Text('Repeat', style: _labelStyle(isDark)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetChip('Daily', _RepeatPreset.daily, isDark),
                  const SizedBox(width: 8),
                  _buildPresetChip('Weekdays', _RepeatPreset.weekdays, isDark),
                  const SizedBox(width: 8),
                  _buildPresetChip('Weekends', _RepeatPreset.weekends, isDark),
                  const SizedBox(width: 8),
                  _buildPresetChip('Custom', _RepeatPreset.custom, isDark),
                ],
              ),
            ),
            if (_repeatPreset == _RepeatPreset.custom)
              _buildCustomSchedule(isDark),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.event_repeat_rounded,
                  size: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _scheduleSummary,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Target
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _repeatPreset == _RepeatPreset.daily
                            ? 'Daily Target'
                            : 'Target per check-in',
                        style: _labelStyle(isDark),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _targetController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(hintText: '1', isDark: isDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unit', style: _labelStyle(isDark)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _unitController,
                        decoration: _inputDecoration(hintText: 'times, mins, ml', isDark: isDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveHabit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _isEditing ? 'Save Changes' : 'Create Habit',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSchedule(bool isDark) {
    final fill = isDark ? const Color(0xFF1E1F24) : const Color(0xFFF6F6F2);
    final border = isDark ? const Color(0xFF2A2B32) : const Color(0xFFE5E5DF);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildUnitChip('Days', HabitRepeatUnit.days, isDark),
                const SizedBox(width: 8),
                _buildUnitChip('Weeks', HabitRepeatUnit.weeks, isDark),
                const SizedBox(width: 8),
                _buildUnitChip('Months', HabitRepeatUnit.months, isDark),
                const SizedBox(width: 8),
                _buildUnitChip('One date', HabitRepeatUnit.once, isDark),
              ],
            ),
          ),
          if (_customUnit != HabitRepeatUnit.once) ...[
            const SizedBox(height: 14),
            _buildIntervalRow(isDark),
          ],
          if (_customUnit == HabitRepeatUnit.weeks) ...[
            const SizedBox(height: 14),
            Text('On these days', style: _labelStyle(isDark)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  _buildWeekdayChip(day, isDark),
              ],
            ),
          ],
          if (_customUnit == HabitRepeatUnit.months) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text('On day', style: _labelStyle(isDark)),
                const Spacer(),
                _buildMonthDayPicker(isDark),
              ],
            ),
          ],
          if (_customUnit == HabitRepeatUnit.once) ...[
            const SizedBox(height: 14),
            Text('Date', style: _labelStyle(isDark)),
            const SizedBox(height: 8),
            _buildDateButton(isDark),
            if (_onceDate != null &&
                _onceDate!.isBefore(
                  Habit.dateOnly(DateTime.now()),
                )) ...[
              const SizedBox(height: 8),
              const Text(
                'This date has already passed. The habit will not appear.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildIntervalRow(bool isDark) {
    final label = switch (_customUnit) {
      HabitRepeatUnit.days => _repeatEvery == 1 ? 'day' : 'days',
      HabitRepeatUnit.weeks => _repeatEvery == 1 ? 'week' : 'weeks',
      HabitRepeatUnit.months => _repeatEvery == 1 ? 'month' : 'months',
      HabitRepeatUnit.once => '',
    };
    final max = switch (_customUnit) {
      HabitRepeatUnit.days => 365,
      HabitRepeatUnit.weeks => 52,
      HabitRepeatUnit.months => 24,
      HabitRepeatUnit.once => 1,
    };

    return Row(
      children: [
        Text('Every', style: _labelStyle(isDark)),
        const Spacer(),
        _buildStepButton(
          icon: Icons.remove_rounded,
          isDark: isDark,
          onTap: _repeatEvery > 1
              ? () => setState(() => _repeatEvery -= 1)
              : null,
        ),
        SizedBox(
          width: 38,
          child: Center(
            child: Text(
              '$_repeatEvery',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF18181B),
              ),
            ),
          ),
        ),
        _buildStepButton(
          icon: Icons.add_rounded,
          isDark: isDark,
          onTap: _repeatEvery < max
              ? () => setState(() => _repeatEvery += 1)
              : null,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.transparent
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isDark ? const Color(0xFF35363F) : const Color(0xFFE0E0D9),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null
              ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
              : (isDark ? Colors.white : const Color(0xFF18181B)),
        ),
      ),
    );
  }

  Widget _buildWeekdayChip(int day, bool isDark) {
    final isSelected = _repeatWeekdays.contains(day);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            // Keep at least one day selected so the schedule stays valid.
            if (_repeatWeekdays.length > 1) {
              _repeatWeekdays.remove(day);
            }
          } else {
            _repeatWeekdays.add(day);
          }
        });
      },
      child: Container(
        width: 38,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF18181B))
              : (isDark ? const Color(0xFF141517) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? const Color(0xFF35363F) : const Color(0xFFE0E0D9)),
          ),
        ),
        child: Text(
          Habit.weekdayLetter[day - 1],
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF141517) : Colors.white)
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthDayPicker(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141517) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF35363F) : const Color(0xFFE0E0D9),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _repeatDayOfMonth ?? DateTime.now().day,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF1E1F24) : Colors.white,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF18181B),
          ),
          items: [
            for (var day = 1; day <= 31; day++)
              DropdownMenuItem(
                value: day,
                child: Text(Habit.ordinal(day)),
              ),
            const DropdownMenuItem(value: -1, child: Text('Last day')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _repeatDayOfMonth = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildDateButton(bool isDark) {
    return GestureDetector(
      onTap: _pickOnceDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141517) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF35363F) : const Color(0xFFE0E0D9),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            const SizedBox(width: 10),
            Text(
              _onceDate == null
                  ? 'Choose a date'
                  : Habit.formatShortDate(_onceDate!),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF18181B),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, _RepeatPreset preset, bool isDark) {
    return _buildSelectChip(
      label: label,
      isSelected: _repeatPreset == preset,
      isDark: isDark,
      onTap: () => _selectPreset(preset),
    );
  }

  Widget _buildUnitChip(String label, HabitRepeatUnit unit, bool isDark) {
    return _buildSelectChip(
      label: label,
      isSelected: _customUnit == unit,
      isDark: isDark,
      onTap: () => _selectUnit(unit),
      compact: true,
    );
  }

  Widget _buildSelectChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 11 : 14,
          vertical: compact ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF18181B))
              : (isDark ? const Color(0xFF222329) : const Color(0xFFF1F1ED)),
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF141517) : Colors.white)
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip(String label, HabitTimeOfDay time, bool isDark) {
    final isSelected = _selectedTimeOfDay == time;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeOfDay = time;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? const Color(0xFF222329) : const Color(0xFFF1F1ED)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle(bool isDark) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
    );
  }

  InputDecoration _inputDecoration({required String hintText, required bool isDark}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1F24) : const Color(0xFFF6F6F2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A2B32) : const Color(0xFFE5E5DF),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A2B32) : const Color(0xFFE5E5DF),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white : const Color(0xFF18181B),
          width: 1.5,
        ),
      ),
    );
  }
}
