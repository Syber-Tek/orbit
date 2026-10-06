import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/ledger.dart';
import 'package:orbit/services/ledger_provider.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  ExpenseCategory _category = ExpenseCategory.food;
  final DateTime _selectedDate = DateTime.now();

  final List<double> _presetAmounts = [5.0, 10.0, 25.0, 50.0, 100.0];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.replaceAll('GH₵', '').replaceAll('\$', '').trim();
    final amount = double.tryParse(amountText);

    if (title.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description/title'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final newTx = TransactionItem(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      amount: amount,
      type: _type,
      category: _type == TransactionType.income ? ExpenseCategory.income : _category,
      dateTime: _selectedDate,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    ref.read(ledgerProvider.notifier).addTransaction(newTx);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newTx.type == TransactionType.expense ? 'Expense' : 'Income'} of ${newTx.formattedAmount} logged'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = ExpenseCategory.values.where((c) => c != ExpenseCategory.income).toList();

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
      child: SingleChildScrollView(
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

            // Sheet Title & Type Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Log Transaction',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.4,
                  ),
                ),
                // Expense vs Income Pill Toggle
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildTypeButton('Expense', TransactionType.expense, isDark),
                      _buildTypeButton('Income', TransactionType.income, isDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount Input Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1F26) : const Color(0xFFF7F7F4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'GH₵',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Quick Preset Amount Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _presetAmounts.map((preset) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _amountController.text = preset.toStringAsFixed(0);
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+GH₵${preset.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Description / Title Field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title / Description',
                hintText: _type == TransactionType.expense ? 'e.g. Groceries, Dinner, Transit' : 'e.g. Salary, Freelance, Bonus',
                prefixIcon: const Icon(IconlyLight.document, size: 20),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Category Selection (only for expenses)
            if (_type == TransactionType.expense) ...[
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = _category == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          cat.icon,
                          size: 15,
                          color: isSelected
                              ? (isDark ? const Color(0xFF141517) : Colors.white)
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                        label: Text(cat.label),
                        selected: isSelected,
                        onSelected: (val) {
                          HapticFeedback.selectionClick();
                          if (val) setState(() => _category = cat);
                        },
                        selectedColor: isDark ? Colors.white : const Color(0xFF18181B),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? (isDark ? const Color(0xFF141517) : Colors.white)
                              : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
                          ),
                        ),
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Note (Optional)
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'Add extra details or memo...',
                prefixIcon: const Icon(IconlyLight.editSquare, size: 20),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
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
                child: Text(
                  _type == TransactionType.expense ? 'Log Expense' : 'Log Income',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, TransactionType type, bool isDark) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _type = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF18181B))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? (isDark ? const Color(0xFF141517) : Colors.white)
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}
