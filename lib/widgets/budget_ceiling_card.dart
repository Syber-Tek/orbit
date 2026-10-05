import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/ledger.dart';
import 'package:orbit/widgets/progress_dial.dart';

class BudgetCeilingCard extends StatelessWidget {
  final LedgerState state;
  final VoidCallback onEditBudget;

  const BudgetCeilingCard({
    super.key,
    required this.state,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color dialColor;
    if (state.isOverMonthlyBudget) {
      dialColor = const Color(0xFFEF4444);
    } else if (state.monthlyProgress >= 0.85) {
      dialColor = const Color(0xFFFFB800);
    } else {
      dialColor = isDark ? Colors.white : const Color(0xFF18181B);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.isOverMonthlyBudget
              ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.4 : 0.3)
              : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title & Edit Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MONTHLY BUDGET CEILING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onEditBudget();
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        IconlyLight.edit,
                        size: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Adjust',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Stats Row with ProgressDial
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${state.totalExpensesThisMonth.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: -0.8,
                        color: state.isOverMonthlyBudget ? const Color(0xFFEF4444) : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of \$${state.monthlyBudgetLimit.toStringAsFixed(0)} monthly limit',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Remaining Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.isOverMonthlyBudget
                            ? 'Over by \$${(state.totalExpensesThisMonth - state.monthlyBudgetLimit).toStringAsFixed(2)}'
                            : '\$${state.monthlyRemaining.toStringAsFixed(2)} available',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: state.isOverMonthlyBudget
                              ? const Color(0xFFEF4444)
                              : (isDark ? Colors.white : const Color(0xFF18181B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Circular Progress Dial
              ProgressDial(
                value: state.monthlyProgress,
                size: 76,
                progressColor: dialColor,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Divider
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
          ),
          const SizedBox(height: 12),

          // Bottom Daily Pace Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    IconlyLight.calendar,
                    size: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Today: \$${state.totalSpentToday.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: state.isOverDailyBudget
                          ? const Color(0xFFEF4444)
                          : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
              Text(
                'Daily Cap: \$${state.dailyBudgetLimit.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
