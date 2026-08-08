import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/fuel_repository.dart';

class HomeFuelSettlementScreen extends StatefulWidget {
  const HomeFuelSettlementScreen({super.key});

  @override
  State<HomeFuelSettlementScreen> createState() =>
      _HomeFuelSettlementScreenState();
}

class _HomeFuelSettlementScreenState
    extends State<HomeFuelSettlementScreen> {
  final _amountController = TextEditingController();
  final _expenseRepository = ExpenseRepository.instance;
  final _fuelRepository = FuelRepository.instance;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _expenseDate = DateTime.now();
  double _liters = 0;
  bool _loading = true;
  bool _saving = false;

  static const _months = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _date(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _visibleDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  double get _amount =>
      double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

  Future<void> _load() async {
    setState(() => _loading = true);
    final liters = await _fuelRepository.getHomeLitersForMonth(_month);
    if (!mounted) return;
    setState(() {
      _liters = liters;
      _loading = false;
    });
  }

  void _changeMonth(int offset) {
    _month = DateTime(_month.year, _month.month + offset);
    _load();
  }

  Future<void> _selectExpenseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() => _expenseDate = selected);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_liters <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('За выбранный месяц нет домашних заправок.'),
        ),
      );
      return;
    }
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите фактическую сумму.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final monthTitle =
          '${_months[_month.month - 1].toLowerCase()} ${_month.year}';
      await _expenseRepository.addExpense(
        Expense(
          date: _date(_expenseDate),
          category: 'Домашнее топливо',
          description:
              'Расчёт домашнего топлива за $monthTitle — ${_number(_liters)} л',
          amount: _amount,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Расчёт домашнего топлива')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${_months[_month.month - 1]} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Заправлено дома за месяц',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_number(_liters)} л',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Цена за литр для домашних заправок не используется. '
                            'Укажите только фактическую общую сумму, которую '
                            'нужно списать с кошелька автобуса.',
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Фактическая сумма за месяц',
                hintText: 'Например: 9500',
                suffixText: '₽',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _selectExpenseDate,
              icon: const Icon(Icons.calendar_month),
              label: Text('Дата списания: ${_visibleDate(_expenseDate)}'),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'После сохранения эта сумма попадёт в расходы на топливо '
                  'и уменьшит кошелёк автобуса. Литры уже были учтены в дни '
                  'фактических домашних заправок.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving || _loading ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.payments_outlined),
              label: Text(
                _saving ? 'Сохраняем...' : 'Списать с кошелька автобуса',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
