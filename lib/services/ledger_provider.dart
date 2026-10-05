import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/ledger.dart';

class LedgerNotifier extends Notifier<LedgerState> {
  @override
  LedgerState build() {
    return const LedgerState(
      transactions: [],
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
