import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/ledger.dart';
import 'package:orbit/services/persistence_service.dart';

class LedgerNotifier extends Notifier<LedgerState> {
  @override
  LedgerState build() {
    final savedTx = PersistenceService.instance.loadTransactions();
    final savedMonthly = PersistenceService.instance.loadMonthlyBudget();
    final savedDaily = PersistenceService.instance.loadDailyBudget();

    return LedgerState(
      transactions: savedTx ?? const [],
      monthlyBudgetLimit: savedMonthly ?? 1400.0,
      dailyBudgetLimit: savedDaily ?? 60.0,
    );
  }

  void addTransaction(TransactionItem transaction) {
    state = state.copyWith(
      transactions: [transaction, ...state.transactions],
    );
    PersistenceService.instance.saveTransactions(state.transactions);
  }

  void deleteTransaction(String id) {
    state = state.copyWith(
      transactions: state.transactions.where((t) => t.id != id).toList(),
    );
    PersistenceService.instance.saveTransactions(state.transactions);
  }

  void updateTransaction(TransactionItem updated) {
    state = state.copyWith(
      transactions: state.transactions.map((t) => t.id == updated.id ? updated : t).toList(),
    );
    PersistenceService.instance.saveTransactions(state.transactions);
  }

  void setMonthlyBudget(double amount) {
    state = state.copyWith(monthlyBudgetLimit: amount);
    PersistenceService.instance.saveMonthlyBudget(amount);
  }

  void setDailyBudget(double amount) {
    state = state.copyWith(dailyBudgetLimit: amount);
    PersistenceService.instance.saveDailyBudget(amount);
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
