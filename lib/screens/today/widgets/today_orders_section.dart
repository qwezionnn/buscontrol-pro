import 'package:flutter/material.dart';

import '../../../models/app_settings.dart';
import '../../../models/order.dart';
import '../../../models/credit.dart';
import '../../../repositories/order_repository.dart';
import '../../../repositories/settings_repository.dart';
import '../../../repositories/credit_repository.dart';
import '../../../widgets/bus_card.dart';
import '../../orders/add_order_screen.dart';

class TodayOrdersSection extends StatefulWidget {
  const TodayOrdersSection({super.key});

  @override
  State<TodayOrdersSection> createState() => _TodayOrdersSectionState();
}

class _TodayOrdersSectionState extends State<TodayOrdersSection> {
  final OrderRepository _repository = OrderRepository.instance;
  final SettingsRepository _settingsRepository =
      SettingsRepository.instance;

  List<Order> _orders = [];
  AppSettings _settings = AppSettings.defaults();
  List<Credit> _credits = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final results = await Future.wait([
        _repository.getOrdersForDate(DateTime.now()),
        _settingsRepository.getSettings(),
        CreditRepository.instance.getCredits(),
      ]);

      final orders = results[0] as List<Order>;
      final settings = results[1] as AppSettings;
      final credits = results[2] as List<Credit>;

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = orders;
        _settings = settings;
        _credits = credits;
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
            'Не удалось загрузить заказы: $error',
          ),
        ),
      );
    }
  }

  Future<void> _openAddOrderScreen() async {
    final wasSaved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddOrderScreen(),
      ),
    );

    if (wasSaved != true) {
      return;
    }

    await _loadOrders();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Заказ сохранён'),
      ),
    );
  }

  Future<void> _markCompleted(Order order) async {
    final orderId = order.id;

    if (orderId == null) {
      return;
    }

    try {
      await _repository.markCompleted(orderId);
      await _loadOrders();

      if (!mounted) {
        return;
      }

      final updated = _orders.firstWhere(
        (item) => item.id == orderId,
        orElse: () => order.copyWith(status: OrderStatus.completed),
      );
      await _showPaymentDialog(updated, firstPayment: true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось изменить заказ: $error',
          ),
        ),
      );
    }
  }

  double _distributionAmount(
    double amount,
    double percent,
  ) {
    return amount * percent / 100;
  }

  Future<void> _showPaymentDialog(
    Order order, {
    bool firstPayment = false,
  }) async {
    final orderId = order.id;
    if (orderId == null || order.remainingAmount <= 0.001) {
      return;
    }

    final result = await showAdaptiveDialog<_PaymentDialogResult>(
      context: context,
      builder: (dialogContext) {
        return _PaymentDialog(
          order: order,
          firstPayment: firstPayment,
          formatMoney: _formatMoney,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      await _repository.addPayment(
        orderId: orderId,
        amount: result.amount,
        note: result.note,
      );

      await _loadOrders();

      if (!mounted) {
        return;
      }

      // Даём закрывшемуся диалогу полностью завершить удаление
      // из дерева виджетов перед открытием следующего окна.
      await Future<void>.delayed(const Duration(milliseconds: 120));

      if (!mounted) {
        return;
      }

      await _showPaymentDistribution(result.amount);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить оплату: $error'),
        ),
      );
    }
  }

  Future<void> _showPaymentDistribution(double amount) {
    return showAdaptiveDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog.adaptive(
          title: const Text('Оплата получена'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Получено сейчас: ${_formatMoney(amount)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Divider(height: 24),
              _buildDialogDistributionRow(
                'На машину',
                _settings.workFundPercent,
                _distributionAmount(amount, _settings.workFundPercent),
              ),
              const SizedBox(height: 12),
              if (_credits.isEmpty)
                _buildDialogDistributionRow(
                  'На кредит',
                  _settings.loanFundPercent,
                  _distributionAmount(amount, _settings.loanFundPercent),
                )
              else
                for (final credit in _credits.where(
                  (credit) => !credit.archived && !credit.isClosed,
                )) ...[
                  _buildDialogDistributionRow(
                    credit.title,
                    credit.incomePercent,
                    _distributionAmount(amount, credit.incomePercent),
                  ),
                  const SizedBox(height: 12),
                ],
              if (_credits.isEmpty) const SizedBox(height: 12),
              _buildDialogDistributionRow(
                'Себе',
                _settings.personalFundPercent,
                _distributionAmount(amount, _settings.personalFundPercent),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Понятно'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogDistributionRow(
    String title,
    double percent,
    double amount,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$title · ${percent.toStringAsFixed(
              percent == percent.roundToDouble() ? 0 : 1,
            )}%',
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            _formatMoney(amount),
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Future<void> _showPaymentHistory(Order order) async {
    final orderId = order.id;
    if (orderId == null) return;

    final payments = await _repository.getPayments(orderId);
    if (!mounted) return;

    await showAdaptiveDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog.adaptive(
          title: const Text('История оплат'),
          content: SizedBox(
            width: double.maxFinite,
            child: payments.isEmpty
                ? const Text('Оплат пока нет.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      final amount =
                          (payment['amount'] as num?)?.toDouble() ?? 0;
                      final paidAt = DateTime.tryParse(
                        payment['paid_at']?.toString() ?? '',
                      );
                      final dateText = paidAt == null
                          ? ''
                          : '${paidAt.day.toString().padLeft(2, '0')}.'
                              '${paidAt.month.toString().padLeft(2, '0')}.'
                              '${paidAt.year} '
                              '${paidAt.hour.toString().padLeft(2, '0')}:'
                              '${paidAt.minute.toString().padLeft(2, '0')}';
                      final note = payment['note']?.toString();

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.payments_outlined),
                        title: Text(
                          _formatMoney(amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (dateText.isNotEmpty) dateText,
                            if (note != null && note.trim().isNotEmpty) note,
                          ].join('\n'),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _restoreOrder(Order order) async {
    final orderId = order.id;

    if (orderId == null) {
      return;
    }

    await _repository.restorePlanned(orderId);
    await _loadOrders();
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog.adaptive(
          title: const Text('Отменить заказ?'),
          content: Text(
            'Заказ «${order.title}» останется в истории, '
                'но доход по нему учитываться не будет.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Назад'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Отменить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || order.id == null) {
      return;
    }

    await _repository.markCancelled(order.id!);
    await _loadOrders();
  }

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(0)} ₽';
  }

  Widget _buildEmptyCard() {
    return BusCard(
      onTap: _openAddOrderScreen,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.local_taxi,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Заказы',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text('Добавить заказ'),
              ],
            ),
          ),
          const Icon(Icons.add_circle_outline),
        ],
      ),
    );
  }

  Widget _buildCompactDistributionRow(
    IconData icon,
    String title,
    double percent,
    double amount,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$title · ${percent.toStringAsFixed(
              percent == percent.roundToDouble() ? 0 : 1,
            )}%',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _formatMoney(amount),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _paymentStatus(Order order) {
    late final String text;
    late final IconData icon;
    late final Color color;

    if (order.isFullyPaid) {
      text = 'Оплачено полностью';
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (order.isPartiallyPaid) {
      text =
          'Получено ${_formatMoney(order.paidAmount)}, осталось ${_formatMoney(order.remainingAmount)}';
      icon = Icons.timelapse;
      color = Colors.orange;
    } else {
      text = 'Не оплачено · долг ${_formatMoney(order.amount)}';
      icon = Icons.schedule;
      color = Colors.orange;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Order order) {
    Color? backgroundColor;

    if (order.isCompleted) {
      backgroundColor = Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.45);
    }

    if (order.isCancelled) {
      backgroundColor =
          Theme.of(context).colorScheme.surfaceContainerHighest;
    }

    return BusCard(
      backgroundColor: backgroundColor,
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
                  color: order.isCancelled
                      ? Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      : Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  order.isCancelled
                      ? Icons.block
                      : Icons.local_taxi,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        decoration: order.isCancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${order.time} · ${order.quantityText}',
                    ),
                  ],
                ),
              ),
              Text(
                _formatMoney(order.amount),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (order.isCompleted)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Заказ выполнен',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _paymentStatus(order),
                if (order.paidAmount > 0) ...[
                  const Divider(height: 24),
                  Text(
                    'Распределено из фактически полученных денег',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  _buildCompactDistributionRow(
                    Icons.directions_bus_outlined,
                    'На машину',
                    _settings.workFundPercent,
                    _distributionAmount(
                      order.paidAmount,
                      _settings.workFundPercent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_credits.isEmpty)
                    _buildCompactDistributionRow(
                      Icons.account_balance_outlined,
                      'На кредит',
                      _settings.loanFundPercent,
                      _distributionAmount(
                        order.paidAmount,
                        _settings.loanFundPercent,
                      ),
                    )
                  else
                    for (final credit in _credits.where(
                      (credit) => !credit.archived && !credit.isClosed,
                    )) ...[
                      _buildCompactDistributionRow(
                        Icons.account_balance_outlined,
                        credit.title,
                        credit.incomePercent,
                        _distributionAmount(
                          order.paidAmount,
                          credit.incomePercent,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  if (_credits.isEmpty) const SizedBox(height: 8),
                  _buildCompactDistributionRow(
                    Icons.person_outline,
                    'Себе',
                    _settings.personalFundPercent,
                    _distributionAmount(
                      order.paidAmount,
                      _settings.personalFundPercent,
                    ),
                  ),
                ],
                if (order.paidAmount > 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _showPaymentHistory(order),
                      icon: const Icon(Icons.history),
                      label: const Text('История оплат'),
                    ),
                  ),
                ],
                if (!order.isFullyPaid) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _showPaymentDialog(order),
                      icon: const Icon(Icons.add_card),
                      label: const Text('Добавить оплату'),
                    ),
                  ),
                ],
              ],
            )
          else if (order.isCancelled)
            Row(
              children: [
                const Icon(Icons.cancel_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Заказ отменён',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _restoreOrder(order);
                  },
                  child: const Text('Вернуть'),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _cancelOrder(order);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Отменить'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      _markCompleted(order);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Выполнен'),
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

    if (_orders.isEmpty) {
      return _buildEmptyCard();
    }

    return Column(
      children: [
        for (final order in _orders) ...[
          _buildOrderCard(order),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openAddOrderScreen,
            icon: const Icon(Icons.add),
            label: const Text('Ещё заказ'),
          ),
        ),
      ],
    );
  }
}

class _PaymentDialogResult {
  const _PaymentDialogResult({
    required this.amount,
    this.note,
  });

  final double amount;
  final String? note;
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.order,
    required this.firstPayment,
    required this.formatMoney,
  });

  final Order order;
  final bool firstPayment;
  final String Function(double value) formatMoney;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController(
      text: widget.firstPayment
          ? widget.order.remainingAmount.toStringAsFixed(0)
          : '',
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    final note = _noteController.text.trim();

    Navigator.of(context).pop(
      _PaymentDialogResult(
        amount: amount,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text(
        widget.firstPayment
            ? 'Оплата за выполненный заказ'
            : 'Добавить оплату',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Стоимость заказа: '
                '${widget.formatMoney(widget.order.amount)}',
              ),
              Text(
                'Уже получено: '
                '${widget.formatMoney(widget.order.paidAmount)}',
              ),
              Text(
                'Осталось: '
                '${widget.formatMoney(widget.order.remainingAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Получено сейчас',
                  suffixText: '₽',
                  border: OutlineInputBorder(),
                ),
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
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  hintText: 'Например: наличными, перевод',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.firstPayment)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Оплатят позже'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Сохранить оплату'),
        ),
      ],
    );
  }
}

