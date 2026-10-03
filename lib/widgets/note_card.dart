import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbit/models/note.dart';
import 'package:orbit/widgets/note_editor_sheet.dart';

class NoteCard extends StatelessWidget {
  final Note note;

  const NoteCard({
    super.key,
    required this.note,
  });

  void _openNote(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NoteEditorSheet(initialNote: note),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Color(note.colorValue);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openNote(context),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? cardColor.withValues(alpha: 0.12)
                : cardColor.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? cardColor.withValues(alpha: 0.28)
                  : cardColor.withValues(alpha: 0.65),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFEDEDEA) : const Color(0xFF18181B),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (note.content.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          note.content,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            color: isDark ? Colors.grey.shade400 : Colors.black87.withValues(alpha: 0.75),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Footer: Time and Diagonal Arrow (↗)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(note.updatedAt),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        size: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
