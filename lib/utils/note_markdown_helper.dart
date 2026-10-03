import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Formatter that automatically continues numbered lists (1. -> 2.)
/// and checklists (- [ ] -> - [ ]) upon pressing Enter.
/// Pressing Enter on an empty list item cleans up the prefix to exit the list.
class NoteListInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only intercept when user pressed enter (text grew and ends with or contains \n at cursor)
    if (newValue.text.length > oldValue.text.length &&
        newValue.selection.isCollapsed &&
        newValue.selection.start > 0) {
      final cursorPos = newValue.selection.start;
      final charBeforeCursor = newValue.text[cursorPos - 1];

      if (charBeforeCursor == '\n') {
        final textBeforeCursor = newValue.text.substring(0, cursorPos - 1);
        final lines = textBeforeCursor.split('\n');
        if (lines.isNotEmpty) {
          final prevLine = lines.last;

          // Case 1: Empty checklist item -> Exit checklist
          if (prevLine == '- [ ] ' || prevLine == '- [x] ' || prevLine == '- [X] ') {
            final startOfPrevLine = cursorPos - 1 - prevLine.length;
            final newText = newValue.text.replaceRange(startOfPrevLine, cursorPos, '\n');
            return TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: startOfPrevLine + 1),
            );
          }

          // Case 2: Active checklist item -> Continue checklist
          if (prevLine.startsWith('- [ ] ') || prevLine.startsWith('- [x] ') || prevLine.startsWith('- [X] ')) {
            const insert = '- [ ] ';
            final newText = newValue.text.replaceRange(cursorPos, cursorPos, insert);
            return TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: cursorPos + insert.length),
            );
          }

          // Case 3: Empty numbered item -> Exit numbered list
          final emptyNumMatch = RegExp(r'^(\d+)\.\s$').firstMatch(prevLine);
          if (emptyNumMatch != null) {
            final startOfPrevLine = cursorPos - 1 - prevLine.length;
            final newText = newValue.text.replaceRange(startOfPrevLine, cursorPos, '\n');
            return TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: startOfPrevLine + 1),
            );
          }

          // Case 4: Active numbered item -> Increment number (e.g. 1. -> 2.)
          final numMatch = RegExp(r'^(\d+)\.\s').firstMatch(prevLine);
          if (numMatch != null) {
            final currentNum = int.tryParse(numMatch.group(1)!) ?? 1;
            final nextNumPrefix = '${currentNum + 1}. ';
            final newText = newValue.text.replaceRange(cursorPos, cursorPos, nextNumPrefix);
            return TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: cursorPos + nextNumPrefix.length),
            );
          }
        }
      }
    }
    return newValue;
  }
}

/// Custom TextEditingController that live-highlights bold text, lists, and checklists
class NoteEditingController extends TextEditingController {
  NoteEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final defaultStyle = style ?? DefaultTextStyle.of(context).style;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (text.isEmpty) {
      return TextSpan(text: '', style: defaultStyle);
    }

    final spans = <InlineSpan>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLastLine = i == lines.length - 1;
      final suffix = isLastLine ? '' : '\n';

      // Checklist item: Completed
      if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
        spans.add(
          TextSpan(
            text: line.substring(0, 6),
            style: defaultStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
            ),
          ),
        );
        spans.add(
          TextSpan(
            text: '${line.substring(6)}$suffix',
            style: defaultStyle.copyWith(
              decoration: TextDecoration.lineThrough,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ),
        );
        continue;
      }

      // Checklist item: Uncompleted
      if (line.startsWith('- [ ] ')) {
        spans.add(
          TextSpan(
            text: line.substring(0, 6),
            style: defaultStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        );
        _parseInlineBold(line.substring(6), defaultStyle, spans, suffix: suffix);
        continue;
      }

      // Numbered list item: 1.
      final numMatch = RegExp(r'^(\d+\.\s)').firstMatch(line);
      if (numMatch != null) {
        final prefix = numMatch.group(0)!;
        spans.add(
          TextSpan(
            text: prefix,
            style: defaultStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
            ),
          ),
        );
        _parseInlineBold(line.substring(prefix.length), defaultStyle, spans, suffix: suffix);
        continue;
      }

      // General line: parse inline bold
      _parseInlineBold(line, defaultStyle, spans, suffix: suffix);
    }

    return TextSpan(children: spans, style: defaultStyle);
  }

  void _parseInlineBold(
    String lineText,
    TextStyle baseStyle,
    List<InlineSpan> spans, {
    String suffix = '',
  }) {
    final boldRegex = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final match in boldRegex.allMatches(lineText)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: lineText.substring(lastIndex, match.start), style: baseStyle));
      }
      // Inner bold content
      spans.add(
        TextSpan(
          text: match.group(0), // Keeps asterisks typed, but highlights them bold
          style: baseStyle.copyWith(fontWeight: FontWeight.w800),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < lineText.length) {
      spans.add(TextSpan(text: '${lineText.substring(lastIndex)}$suffix', style: baseStyle));
    } else {
      if (suffix.isNotEmpty) {
        spans.add(TextSpan(text: suffix, style: baseStyle));
      }
    }
  }
}

/// Helper actions for the formatting accessory bar
class NoteFormattingHelper {
  /// Toggles bold formatting (**word**) on selected text or inserts empty bold tag
  static void toggleBold(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid) {
      controller.text = '$text**bold**';
      controller.selection = TextSelection(
        baseOffset: text.length + 2,
        extentOffset: text.length + 6,
      );
      return;
    }

    if (selection.isCollapsed) {
      const insert = '****';
      final newText = text.replaceRange(selection.start, selection.end, insert);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + 2),
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      if (selectedText.startsWith('**') && selectedText.endsWith('**') && selectedText.length >= 4) {
        // Strip bold
        final unwrapped = selectedText.substring(2, selectedText.length - 2);
        final newText = text.replaceRange(selection.start, selection.end, unwrapped);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: selection.start,
            extentOffset: selection.start + unwrapped.length,
          ),
        );
      } else {
        // Wrap in bold
        final wrapped = '**$selectedText**';
        final newText = text.replaceRange(selection.start, selection.end, wrapped);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: selection.start,
            extentOffset: selection.start + wrapped.length,
          ),
        );
      }
    }
  }

  /// Toggles or inserts a numbered list item (1. ) on the current line
  static void toggleNumberedList(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : text.length;

    // Find line bounds
    final lineStart = text.lastIndexOf('\n', start > 0 ? start - 1 : 0);
    final actualLineStart = lineStart == -1 ? 0 : lineStart + 1;

    final currentLine = text.substring(actualLineStart);
    final numMatch = RegExp(r'^(\d+)\.\s').firstMatch(currentLine);

    if (numMatch != null) {
      // Remove numbering
      final len = numMatch.group(0)!.length;
      final newText = text.replaceRange(actualLineStart, actualLineStart + len, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: (start - len).clamp(0, newText.length)),
      );
    } else {
      // Determine list number
      int nextNum = 1;
      if (actualLineStart > 0) {
        final prevLineStart = text.lastIndexOf('\n', actualLineStart - 2);
        final prevActualStart = prevLineStart == -1 ? 0 : prevLineStart + 1;
        final prevLine = text.substring(prevActualStart, actualLineStart - 1);
        final prevMatch = RegExp(r'^(\d+)\.\s').firstMatch(prevLine);
        if (prevMatch != null) {
          nextNum = (int.tryParse(prevMatch.group(1)!) ?? 0) + 1;
        }
      }
      final prefix = '$nextNum. ';
      final newText = text.replaceRange(actualLineStart, actualLineStart, prefix);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + prefix.length),
      );
    }
  }

  /// Toggles or inserts a checklist item (- [ ] ) on the current line
  static void toggleChecklist(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : text.length;

    // Find line bounds
    final lineStart = text.lastIndexOf('\n', start > 0 ? start - 1 : 0);
    final actualLineStart = lineStart == -1 ? 0 : lineStart + 1;

    final currentLine = text.substring(actualLineStart);
    if (currentLine.startsWith('- [ ] ') || currentLine.startsWith('- [x] ') || currentLine.startsWith('- [X] ')) {
      // Remove checklist prefix
      const len = 6;
      final newText = text.replaceRange(actualLineStart, actualLineStart + len, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: (start - len).clamp(0, newText.length)),
      );
    } else {
      // Insert checklist prefix
      const prefix = '- [ ] ';
      final newText = text.replaceRange(actualLineStart, actualLineStart, prefix);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + prefix.length),
      );
    }
  }

  /// Parses note content for card preview: removes raw asterisks, renders clean checkmarks
  static List<InlineSpan> buildPreviewSpans(String rawText, TextStyle baseStyle, bool isDark) {
    if (rawText.isEmpty) return [];

    final spans = <InlineSpan>[];
    final lines = rawText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLastLine = i == lines.length - 1;
      final suffix = isLastLine ? '' : '\n';

      if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
        spans.add(
          TextSpan(
            text: '☑ ',
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
            ),
          ),
        );
        spans.add(
          TextSpan(
            text: '${line.substring(6)}$suffix',
            style: baseStyle.copyWith(
              decoration: TextDecoration.lineThrough,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ),
        );
        continue;
      }

      if (line.startsWith('- [ ] ')) {
        spans.add(
          TextSpan(
            text: '☐ ',
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        );
        _parsePreviewBold(line.substring(6), baseStyle, spans, suffix: suffix);
        continue;
      }

      _parsePreviewBold(line, baseStyle, spans, suffix: suffix);
    }

    return spans;
  }

  static void _parsePreviewBold(
    String lineText,
    TextStyle baseStyle,
    List<InlineSpan> spans, {
    String suffix = '',
  }) {
    final boldRegex = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final match in boldRegex.allMatches(lineText)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: lineText.substring(lastIndex, match.start), style: baseStyle));
      }
      spans.add(
        TextSpan(
          text: match.group(1), // Clean text without asterisks
          style: baseStyle.copyWith(fontWeight: FontWeight.w800),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < lineText.length) {
      spans.add(TextSpan(text: '${lineText.substring(lastIndex)}$suffix', style: baseStyle));
    } else if (suffix.isNotEmpty) {
      spans.add(TextSpan(text: suffix, style: baseStyle));
    }
  }
}
