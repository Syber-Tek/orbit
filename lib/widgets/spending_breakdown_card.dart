import 'package:flutter/material.dart';
import 'package:orbit/models/ledger.dart';

class SpendingBreakdownCard extends StatelessWidget {
  final Map<ExpenseCategory, double> breakdown;
  final double totalExpenses;

  const SpendingBreakdownCard({
    super.key,
    required this.breakdown,
    required this.totalExpenses,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (breakdown.isEmpty || totalExpenses <= 0) {
      return const SizedBox.shrink();
    }

    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                'Spending by Category',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              Text(
                '${sortedEntries.length} categories',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stacked Segmented Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 7,
              child: Row(
                children: sortedEntries.map((e) {
                  final pct = e.value / totalExpenses;
                  // Opacity variation to differentiate segments in monochrome
                  final index = sortedEntries.indexOf(e);
                  final opacity = (1.0 - (index * 0.18)).clamp(0.2, 1.0);

                  return Expanded(
                    flex: (pct * 100).toInt().clamp(1, 100),
                    child: Container(
                      color: isDark
                          ? Colors.white.withValues(alpha: opacity)
                          : const Color(0xFF18181B).withValues(alpha: opacity),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Category List Rows (top 4 or all)
          ...sortedEntries.take(4).map((entry) {
            final category = entry.key;
            final amount = entry.value;
            final percentage = (amount / totalExpenses * 100).round();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        category.icon,
                        size: 16,
                        color: isDark ? Colors.white : const Color(0xFF18181B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$percentage% of total',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'GH₵${amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
