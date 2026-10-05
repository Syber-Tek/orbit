import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/ledger.dart';
import 'package:orbit/services/ledger_provider.dart';
import 'package:orbit/widgets/add_transaction_sheet.dart';
import 'package:orbit/widgets/budget_ceiling_card.dart';
import 'package:orbit/widgets/set_budget_sheet.dart';
import 'package:orbit/widgets/spending_breakdown_card.dart';
import 'package:orbit/widgets/transaction_tile.dart';

class LedgerScreen extends ConsumerWidget {
  final VoidCallback? onSettingsTap;

  const LedgerScreen({
    super.key,
    this.onSettingsTap,
  });

  void _openAddTransaction(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionSheet(),
    );
  }

  void _openSetBudget(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SetBudgetSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final ledgerState = ref.watch(ledgerProvider);
    final transactions = ledgerState.filteredTransactions;

    return CustomScrollView(
      key: const PageStorageKey('ledger_scroll'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Monthly Budget Ceiling Hero Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: BudgetCeilingCard(
              state: ledgerState,
              onEditBudget: () => _openSetBudget(context),
            ),
          ),
        ),

        // Urgent Daily or Monthly Budget Warning Banner
        if (ledgerState.isOverDailyBudget || ledgerState.isOverMonthlyBudget || ledgerState.isNearDailyLimit)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: (ledgerState.isOverDailyBudget || ledgerState.isOverMonthlyBudget)
                      ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.16 : 0.08)
                      : const Color(0xFFFFB800).withValues(alpha: isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (ledgerState.isOverDailyBudget || ledgerState.isOverMonthlyBudget)
                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                        : const Color(0xFFFFB800).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (ledgerState.isOverDailyBudget || ledgerState.isOverMonthlyBudget)
                          ? Icons.error_outline_rounded
                          : Icons.warning_amber_rounded,
                      color: (ledgerState.isOverDailyBudget || ledgerState.isOverMonthlyBudget)
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFFFB800),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ledgerState.isOverMonthlyBudget
                                ? 'Monthly budget ceiling exceeded!'
                                : (ledgerState.isOverDailyBudget
                                    ? 'Daily spending cap exceeded'
                                    : 'Approaching daily spending limit'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: (ledgerState.isOverDailyBudget || ledgerState.isOverMonthlyBudget)
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFFFB800),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ledgerState.isOverMonthlyBudget
                                ? 'You have exceeded your GH₵${ledgerState.monthlyBudgetLimit.toStringAsFixed(0)} limit by GH₵${(ledgerState.totalExpensesThisMonth - ledgerState.monthlyBudgetLimit).toStringAsFixed(2)}.'
                                : 'Spent GH₵${ledgerState.totalSpentToday.toStringAsFixed(2)} today against GH₵${ledgerState.dailyBudgetLimit.toStringAsFixed(0)} daily cap.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Quick Summary Row (Income, Expenses, Net)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryBox(
                    label: 'Income',
                    amount: '+GH₵${ledgerState.totalIncomeThisMonth.toStringAsFixed(0)}',
                    icon: IconlyLight.arrowDownCircle,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryBox(
                    label: 'Expenses',
                    amount: '-GH₵${ledgerState.totalExpensesThisMonth.toStringAsFixed(0)}',
                    icon: IconlyLight.arrowUpCircle,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryBox(
                    label: 'Net Balance',
                    amount: '${ledgerState.netBalance >= 0 ? '+' : ''}GH₵${ledgerState.netBalance.toStringAsFixed(0)}',
                    icon: IconlyLight.wallet,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Categorical Spending Breakdown Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SpendingBreakdownCard(
              breakdown: ledgerState.categoryBreakdown,
              totalExpenses: ledgerState.totalExpensesThisMonth,
            ),
          ),
        ),

        // Recent Transactions Section Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TRANSACTIONS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    // Add Transaction Button
                    InkWell(
                      onTap: () => _openAddTransaction(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: isDark ? Colors.white : const Color(0xFF18181B),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Log',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF18181B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Filter Chips (All, Expenses, Income)
                Row(
                  children: [
                    _buildFilterPill(
                      label: 'All',
                      isSelected: ledgerState.filterType == null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(ledgerProvider.notifier).setFilter(null);
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildFilterPill(
                      label: 'Expenses',
                      isSelected: ledgerState.filterType == TransactionType.expense,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(ledgerProvider.notifier).setFilter(TransactionType.expense);
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildFilterPill(
                      label: 'Income',
                      isSelected: ledgerState.filterType == TransactionType.income,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(ledgerProvider.notifier).setFilter(TransactionType.income);
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Transactions List or Empty State
        if (transactions.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18191E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      IconlyLight.wallet,
                      size: 36,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No transactions found',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Log an expense or income to track your cash flow.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _openAddTransaction(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Log Transaction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : const Color(0xFF18181B),
                        foregroundColor: isDark ? const Color(0xFF141517) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tx = transactions[index];
                  return TransactionTile(
                    transaction: tx,
                    onDelete: () => ref.read(ledgerProvider.notifier).deleteTransaction(tx.id),
                  );
                },
                childCount: transactions.length,
              ),
            ),
          ),

        // Bottom Spacing for floating navbar
        const SliverToBoxAdapter(
          child: SizedBox(height: 110),
        ),
      ],
    );
  }

  Widget _buildSummaryBox({
    required String label,
    required String amount,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF18181B))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF141517) : Colors.white)
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}
