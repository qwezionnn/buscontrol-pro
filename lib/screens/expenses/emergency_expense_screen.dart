import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../repositories/expense_repository.dart';

class EmergencyExpenseScreen extends StatefulWidget {
  const EmergencyExpenseScreen({super.key});

  @override
  State<EmergencyExpenseScreen> createState() =>
      _EmergencyExpenseScreenState();
}

class _EmergencyExpenseScreenState
    extends State<EmergencyExpenseScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String _category = 'Поломка';
  bool _saving = false;

  static const _categories = [
    'Поломка',
    'Двигатель',
    'Коробка',
    'Подвеска',
    'Кузов',
    'Стекло',
    'Эвакуатор',
    'Другое',
  ];

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value =
        double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await ExpenseRepository.instance.addExpense(
      Expense(
        date: date,
        time: time,
        category: 'Экстренно: $_category',
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        amount: value,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Экстренный расход')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Причина',
              prefixIcon: Icon(Icons.warning_amber_rounded),
            ),
            items: _categories
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Сумма',
              suffixText: '₽',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              hintText: 'Что произошло и что было куплено',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Сохраняем...' : 'Записать расход'),
          ),
        ],
      ),
    );
  }
}
