import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/note.dart';
import 'package:orbit/services/note_provider.dart';

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
  late final TextEditingController _contentController;
  late int _selectedColor;

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
    _contentController = TextEditingController(text: widget.initialNote?.content ?? '');
    _selectedColor = widget.initialNote?.colorValue ?? _availableColors.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
      );
      ref.read(noteListProvider.notifier).updateNote(updated);
    } else {
      final newNote = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.isEmpty ? 'Untitled Note' : title,
        content: content,
        colorValue: _selectedColor,
        updatedAt: DateTime.now(),
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
              maxLines: 5,
              minLines: 3,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.45,
              ),
              decoration: InputDecoration(
                hintText: 'Start typing thoughts, tasks, or reminders...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
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
}
