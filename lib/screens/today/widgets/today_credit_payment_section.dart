import 'package:flutter/material.dart';

import '../../../models/credit.dart';
import '../../../repositories/credit_repository.dart';
import '../../../widgets/bus_card.dart';

class TodayCreditPaymentSection extends StatefulWidget {
  const TodayCreditPaymentSection({super.key});

  @override
  State<TodayCreditPaymentSection> createState() =>
      _TodayCreditPaymentSectionState();
}

class _TodayCreditPaymentSectionState
    extends State<TodayCreditPaymentSection> {
  final _repo = CreditRepository.instance;
  List<Credit> _credits = [];

  static const _sourceNames = <String, String>{
    'credit': 'Счёт «Кредит»',
    'vehicle': 'Счёт «Автобус»',
    'reserve': 'Заначка',
    'personal': 'Наличные / личные',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final credits = await _repo.getCredits();
    if (!mounted) return;
    setState(() {
      _credits = credits.where((x) => !x.archived).toList();
    });
  }

  String _money(double value) => '${value.toStringAsFixed(0)} ₽';

  Future<void> _pay(Credit credit) async {
    final amount = TextEditingController(
      text: credit.monthlyPayment?.toStringAsFixed(0) ?? '',
    );
    DateTime month = DateTime.now();
    var source = 'credit';

    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text('Оплата • ${credit.title}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Сумма',
                    suffixText: '₽',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: source,
                  decoration: const InputDecoration(
                    labelText: 'Откуда списать',
                  ),
                  items: _sourceNames.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setLocal(() => source = value);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: month,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setLocal(() => month = picked);
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    'Месяц: ${month.month.toString().padLeft(2, '0')}.${month.year}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'amount': double.tryParse(amount.text.replaceAll(',', '.')),
                'month':
                    '${month.year}-${month.month.toString().padLeft(2, '0')}',
                'source': source,
              }),
              child: const Text('Заплатить'),
            ),
          ],
        ),
      ),
    );

    amount.dispose();
    final value = result?['amount'] as double?;
    if (value == null || value <= 0) return;

    await _repo.addPayment(
      creditId: credit.id!,
      amount: value,
      paymentMonth: result?['month'] as String?,
      sourceAccount: result?['source'] as String? ?? 'personal',
    );
    await _load();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Платёж ${_money(value)} сохранён • ${_sourceNames[result?['source']] ?? ''}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_credits.isEmpty) return const SizedBox.shrink();

    return BusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💳 Платёж по кредиту',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text('Укажите сумму, месяц платежа и источник денег.'),
          const SizedBox(height: 10),
          for (final credit in _credits.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(credit.title),
                subtitle: Text(
                  credit.monthlyPayment == null
                      ? 'Плановый платёж не указан'
                      : 'Плановый платёж: ${_money(credit.monthlyPayment!)}',
                ),
                trailing: FilledButton(
                  onPressed: () => _pay(credit),
                  child: const Text('Заплатить'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
