import 'package:flutter/material.dart';

import '../../../repositories/financial_assistant_repository.dart';
import '../../../widgets/bus_card.dart';

class TodayCreditPaymentSection extends StatefulWidget {
  const TodayCreditPaymentSection({super.key});

  @override
  State<TodayCreditPaymentSection> createState() =>
      _TodayCreditPaymentSectionState();
}

class _TodayCreditPaymentSectionState
    extends State<TodayCreditPaymentSection> {
  final _repository = FinancialAssistantRepository.instance;
  FinancialSnapshot? _snapshot;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _money(double value) => '${value.toStringAsFixed(0)} ₽';

  Future<void> _load() async {
    final snapshot = await _repository.getSnapshot();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  Future<void> _pay() async {
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
            labelText: 'Сумма',
            suffixText: '₽',
            helperText: 'На счёте Кредит: ${_money(_snapshot?.creditCash ?? 0)}',
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
          SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return BusCard(
      child: Row(
        children: [
          const Icon(Icons.credit_score_outlined, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💳 Счёт Кредит',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text('Накоплено: ${_money(_snapshot?.creditCash ?? 0)}'),
              ],
            ),
          ),
          FilledButton(
            onPressed: _saving ? null : _pay,
            child: const Text('Оплатить'),
          ),
        ],
      ),
    );
  }
}
