import 'package:flutter/material.dart';

class ProgressDial extends StatelessWidget {
  const ProgressDial({
    super.key,
    required this.value,
    this.size = 76, // dial width & height
    this.strokeWidth, // null = size * 0.08
    this.contentFontSize, // null = size * 0.21. Set this to resize the inside text
    this.contentPadding = 0, // extra space between ring and content
    this.fitContent = false, // true = shrink content to stay inside ring
    this.trackColor,
    this.progressColor,
    this.textColor,
    this.child, // custom content (icon, column, etc.)
  });

  final double value;
  final double size;
  final double? strokeWidth;
  final double? contentFontSize;
  final double contentPadding;
  final bool fitContent;
  final Color? trackColor;
  final Color? progressColor;
  final Color? textColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stroke = strokeWidth ?? size * 0.08;

    final track = trackColor ??
        (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF));
    final progress =
        progressColor ?? (isDark ? Colors.white : const Color(0xFF18181B));

    Widget content = child ??
        Text(
          '${(value.clamp(0.0, 1.0) * 100).toInt()}%',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: contentFontSize ?? size * 0.21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: textColor ?? progress,
          ),
        );

    if (fitContent) {
      content = FittedBox(fit: BoxFit.scaleDown, child: content);
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
              backgroundColor: track,
              valueColor: AlwaysStoppedAnimation<Color>(progress),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(stroke + contentPadding),
            child: Center(child: content),
          ),
        ],
      ),
    );
  }
}
