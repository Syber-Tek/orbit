import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/note.dart';
import 'package:orbit/services/note_provider.dart';
import 'package:orbit/utils/note_markdown_helper.dart';

class NoteEditorSheet extends ConsumerStatefulWidget {
  final Note? initialNote;

  const NoteEditorSheet({
    super.key,
    this.initialNote,
  });

  @override
  ConsumerState<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<NoteEditorSheet> {
  late final TextEditingController _titleController;
  late final NoteEditingController _contentController;
  late int _selectedColor;
  DateTime? _reminderAt;

  final List<int> _availableColors = const [
    0xFFE9D8FD, // Lilac
    0xFFDCEBFE, // Sky Blue
    0xFFD1FAE5, // Mint
    0xFFFFEDD5, // Peach
    0xFFFCE7F3, // Rose
    0xFFF3F4F6, // Slate / Warm Gray
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialNote?.title ?? '');
    _contentController = NoteEditingController(text: widget.initialNote?.content ?? '');
    _selectedColor = widget.initialNote?.colorValue ?? _availableColors.first;
    _reminderAt = widget.initialNote?.reminderAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickReminder() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final initial = _reminderAt ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _reminderAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _clearReminder() {
    HapticFeedback.lightImpact();
    setState(() {
      _reminderAt = null;
    });
  }

  String _formatReminder(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day;

    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute $period';

    if (isToday) return 'Today, $timeStr';
    if (isTomorrow) return 'Tomorrow, $timeStr';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, $timeStr';
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) return;

    if (widget.initialNote != null) {
      final updated = widget.initialNote!.copyWith(
        title: title.isEmpty ? 'Untitled Note' : title,
        content: content,
        colorValue: _selectedColor,
        updatedAt: DateTime.now(),
        reminderAt: _reminderAt,
        clearReminder: _reminderAt == null,
      );
      ref.read(noteListProvider.notifier).updateNote(updated);
    } else {
      final newNote = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.isEmpty ? 'Untitled Note' : title,
        content: content,
        colorValue: _selectedColor,
        updatedAt: DateTime.now(),
        reminderAt: _reminderAt,
      );
      ref.read(noteListProvider.notifier).addNote(newNote);
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _deleteNote() {
    if (widget.initialNote != null) {
      ref.read(noteListProvider.notifier).deleteNote(widget.initialNote!.id);
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 16, 22, bottomInset + 24),
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
                  widget.initialNote == null ? 'Quick Note' : 'Edit Note',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    if (widget.initialNote != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                        onPressed: _deleteNote,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Color Selector Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _availableColors.map((colorVal) {
                  final isSelected = _selectedColor == colorVal;
                  final color = Color(colorVal);

                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorVal),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.onSurface : Colors.black12,
                          width: isSelected ? 2.2 : 1,
                        ),
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(Icons.check_rounded, size: 14, color: Colors.black87),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Title Field
            TextField(
              controller: _titleController,
              autofocus: widget.initialNote == null,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Note Title...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 10),

            // Content Field
            TextField(
              controller: _contentController,
              maxLines: 6,
              minLines: 4,
              inputFormatters: [NoteListInputFormatter()],
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.45,
              ),
              decoration: InputDecoration(
                hintText: 'Start typing thoughts, tasks, or lists...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),

            // Formatting & Reminder Accessory Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18191E) : const Color(0xFFF4F4F1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                ),
              ),
              child: Row(
                children: [
                  // Bold (B)
                  _buildFormatButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      NoteFormattingHelper.toggleBold(_contentController);
                    },
                    tooltip: 'Bold (**bold**)',
                    child: const Text(
                      'B',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Numbered List (1.)
                  _buildFormatButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      NoteFormattingHelper.toggleNumberedList(_contentController);
                    },
                    tooltip: 'Numbered List (1.)',
                    child: const Text(
                      '1.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Checklist (☑)
                  _buildFormatButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      NoteFormattingHelper.toggleChecklist(_contentController);
                    },
                    tooltip: 'Checklist (- [ ])',
                    child: const Icon(
                      Icons.check_box_outlined,
                      size: 19,
                    ),
                  ),

                  const SizedBox(width: 6),
                  Container(
                    width: 1,
                    height: 20,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  const SizedBox(width: 6),

                  // Reminder Badge or Button
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _reminderAt == null
                          ? InkWell(
                              onTap: _pickReminder,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      IconlyLight.notification,
                                      size: 15,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Reminder',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.22 : 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: _pickReminder,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          IconlyLight.notification,
                                          size: 14,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _formatReminder(_reminderAt!),
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF8B5CF6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  GestureDetector(
                                    onTap: _clearReminder,
                                    child: Padding(
                                      padding: const EdgeInsets.all(3.0),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Save CTA
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.initialNote == null ? 'Save Note' : 'Update Note',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton({
    required VoidCallback onTap,
    required Widget child,
    required String tooltip,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
