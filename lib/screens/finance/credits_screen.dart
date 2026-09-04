import 'package:flutter/material.dart';

import '../../repositories/financial_assistant_repository.dart';
import '../../widgets/bus_card.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
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
    final history = await _repository.getCreditAccountHistory();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _payCredit() async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Оплатить кредит'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Сумма оплаты',
            suffixText: '₽',
            helperText:
                'На счёте: ${_money(_snapshot?.creditCash ?? 0)}',
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
            child: const Text('Оплатить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0 || _saving) return;

    setState(() => _saving = true);
    try {
      await _repository.payCredit(amount: amount);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Оплачено ${_money(amount)}.')),
        );
      }
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
      'payment' => Icons.payments_outlined,
      'order' => Icons.receipt_long_outlined,
      'payout' => Icons.account_balance_wallet_outlined,
      _ => Icons.swap_horiz,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Счёт Кредит')),
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
                          '💳 Счёт Кредит',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _money(_snapshot?.creditCash ?? 0),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Сюда попадают деньги из распределения заказов, выплат предприятия и переводов.',
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _payCredit,
                            icon: const Icon(Icons.payments_outlined),
                            label: Text(
                              _saving ? 'Сохраняю…' : 'Оплатить кредит',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'История счёта',
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
                ],
              ),
            ),
    );
  }
}
