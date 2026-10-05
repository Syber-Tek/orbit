import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/habit.dart';
import 'package:orbit/services/habit_provider.dart';

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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _saveHabit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final target = int.tryParse(_targetController.text.trim()) ?? 1;
    final unit = _unitController.text.trim().isEmpty ? 'times' : _unitController.text.trim();

    if (_isEditing) {
      final updated = widget.initialHabit!.copyWith(
        title: title,
        category: _selectedCategory,
        iconCodePoint: _selectedIconCode,
        colorValue: _selectedColor,
        targetCount: target,
        unit: unit,
        timeOfDay: _selectedTimeOfDay,
      );
      ref.read(habitListProvider.notifier).updateHabit(updated);
    } else {
      final newHabit = Habit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: _selectedCategory,
        iconCodePoint: _selectedIconCode,
        colorValue: _selectedColor,
        targetCount: target,
        unit: unit,
        timeOfDay: _selectedTimeOfDay,
        createdAt: DateTime.now(),
      );
      ref.read(habitListProvider.notifier).addHabit(newHabit);
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
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
            Text('HABIT TITLE', style: _labelStyle(isDark)),
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

            // Daily Target
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Target', style: _labelStyle(isDark)),
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
