import 'package:flutter/material.dart';

import '../../repositories/financial_assistant_repository.dart';
import '../../widgets/bus_card.dart';

class ReserveScreen extends StatefulWidget {
  const ReserveScreen({super.key});

  @override
  State<ReserveScreen> createState() => _ReserveScreenState();
}

class _ReserveScreenState extends State<ReserveScreen> {
  final _repository = FinancialAssistantRepository.instance;

  FinancialSnapshot? _snapshot;
  List<Map<String, Object?>> _history = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _money(double value) {
    final sign = value < 0 ? '−' : '';
    return '$sign${value.abs().toStringAsFixed(0)} ₽';
  }

  Future<void> _load() async {
    final snapshot = await _repository.getSnapshot();
    final history = await _repository.getReserveHistory();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _history = history;
      _loading = false;
    });
  }

  Future<double?> _askAmount({
    required String title,
    String? helper,
    double? initial,
  }) async {
    final controller = TextEditingController(
      text: initial == null ? '' : initial.toStringAsFixed(0),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Сумма',
            suffixText: '₽',
            helperText: helper,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.trim().replaceAll(',', '.')),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _editBalance() async {
    final value = await _askAmount(
      title: 'Фактическая сумма заначки',
      helper: 'Изменение сохранится в истории как корректировка.',
      initial: _snapshot?.reserveCash ?? 0,
    );
    if (value == null || value < 0) return;
    await _run(() => _repository.setReserveBalance(value));
  }

  Future<void> _topUp() async {
    final amount = await _askAmount(title: 'Пополнить заначку');
    if (amount == null || amount <= 0) return;

    var source = 'personal';
    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('Откуда пополнить'),
          content: DropdownButtonFormField<String>(
            initialValue: source,
            items: const [
              DropdownMenuItem(value: 'personal', child: Text('Личные')),
              DropdownMenuItem(value: 'vehicle', child: Text('Автобус')),
              DropdownMenuItem(value: 'credit', child: Text('Кредит')),
            ],
            onChanged: (value) {
              if (value != null) setLocal(() => source = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, source),
              child: const Text('Пополнить'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _run(
      () => _repository.transferFunds(
        fromAccount: selected,
        toAccount: 'reserve',
        amount: amount,
        note: 'Пополнение заначки',
      ),
    );
  }

  Future<void> _withdraw() async {
    final amount = await _askAmount(
      title: 'Снять из заначки',
      helper: 'Доступно: ${_money(_snapshot?.reserveCash ?? 0)}',
    );
    if (amount == null || amount <= 0) return;

    var target = 'personal';
    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('Куда перевести'),
          content: DropdownButtonFormField<String>(
            initialValue: target,
            items: const [
              DropdownMenuItem(value: 'personal', child: Text('Личные')),
              DropdownMenuItem(value: 'vehicle', child: Text('Автобус')),
              DropdownMenuItem(value: 'credit', child: Text('Кредит')),
            ],
            onChanged: (value) {
              if (value != null) setLocal(() => target = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, target),
              child: const Text('Перевести'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _run(
      () => _repository.transferFunds(
        fromAccount: 'reserve',
        toAccount: selected,
        amount: amount,
        note: 'Снятие из заначки',
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  IconData _iconFor(String kind) {
    return switch (kind) {
      'expense' => Icons.build_outlined,
      'fuel' => Icons.local_gas_station_outlined,
      'adjustment' => Icons.edit_outlined,
      'order' => Icons.receipt_long_outlined,
      'payout' => Icons.account_balance_wallet_outlined,
      _ => Icons.swap_horiz,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Заначка')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  BusCard(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🏦 Заначка',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _money(_snapshot?.reserveCash ?? 0),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _saving ? null : _topUp,
                              icon: const Icon(Icons.add),
                              label: const Text('Пополнить'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _saving ? null : _withdraw,
                              icon: const Icon(Icons.remove),
                              label: const Text('Снять'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _editBalance,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Изменить сумму'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'История заначки',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    const BusCard(child: Text('Операций пока нет.'))
                  else
                    for (final row in _history)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: BusCard(
                          child: Row(
                            children: [
                              Icon(_iconFor(row['kind']?.toString() ?? '')),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row['title']?.toString() ?? 'Операция',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if ((row['note']?.toString() ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      Text(row['note'].toString()),
                                    Text(
                                      row['date']?.toString() ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
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
                  const SizedBox(height: 12),
                  Text(
                    'Оплата топлива, запчастей и других расходов из заначки тоже автоматически уменьшает её остаток и попадает сюда.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }
}
