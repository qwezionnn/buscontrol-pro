import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../models/credit.dart';
import '../../models/order.dart';
import '../../repositories/credit_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../widgets/bus_card.dart';

class OrderPaymentScreen extends StatefulWidget {
  const OrderPaymentScreen({
    super.key,
    required this.order,
  });

  final Order order;

  @override
  State<OrderPaymentScreen> createState() => _OrderPaymentScreenState();
}

class _OrderPaymentScreenState extends State<OrderPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _personalController = TextEditingController();
  final Map<String, TextEditingController> _creditControllers = {};

  bool _loading = true;
  bool _saving = false;

  double _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;

  double get _amount => _parse(_amountController);
  double get _vehiclePercent => _parse(_vehicleController);
  double get _personalPercent => _parse(_personalController);
  double get _totalPercent =>
      _vehiclePercent +
      _personalPercent +
      _creditControllers.values.fold<double>(
        0,
        (sum, controller) => sum + _parse(controller),
      );

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.order.remainingAmount.toStringAsFixed(0);
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SettingsRepository.instance.getSettings(),
      CreditRepository.instance.getCredits(),
    ]);
    final settings = results[0] as AppSettings;
    final credits = (results[1] as List<Credit>)
        .where((credit) => !credit.archived && !credit.isClosed)
        .toList();

    _vehicleController.text = _formatPercent(settings.workFundPercent);
    _personalController.text = _formatPercent(settings.personalFundPercent);

    if (credits.isEmpty) {
      _creditControllers['Кредит'] = TextEditingController(
        text: _formatPercent(settings.loanFundPercent),
      );
    } else {
      var named = 0.0;
      for (final credit in credits) {
        named += credit.incomePercent;
        _creditControllers[credit.title] = TextEditingController(
          text: _formatPercent(credit.incomePercent),
        );
      }
      final reserve =
          (settings.loanFundPercent - named).clamp(0, double.infinity).toDouble();
      if (reserve > 0.001) {
        _creditControllers['Кредитный резерв'] = TextEditingController(
          text: _formatPercent(reserve),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  String _formatPercent(double value) =>
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);

  String _money(double value) => '${value.toStringAsFixed(0)} ₽';

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _vehicleController.dispose();
    _personalController.dispose();
    for (final controller in _creditControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    if ((_totalPercent - 100).abs() > 0.01) {
      setState(() {});
      return;
    }
    final id = widget.order.id;
    if (id == null) return;

    setState(() => _saving = true);
    try {
      await OrderRepository.instance.addPayment(
        orderId: id,
        amount: _amount,
        vehiclePercent: _vehiclePercent,
        personalPercent: _personalPercent,
        creditPercents: {
          for (final entry in _creditControllers.entries)
            entry.key: _parse(entry.value),
        },
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить оплату: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _percentField(
    String title,
    TextEditingController controller,
    IconData icon,
  ) {
    final percent = _parse(controller);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: title,
                prefixIcon: Icon(icon),
                suffixText: '%',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final number = double.tryParse(
                  (value ?? '').trim().replaceAll(',', '.'),
                );
                if (number == null || number < 0 || number > 100) {
                  return '0–100';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                _money(_amount * percent / 100),
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final delta = 100 - _totalPercent;
    final valid = delta.abs() <= 0.01;

    return Scaffold(
      appBar: AppBar(title: const Text('Оплата заказа')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    BusCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.order.title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Стоимость: ${_money(widget.order.amount)}'),
                          Text(
                            'Уже получено: ${_money(widget.order.paidAmount)}',
                          ),
                          Text(
                            'Осталось: ${_money(widget.order.remainingAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Получено сейчас',
                        suffixText: '₽',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final amount = double.tryParse(
                          (value ?? '').trim().replaceAll(',', '.'),
                        );
                        if (amount == null || amount <= 0) {
                          return 'Введите сумму больше нуля';
                        }
                        if (amount > widget.order.remainingAmount + 0.001) {
                          return 'Сумма больше остатка';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Распределение этой оплаты',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Изменения действуют только на эту оплату.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    _percentField(
                      'На автобус',
                      _vehicleController,
                      Icons.directions_bus_outlined,
                    ),
                    for (final entry in _creditControllers.entries)
                      _percentField(
                        entry.key,
                        entry.value,
                        Icons.account_balance_outlined,
                      ),
                    _percentField(
                      'Личные деньги',
                      _personalController,
                      Icons.person_outline,
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: valid
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        valid
                            ? 'Распределено 100%'
                            : delta > 0
                                ? 'Осталось распределить '
                                    '${_formatPercent(delta)}%'
                                : 'Превышение ${_formatPercent(-delta)}%',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий',
                        hintText: 'Наличными, перевод и т. п.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: valid && !_saving ? _save : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _saving ? 'Сохраняем...' : 'Сохранить оплату',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
