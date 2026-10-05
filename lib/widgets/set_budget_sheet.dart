import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/services/ledger_provider.dart';

class SetBudgetSheet extends ConsumerStatefulWidget {
  const SetBudgetSheet({super.key});

  @override
  ConsumerState<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends ConsumerState<SetBudgetSheet> {
  late double _monthlyLimit;
  late double _dailyLimit;

  @override
  void initState() {
    super.initState();
    final state = ref.read(ledgerProvider);
    _monthlyLimit = state.monthlyBudgetLimit;
    _dailyLimit = state.dailyBudgetLimit;
  }

  void _save() {
    HapticFeedback.mediumImpact();
    ref.read(ledgerProvider.notifier).setMonthlyBudget(_monthlyLimit);
    ref.read(ledgerProvider.notifier).setDailyBudget(_dailyLimit);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Budgets updated: GH₵${_monthlyLimit.toStringAsFixed(0)}/mo · GH₵${_dailyLimit.toStringAsFixed(0)}/day',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16171B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Adjust Budget Ceilings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set your monthly spending ceiling and daily target pace.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 22),

          // Monthly Ceiling Control Box
          Text(
            'MONTHLY BUDGET CEILING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1F26) : const Color(0xFFF7F7F4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _monthlyLimit > 100
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() => _monthlyLimit = (_monthlyLimit - 100).clamp(100, 20000));
                            }
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 24),
                    ),
                    IconButton(
                      onPressed: _monthlyLimit > 50
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() => _monthlyLimit = (_monthlyLimit - 50).clamp(50, 20000));
                            }
                          : null,
                      icon: const Icon(Icons.remove_rounded, size: 20),
                    ),
                  ],
                ),
                Text(
                  'GH₵${_monthlyLimit.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _monthlyLimit = (_monthlyLimit + 50).clamp(50, 20000));
                      },
                      icon: const Icon(Icons.add_rounded, size: 20),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _monthlyLimit = (_monthlyLimit + 100).clamp(50, 20000));
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Daily Target Cap Control Box
          Text(
            'DAILY SPENDING CAP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1F26) : const Color(0xFFF7F7F4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _dailyLimit > 10
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() => _dailyLimit = (_dailyLimit - 10).clamp(5, 1000));
                            }
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 24),
                    ),
                    IconButton(
                      onPressed: _dailyLimit > 5
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() => _dailyLimit = (_dailyLimit - 5).clamp(5, 1000));
                            }
                          : null,
                      icon: const Icon(Icons.remove_rounded, size: 20),
                    ),
                  ],
                ),
                Text(
                  'GH₵${_dailyLimit.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _dailyLimit = (_dailyLimit + 5).clamp(5, 1000));
                      },
                      icon: const Icon(Icons.add_rounded, size: 20),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _dailyLimit = (_dailyLimit + 10).clamp(5, 1000));
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : const Color(0xFF18181B),
                foregroundColor: isDark ? const Color(0xFF141517) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Save Budgets',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
