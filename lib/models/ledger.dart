import 'package:flutter/material.dart';
import 'package:iconly_plus/iconly_plus.dart';

enum TransactionType {
  expense,
  income,
}

enum ExpenseCategory {
  food('Food & Dining', IconlyLight.buy),
  transport('Transport', IconlyLight.location),
  shopping('Shopping', IconlyLight.bag),
  bills('Bills & Utilities', IconlyLight.document),
  entertainment('Entertainment', IconlyLight.video),
  health('Health & Fitness', IconlyLight.heart),
  education('Education', IconlyLight.bookmark),
  personal('Personal Care', IconlyLight.user),
  income('Income / Salary', IconlyLight.wallet);

  final String label;
  final IconData icon;
  const ExpenseCategory(this.label, this.icon);
}

class TransactionItem {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final ExpenseCategory category;
  final DateTime dateTime;
  final String? note;

  const TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.dateTime,
    this.note,
  });

  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;

  String get formattedAmount {
    final prefix = isExpense ? '-GH₵' : '+GH₵';
    return '$prefix${amount.toStringAsFixed(2)}';
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute $amPm';

    if (itemDay == today) {
      return 'Today, $timeStr';
    } else if (itemDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $timeStr';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}, $timeStr';
    }
  }

  TransactionItem copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    ExpenseCategory? category,
    DateTime? dateTime,
    String? note,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category.name,
      'dateTime': dateTime.toIso8601String(),
      'note': note,
    };
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TransactionType.expense,
      ),
      category: ExpenseCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ExpenseCategory.food,
      ),
      dateTime: DateTime.parse(json['dateTime'] as String),
      note: json['note'] as String?,
    );
  }
}

class LedgerState {
  final List<TransactionItem> transactions;
  final double monthlyBudgetLimit;
  final double dailyBudgetLimit;
  final TransactionType? filterType;

  const LedgerState({
    required this.transactions,
    this.monthlyBudgetLimit = 1500.0,
    this.dailyBudgetLimit = 60.0,
    this.filterType,
  });

  // Calculations for current month
  double get totalIncomeThisMonth {
    final now = DateTime.now();
    return transactions
        .where((t) => t.isIncome && t.dateTime.year == now.year && t.dateTime.month == now.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpensesThisMonth {
    final now = DateTime.now();
    return transactions
        .where((t) => t.isExpense && t.dateTime.year == now.year && t.dateTime.month == now.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get netBalance => totalIncomeThisMonth - totalExpensesThisMonth;

  // Today calculations
  double get totalSpentToday {
    final now = DateTime.now();
    return transactions
        .where((t) =>
            t.isExpense &&
            t.dateTime.year == now.year &&
            t.dateTime.month == now.month &&
            t.dateTime.day == now.day)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get dailyRemaining => (dailyBudgetLimit - totalSpentToday).clamp(0.0, double.infinity);
  double get monthlyRemaining => (monthlyBudgetLimit - totalExpensesThisMonth).clamp(0.0, double.infinity);

  double get dailyProgress =>
      dailyBudgetLimit > 0 ? (totalSpentToday / dailyBudgetLimit).clamp(0.0, 1.0) : 0.0;

  double get monthlyProgress =>
      monthlyBudgetLimit > 0 ? (totalExpensesThisMonth / monthlyBudgetLimit).clamp(0.0, 1.0) : 0.0;

  bool get isOverDailyBudget => totalSpentToday > dailyBudgetLimit;
  bool get isOverMonthlyBudget => totalExpensesThisMonth > monthlyBudgetLimit;
  bool get isNearDailyLimit => !isOverDailyBudget && dailyProgress >= 0.85;

  Map<ExpenseCategory, double> get categoryBreakdown {
    final now = DateTime.now();
    final map = <ExpenseCategory, double>{};
    for (final t in transactions) {
      if (t.isExpense && t.dateTime.year == now.year && t.dateTime.month == now.month) {
        map[t.category] = (map[t.category] ?? 0.0) + t.amount;
      }
    }
    return map;
  }

  List<TransactionItem> get filteredTransactions {
    if (filterType == null) return transactions;
    return transactions.where((t) => t.type == filterType).toList();
  }

  LedgerState copyWith({
    List<TransactionItem>? transactions,
    double? monthlyBudgetLimit,
    double? dailyBudgetLimit,
    TransactionType? filterType,
    bool clearFilter = false,
  }) {
    return LedgerState(
      transactions: transactions ?? this.transactions,
      monthlyBudgetLimit: monthlyBudgetLimit ?? this.monthlyBudgetLimit,
      dailyBudgetLimit: dailyBudgetLimit ?? this.dailyBudgetLimit,
      filterType: clearFilter ? null : (filterType ?? this.filterType),
    );
  }
}
