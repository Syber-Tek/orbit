import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/ledger.dart';

class LedgerNotifier extends Notifier<LedgerState> {
  @override
  LedgerState build() {
    final now = DateTime.now();

    final starterTransactions = [
      TransactionItem(
        id: 'tx_1',
        title: 'Specialty Coffee & Pastry',
        amount: 6.50,
        type: TransactionType.expense,
        category: ExpenseCategory.food,
        dateTime: now.subtract(const Duration(hours: 2, minutes: 15)),
        note: 'Morning pour-over at cafe',
      ),
      TransactionItem(
        id: 'tx_2',
        title: 'Subway Transit Pass',
        amount: 18.00,
        type: TransactionType.expense,
        category: ExpenseCategory.transport,
        dateTime: now.subtract(const Duration(hours: 4, minutes: 40)),
      ),
      TransactionItem(
        id: 'tx_3',
        title: 'Whole Foods Groceries',
        amount: 64.20,
        type: TransactionType.expense,
        category: ExpenseCategory.food,
        dateTime: now.subtract(const Duration(days: 1, hours: 3)),
        note: 'Fresh produce & pantry staples',
      ),
      TransactionItem(
        id: 'tx_4',
        title: 'Freelance UI/UX Retainer',
        amount: 750.00,
        type: TransactionType.income,
        category: ExpenseCategory.income,
        dateTime: now.subtract(const Duration(days: 1, hours: 6)),
        note: 'Milestone payment via Stripe',
      ),
      TransactionItem(
        id: 'tx_5',
        title: 'Fitness Club Membership',
        amount: 45.00,
        type: TransactionType.expense,
        category: ExpenseCategory.health,
        dateTime: now.subtract(const Duration(days: 3, hours: 2)),
      ),
      TransactionItem(
        id: 'tx_6',
        title: 'Cloud Workspace Subscription',
        amount: 12.00,
        type: TransactionType.expense,
        category: ExpenseCategory.bills,
        dateTime: now.subtract(const Duration(days: 5, hours: 8)),
      ),
      TransactionItem(
        id: 'tx_7',
        title: 'Direct Deposit Paycheck',
        amount: 1950.00,
        type: TransactionType.income,
        category: ExpenseCategory.income,
        dateTime: now.subtract(const Duration(days: 8)),
      ),
    ];

    return LedgerState(
      transactions: starterTransactions,
      monthlyBudgetLimit: 1400.0,
      dailyBudgetLimit: 60.0,
    );
  }

  void addTransaction(TransactionItem transaction) {
    state = state.copyWith(
      transactions: [transaction, ...state.transactions],
    );
  }

  void deleteTransaction(String id) {
    state = state.copyWith(
      transactions: state.transactions.where((t) => t.id != id).toList(),
    );
  }

  void updateTransaction(TransactionItem updated) {
    state = state.copyWith(
      transactions: state.transactions.map((t) => t.id == updated.id ? updated : t).toList(),
    );
  }

  void setMonthlyBudget(double amount) {
    state = state.copyWith(monthlyBudgetLimit: amount);
  }

  void setDailyBudget(double amount) {
    state = state.copyWith(dailyBudgetLimit: amount);
  }

  void setFilter(TransactionType? type) {
    if (type == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterType: type);
    }
  }
}

final ledgerProvider = NotifierProvider<LedgerNotifier, LedgerState>(LedgerNotifier.new);
