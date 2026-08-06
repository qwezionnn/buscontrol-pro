import 'package:flutter/material.dart';

import '../../../models/expense.dart';
import '../../../repositories/expense_repository.dart';
import '../../../widgets/bus_card.dart';
import '../../expenses/add_expense_screen.dart';

class TodayExpensesSection extends StatefulWidget {
  const TodayExpensesSection({super.key});

  @override
  State<TodayExpensesSection> createState() =>
      _TodayExpensesSectionState();
}

class _TodayExpensesSectionState
    extends State<TodayExpensesSection> {
  final ExpenseRepository _repository =
      ExpenseRepository.instance;

  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final expenses = await _repository.getExpensesForDate(
        DateTime.now(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось загрузить расходы: $error',
          ),
        ),
      );
    }
  }

  Future<void> _openAddExpenseScreen() async {
    final wasSaved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddExpenseScreen(),
      ),
    );

    if (wasSaved != true) {
      return;
    }

    await _loadExpenses();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Расход сохранён'),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return BusCard(
      onTap: _openAddExpenseScreen,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .tertiaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.receipt_long,
              color: Theme.of(context)
                  .colorScheme
                  .onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Расход',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text('Добавить'),
              ],
            ),
          ),
          const Icon(Icons.add_circle_outline),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return BusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .tertiaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Theme.of(context)
                      .colorScheme
                      .onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.category,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(expense.detailsText),
                  ],
                ),
              ),
              Text(
                expense.amountText,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          if (expense.description != null &&
              expense.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(expense.description!),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const BusCard(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_expenses.isEmpty) {
      return _buildEmptyCard();
    }

    return Column(
      children: [
        for (final expense in _expenses) ...[
          _buildExpenseCard(expense),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openAddExpenseScreen,
            icon: const Icon(Icons.add),
            label: const Text('Ещё расход'),
          ),
        ),
      ],
    );
  }
}