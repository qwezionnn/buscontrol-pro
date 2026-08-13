import '../database/database_helper.dart';
import '../models/expense.dart';

class ExpenseRepository {
  ExpenseRepository._();

  static final ExpenseRepository instance = ExpenseRepository._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  String _databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  Future<List<Expense>> getExpensesForDate(
      DateTime date,
      ) async {
    final rows = await _databaseHelper.getExpensesByDate(
      _databaseDate(date),
    );

    final expenses = rows.map(Expense.fromMap).toList();

    expenses.sort((first, second) {
      final firstTime = first.time ?? '';
      final secondTime = second.time ?? '';

      return firstTime.compareTo(secondTime);
    });

    return expenses;
  }

  Future<int> addExpense(Expense expense) {
    return _databaseHelper.addExpense(
      date: expense.date,
      time: expense.time,
      category: expense.category,
      description: expense.description,
      amount: expense.amount,
    );
  }

  /// Удаляет ошибочно добавленный расход.
  Future<void> deleteExpense(int id) {
    return _databaseHelper.deleteExpense(id);
  }

  Future<List<Expense>> getExpensesForMonth(DateTime month) async {
    final db = await _databaseHelper.database;
    final monthText = month.month.toString().padLeft(2, '0');
    final prefix = '${month.year}-$monthText-';

    final rows = await db.query(
      'expenses',
      where: 'date LIKE ?',
      whereArgs: ['$prefix%'],
      orderBy: 'date DESC, time DESC, id DESC',
    );

    return rows.map(Expense.fromMap).toList();
  }

  Future<void> updateExpense(Expense expense) async {
    final id = expense.id;
    if (id == null) {
      throw ArgumentError('Нельзя изменить расход без id.');
    }

    final db = await _databaseHelper.database;
    await db.update(
      'expenses',
      {
        'date': expense.date,
        'time': expense.time,
        'category': expense.category,
        'description': expense.description,
        'amount': expense.amount,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalForDate(
      DateTime date,
      ) async {
    final expenses = await getExpensesForDate(date);

    return expenses.fold<double>(
      0,
          (total, expense) => total + expense.amount,
    );
  }

  Future<ExpenseDaySummary> getDaySummary(
      DateTime date,
      ) async {
    final expenses = await getExpensesForDate(date);

    final total = expenses.fold<double>(
      0,
          (sum, expense) => sum + expense.amount,
    );

    final categories = <String, double>{};

    for (final expense in expenses) {
      categories.update(
        expense.category,
            (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    return ExpenseDaySummary(
      count: expenses.length,
      total: total,
      totalsByCategory: categories,
    );
  }
}

class ExpenseDaySummary {
  const ExpenseDaySummary({
    required this.count,
    required this.total,
    required this.totalsByCategory,
  });

  final int count;
  final double total;
  final Map<String, double> totalsByCategory;
}