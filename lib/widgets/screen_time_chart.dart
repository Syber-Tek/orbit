import 'package:flutter/material.dart';

class ScreenTimeChart extends StatelessWidget {
  final List<int> hourlyUsage;

  const ScreenTimeChart({
    super.key,
    required this.hourlyUsage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final labels = ['6 AM', '9 AM', '12 PM', '3 PM', '6 PM', '9 PM'];
    final maxUsage = hourlyUsage.isEmpty
        ? 60
        : hourlyUsage.reduce((a, b) => a > b ? a : b).clamp(30, 120);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVITY DISTRIBUTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              Text(
                'Peak: 12 PM (45m)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart Row
          SizedBox(
            height: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(hourlyUsage.length, (index) {
                final usage = hourlyUsage[index];
                final factor = (usage / maxUsage).clamp(0.08, 1.0);
                final isPeak = usage == maxUsage && usage > 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (usage > 0)
                          Text(
                            '${usage}m',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
                              color: isPeak
                                  ? const Color(0xFF8B5CF6)
                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: factor,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isPeak
                                      ? const Color(0xFF8B5CF6)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.15)
                                          : const Color(0xFF18181B).withValues(alpha: 0.12)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[index],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
