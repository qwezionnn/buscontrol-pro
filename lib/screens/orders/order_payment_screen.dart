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

  final _vehiclePercentController = TextEditingController();
  final _vehicleAmountController = TextEditingController();

  final _personalPercentController = TextEditingController();
  final _personalAmountController = TextEditingController();

  final Map<String, TextEditingController> _creditPercentControllers = {};
  final Map<String, TextEditingController> _creditAmountControllers = {};

  bool _loading = true;
  bool _saving = false;
  bool _syncing = false;

  double _parse(TextEditingController controller) {
    return double.tryParse(
          controller.text.trim().replaceAll(',', '.'),
        ) ??
        0;
  }

  double get _paymentAmount => _parse(_amountController);

  double get _vehicleAmount => _parse(_vehicleAmountController);

  double get _personalAmount => _parse(_personalAmountController);

  double get _allocatedAmount =>
      _vehicleAmount +
      _personalAmount +
      _creditAmountControllers.values.fold<double>(
        0,
        (sum, controller) => sum + _parse(controller),
      );

  double get _remainingToAllocate => _paymentAmount - _allocatedAmount;

  @override
  void initState() {
    super.initState();
    _amountController.text = _formatInputMoney(widget.order.remainingAmount);
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

    _vehiclePercentController.text =
        _formatPercent(settings.workFundPercent);
    _personalPercentController.text =
        _formatPercent(settings.personalFundPercent);

    if (credits.isEmpty) {
      _creditPercentControllers['Кредит'] = TextEditingController(
        text: _formatPercent(settings.loanFundPercent),
      );
      _creditAmountControllers['Кредит'] = TextEditingController();
    } else {
      var named = 0.0;

      for (final credit in credits) {
        named += credit.incomePercent;
        _creditPercentControllers[credit.title] = TextEditingController(
          text: _formatPercent(credit.incomePercent),
        );
        _creditAmountControllers[credit.title] = TextEditingController();
      }

      final reserve = (settings.loanFundPercent - named)
          .clamp(0, double.infinity)
          .toDouble();

      if (reserve > 0.001) {
        _creditPercentControllers['Кредитный резерв'] =
            TextEditingController(
          text: _formatPercent(reserve),
        );
        _creditAmountControllers['Кредитный резерв'] =
            TextEditingController();
      }
    }

    _syncAllAmountsFromPercents();

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatPercent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatInputMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _money(double value) => '${_formatInputMoney(value)} ₽';

  void _setControllerNumber(
    TextEditingController controller,
    double value, {
    bool percent = false,
  }) {
    controller.text =
        percent ? _formatPercent(value) : _formatInputMoney(value);
  }

  void _syncAllAmountsFromPercents() {
    if (_syncing) return;

    _syncing = true;
    final amount = _paymentAmount;

    _setControllerNumber(
      _vehicleAmountController,
      amount * _parse(_vehiclePercentController) / 100,
    );

    for (final entry in _creditPercentControllers.entries) {
      final amountController = _creditAmountControllers[entry.key];
      if (amountController == null) continue;

      _setControllerNumber(
        amountController,
        amount * _parse(entry.value) / 100,
      );
    }

    _setControllerNumber(
      _personalAmountController,
      amount * _parse(_personalPercentController) / 100,
    );

    _syncing = false;
  }

  void _syncAmountFromPercent(
    TextEditingController percentController,
    TextEditingController amountController,
  ) {
    if (_syncing) return;

    _syncing = true;
    final percent = _parse(percentController);
    _setControllerNumber(
      amountController,
      _paymentAmount * percent / 100,
    );
    _syncing = false;
  }

  void _syncPercentFromAmount(
    TextEditingController amountController,
    TextEditingController percentController,
  ) {
    if (_syncing) return;

    _syncing = true;
    final total = _paymentAmount;
    final part = _parse(amountController);
    final percent = total <= 0 ? 0.0 : part / total * 100;
    _setControllerNumber(
      percentController,
      percent,
      percent: true,
    );
    _syncing = false;
  }

  double _percentForAmount(double amount) {
    if (_paymentAmount <= 0) return 0;
    return amount / _paymentAmount * 100;
  }

  Map<String, double> _creditPercentsForSave() {
    return {
      for (final entry in _creditAmountControllers.entries)
        entry.key: _percentForAmount(_parse(entry.value)),
    };
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();

    _vehiclePercentController.dispose();
    _vehicleAmountController.dispose();
    _personalPercentController.dispose();
    _personalAmountController.dispose();

    for (final controller in _creditPercentControllers.values) {
      controller.dispose();
    }
    for (final controller in _creditAmountControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;

    if (_remainingToAllocate.abs() > 0.01) {
      setState(() {});
      return;
    }

    final id = widget.order.id;
    if (id == null) return;

    setState(() {
      _saving = true;
    });

    try {
      await OrderRepository.instance.addPayment(
        orderId: id,
        amount: _paymentAmount,
        vehiclePercent: _percentForAmount(_vehicleAmount),
        personalPercent: _percentForAmount(_personalAmount),
        creditPercents: _creditPercentsForSave(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось сохранить оплату: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _distributionField({
    required String title,
    required IconData icon,
    required TextEditingController percentController,
    required TextEditingController amountController,
  }) {
    return BusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: percentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Процент',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    _syncAmountFromPercent(
                      percentController,
                      amountController,
                    );
                    setState(() {});
                  },
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
                child: TextFormField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Сумма',
                    suffixText: '₽',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    _syncPercentFromAmount(
                      amountController,
                      percentController,
                    );
                    setState(() {});
                  },
                  validator: (value) {
                    final number = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );
                    if (number == null || number < 0) {
                      return '≥ 0';
                    }
                    if (number > _paymentAmount + 0.01) {
                      return 'Больше оплаты';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final difference = _remainingToAllocate;
    final validDistribution = difference.abs() <= 0.01;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Оплата заказа'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
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
                          Text(
                            'Стоимость: ${_money(widget.order.amount)}',
                          ),
                          Text(
                            'Уже получено: '
                            '${_money(widget.order.paidAmount)}',
                          ),
                          Text(
                            'Осталось: '
                            '${_money(widget.order.remainingAmount)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
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
                        helperText:
                            'Можно указать полную или частичную оплату',
                        suffixText: '₽',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        _syncAllAmountsFromPercents();
                        setState(() {});
                      },
                      validator: (value) {
                        final amount = double.tryParse(
                          (value ?? '').trim().replaceAll(',', '.'),
                        );

                        if (amount == null || amount <= 0) {
                          return 'Введите сумму больше нуля';
                        }

                        if (amount >
                            widget.order.remainingAmount + 0.001) {
                          return 'Сумма больше остатка';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Распределение этой выплаты',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Можно менять как проценты, так и суммы в рублях. '
                      'Изменения относятся только к этой конкретной выплате.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    _distributionField(
                      title: 'На автобус',
                      icon: Icons.directions_bus_outlined,
                      percentController: _vehiclePercentController,
                      amountController: _vehicleAmountController,
                    ),
                    const SizedBox(height: 10),
                    for (final entry
                        in _creditPercentControllers.entries) ...[
                      _distributionField(
                        title: entry.key,
                        icon: Icons.account_balance_outlined,
                        percentController: entry.value,
                        amountController:
                            _creditAmountControllers[entry.key]!,
                      ),
                      const SizedBox(height: 10),
                    ],
                    _distributionField(
                      title: 'Личные деньги',
                      icon: Icons.person_outline,
                      percentController: _personalPercentController,
                      amountController: _personalAmountController,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: validDistribution
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        validDistribution
                            ? 'Распределено полностью: '
                                '${_money(_allocatedAmount)}'
                            : difference > 0
                                ? 'Осталось распределить: '
                                    '${_money(difference)}'
                                : 'Распределено больше выплаты на: '
                                    '${_money(-difference)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
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
                      onPressed:
                          validDistribution && !_saving ? _save : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _saving
                            ? 'Сохраняем...'
                            : 'Сохранить оплату',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
