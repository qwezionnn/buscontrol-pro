import 'package:flutter/material.dart';

import '../../repositories/financial_assistant_repository.dart';
import '../../widgets/bus_card.dart';

class FundTransferScreen extends StatefulWidget {
  const FundTransferScreen({super.key});

  @override
  State<FundTransferScreen> createState() => _FundTransferScreenState();
}

class _FundTransferScreenState extends State<FundTransferScreen> {
  final _repository = FinancialAssistantRepository.instance;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  FinancialSnapshot? _snapshot;
  List<Map<String, Object?>> _history = const [];
  String _from = 'vehicle';
  String _to = 'personal';
  bool _loading = true;
  bool _saving = false;

  static const _names = <String, String>{
    'vehicle': 'Автобус',
    'credit': 'Кредиты',
    'personal': 'Личные',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snapshot = await _repository.getSnapshot();
    final history = await _repository.getFundTransfers();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _history = history;
      _loading = false;
    });
  }

  double _balance(String account) {
    final snapshot = _snapshot;
    if (snapshot == null) return 0;
    return switch (account) {
      'vehicle' => snapshot.vehicleCash,
      'credit' => snapshot.creditCash,
      'personal' => snapshot.personalCash,
      _ => 0,
    };
  }

  String _money(double value) => '${value.toStringAsFixed(0)} ₽';

  Future<void> _transfer() async {
    if (_saving) return;
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      _message('Введите корректную сумму.');
      return;
    }
    if (_from == _to) {
      _message('Выберите разные счета.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _repository.transferFunds(
        fromAccount: _from,
        toAccount: _to,
        amount: amount,
        note: _noteController.text,
      );
      _amountController.clear();
      _noteController.clear();
      await _load();
      if (mounted) _message('Перевод выполнен.');
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _deleteTransfer(Map<String, Object?> row) async {
    final id = row['id'];
    if (id is! int) return;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Удалить перевод?'),
        content: const Text(
          'Остатки счетов будут пересчитаны так, будто этого перевода не было.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteFundTransfer(id);
    await _load();
  }

  Widget _accountCard(String key, IconData icon) {
    return Expanded(
      child: BusCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(_names[key]!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            Text(
              _money(_balance(key)),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Перевод между счетами')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      _accountCard('vehicle', Icons.directions_bus),
                      const SizedBox(width: 8),
                      _accountCard('credit', Icons.credit_score),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _accountCard('personal', Icons.person_outline),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BusCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Новый перевод',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _from,
                          decoration: const InputDecoration(
                            labelText: 'Откуда',
                          ),
                          items: _names.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    '${e.value} • ${_money(_balance(e.key))}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _from = value;
                              if (_to == value) {
                                _to = _names.keys.firstWhere(
                                  (key) => key != value,
                                );
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _to,
                          decoration: const InputDecoration(
                            labelText: 'Куда',
                          ),
                          items: _names.entries
                              .where((e) => e.key != _from)
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _to = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Сумма',
                            suffixText: '₽',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            labelText: 'Комментарий',
                            hintText: 'Необязательно',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _transfer,
                            icon: const Icon(Icons.swap_horiz),
                            label: Text(
                              _saving ? 'Перевожу…' : 'Перевести',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'История переводов',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    const BusCard(
                      child: Text('Переводов пока нет.'),
                    )
                  else
                    for (final row in _history)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onLongPress: () => _deleteTransfer(row),
                          child: BusCard(
                            child: Row(
                            children: [
                              const Icon(Icons.swap_horiz),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_names[row['from_account']] ?? row['from_account']}'
                                      ' → '
                                      '${_names[row['to_account']] ?? row['to_account']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if ((row['note']?.toString() ?? '').trim().isNotEmpty)
                                      Text(row['note'].toString()),
                                    Text(
                                      row['transferred_at']?.toString() ?? '',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _money(
                                  (row['amount'] as num?)?.toDouble() ?? 0,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
