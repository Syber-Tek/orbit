import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/services/ledger_provider.dart';
import 'package:orbit/utils/app_haptics.dart';

class SetBudgetSheet extends ConsumerStatefulWidget {
  const SetBudgetSheet({super.key});

  @override
  ConsumerState<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends ConsumerState<SetBudgetSheet> {
  double _monthlyLimit = 0;
  double _dailyLimit = 0;

  final TextEditingController _monthlyController = TextEditingController();
  final TextEditingController _dailyController = TextEditingController();

  int _monthlyStep = 1;
  int _dailyStep = 1;
  bool _initialized = false;

  static const List<int> _monthlyStepOptions = [1, 5, 10, 50, 100, 500];
  static const List<int> _dailyStepOptions = [1, 5, 10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    _initFromState();
  }

  void _initFromState() {
    final state = ref.read(ledgerProvider);
    _monthlyLimit = state.monthlyBudgetLimit;
    _dailyLimit = state.dailyBudgetLimit;

    _monthlyController.text = _formatAmount(_monthlyLimit);
    _dailyController.text = _formatAmount(_dailyLimit);
    _initialized = true;
  }

  @override
  void dispose() {
    _monthlyController.dispose();
    _dailyController.dispose();
    super.dispose();
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  void _adjustMonthly(int delta) {
    AppHaptics.selectionClick();
    final current = double.tryParse(_monthlyController.text.trim()) ?? _monthlyLimit;
    final updated = (current + delta).clamp(0.0, 1000000.0);
    setState(() {
      _monthlyLimit = updated;
      final text = _formatAmount(updated);
      _monthlyController.text = text;
      _monthlyController.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    });
  }

  void _adjustDaily(int delta) {
    AppHaptics.selectionClick();
    final current = double.tryParse(_dailyController.text.trim()) ?? _dailyLimit;
    final updated = (current + delta).clamp(0.0, 500000.0);
    setState(() {
      _dailyLimit = updated;
      final text = _formatAmount(updated);
      _dailyController.text = text;
      _dailyController.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    });
  }

  void _save() {
    AppHaptics.mediumImpact();

    final parsedMonthly = double.tryParse(_monthlyController.text.trim()) ?? _monthlyLimit;
    final parsedDaily = double.tryParse(_dailyController.text.trim()) ?? _dailyLimit;

    _monthlyLimit = parsedMonthly.clamp(0.0, 1000000.0);
    _dailyLimit = parsedDaily.clamp(0.0, 500000.0);

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
    if (!_initialized) {
      _initFromState();
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16171B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1F26) : const Color(0xFFF7F7F4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: _monthlyLimit > 0
                                ? () => _adjustMonthly(-_monthlyStep)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                            color: isDark ? Colors.white70 : Colors.black87,
                            disabledColor: isDark ? Colors.white24 : Colors.black26,
                            visualDensity: VisualDensity.compact,
                          ),
                          Expanded(
                            child: Container(
                              height: 48,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF16171B) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2E303A) : const Color(0xFFD6D6CF),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'GH₵',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _monthlyController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF141517),
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: '0',
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                      ],
                                      onChanged: (val) {
                                        final parsed = double.tryParse(val.trim());
                                        if (parsed != null && parsed >= 0) {
                                          _monthlyLimit = parsed;
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _adjustMonthly(_monthlyStep),
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                            color: isDark ? Colors.white70 : Colors.black87,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Step:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  for (final step in _monthlyStepOptions) ...[
                                    _buildStepSelectorChip(
                                      step: step,
                                      isSelected: _monthlyStep == step,
                                      onSelected: () {
                                        AppHaptics.selectionClick();
                                        setState(() => _monthlyStep = step);
                                      },
                                      isDark: isDark,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                ],
                              ),
                            ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1F26) : const Color(0xFFF7F7F4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: _dailyLimit > 0
                                ? () => _adjustDaily(-_dailyStep)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                            color: isDark ? Colors.white70 : Colors.black87,
                            disabledColor: isDark ? Colors.white24 : Colors.black26,
                            visualDensity: VisualDensity.compact,
                          ),
                          Expanded(
                            child: Container(
                              height: 48,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF16171B) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2E303A) : const Color(0xFFD6D6CF),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'GH₵',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _dailyController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF141517),
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: '0',
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                      ],
                                      onChanged: (val) {
                                        final parsed = double.tryParse(val.trim());
                                        if (parsed != null && parsed >= 0) {
                                          _dailyLimit = parsed;
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _adjustDaily(_dailyStep),
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                            color: isDark ? Colors.white70 : Colors.black87,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Step:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  for (final step in _dailyStepOptions) ...[
                                    _buildStepSelectorChip(
                                      step: step,
                                      isSelected: _dailyStep == step,
                                      onSelected: () {
                                        AppHaptics.selectionClick();
                                        setState(() => _dailyStep = step);
                                      },
                                      isDark: isDark,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                ],
                              ),
                            ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildStepSelectorChip({
    required int step,
    required bool isSelected,
    required VoidCallback onSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF18181B))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF18181B))
                : (isDark ? const Color(0xFF2E303A) : const Color(0xFFE5E5DF)),
            width: 1.0,
          ),
        ),
        child: Text(
          '±$step',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (isDark ? const Color(0xFF141517) : Colors.white)
                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}

