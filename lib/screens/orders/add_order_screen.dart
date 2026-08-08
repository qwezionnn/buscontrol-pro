import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../models/order.dart';
import '../../models/credit.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/credit_repository.dart';

enum OrderFormType {
  hourly,
  intercity,
  fixed,
}

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({
    super.key,
    this.initialDate,
    this.order,
  });

  final DateTime? initialDate;
  final Order? order;

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _quantityController = TextEditingController();
  final _rateController = TextEditingController();
  final _noteController = TextEditingController();

  final OrderRepository _orderRepository = OrderRepository.instance;
  final SettingsRepository _settingsRepository =
      SettingsRepository.instance;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  OrderFormType _type = OrderFormType.hourly;

  bool _isLoading = true;
  bool _isSaving = false;

  double _hourlyRate = 2000;
  double _intercityRate = 55;
  int _reminderHours = 12;
  AppSettings _settings = AppSettings.defaults();
  List<Credit> _credits = const [];

  double get _quantity {
    return double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    ) ??
        0;
  }

  double get _rate {
    return double.tryParse(
      _rateController.text.trim().replaceAll(',', '.'),
    ) ??
        0;
  }

  double get _amount =>
      _type == OrderFormType.fixed ? _rate : _quantity * _rate;

  double get _workFundAmount =>
      _amount * _settings.workFundPercent / 100;

  double get _loanFundAmount => _credits.isEmpty
      ? _amount * _settings.loanFundPercent / 100
      : _credits
          .where((credit) => !credit.archived && !credit.isClosed)
          .fold<double>(
            0,
            (sum, credit) => sum + _amount * credit.incomePercent / 100,
          );

  double get _personalFundAmount =>
      _amount * _settings.personalFundPercent / 100;

  @override
  void initState() {
    super.initState();
    final initialDate = widget.initialDate;
    if (initialDate != null) {
      _selectedDate = DateTime(initialDate.year, initialDate.month, initialDate.day);
    }

    final order = widget.order;
    if (order != null) {
      _titleController.text = order.title;
      _noteController.text = order.note ?? '';
      _selectedDate = DateTime.tryParse(order.date) ?? _selectedDate;
      final timeParts = order.time.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        if (hour != null && minute != null) {
          _selectedTime = TimeOfDay(hour: hour, minute: minute);
        }
      }

      if (order.type == OrderType.hourly) {
        _type = OrderFormType.hourly;
        _quantityController.text = _formatNumber(order.hours ?? 0);
        _rateController.text = _formatNumber(order.rate);
      } else if (order.type == OrderType.intercity) {
        _type = OrderFormType.intercity;
        _quantityController.text = _formatNumber(order.kilometers ?? 0);
        _rateController.text = _formatNumber(order.rate);
      } else {
        _type = OrderFormType.fixed;
        _rateController.text = _formatNumber(order.amount);
      }
    }

    _loadDefaults();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    try {
      final settings = await _settingsRepository.getSettings();
      final credits = await CreditRepository.instance.getCredits();

      if (!mounted) {
        return;
      }

      _settings = settings;
      _credits = credits;
      _hourlyRate = settings.hourlyOrderRate;
      _intercityRate = settings.intercityOrderRate;
      _reminderHours = settings.orderReminderHours;

      if (widget.order == null) {
        _rateController.text = _formatNumber(_hourlyRate);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (widget.order == null) {
        _rateController.text = _formatNumber(_hourlyRate);
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось загрузить ставки: $error',
          ),
        ),
      );
    }
  }

  String _databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  String _databaseTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(0)} ₽';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  void _changeType(OrderFormType type) {
    setState(() {
      _type = type;

      if (_type == OrderFormType.hourly) {
        _rateController.text = _formatNumber(_hourlyRate);
      } else if (_type == OrderFormType.intercity) {
        _rateController.text = _formatNumber(_intercityRate);
      } else {
        _rateController.clear();
      }
      if (_type == OrderFormType.fixed) {
        _quantityController.clear();
      }
    });
  }

  Future<void> _selectDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedDate = result;
    });
  }

  Future<void> _selectTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedTime = result;
    });
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final order = Order(
        title: _titleController.text.trim(),
        date: _databaseDate(_selectedDate),
        time: _databaseTime(_selectedTime),
        type: switch (_type) {
          OrderFormType.hourly => OrderType.hourly,
          OrderFormType.intercity => OrderType.intercity,
          OrderFormType.fixed => OrderType.fixed,
        },
        hours: _type == OrderFormType.hourly ? _quantity : null,
        kilometers: _type == OrderFormType.intercity ? _quantity : null,
        rate: _rate,
        amount: _amount,
        reminderHours: _reminderHours,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (widget.order != null && _amount + 0.001 < widget.order!.paidAmount) {
        throw StateError(
          'Новая стоимость заказа меньше уже полученной оплаты '
          '(${_formatMoney(widget.order!.paidAmount)}).',
        );
      }

      if (widget.order?.id != null) {
        await _orderRepository.updateOrder(
          order.copyWith(
            id: widget.order!.id,
            status: widget.order!.status,
            paid: widget.order!.paid,
            paidAmount: widget.order!.paidAmount,
          ),
        );
      } else {
        await _orderRepository.addOrder(order);
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось сохранить заказ: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildDistributionRow({
    required String title,
    required double percent,
    required double amount,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$title · ${_formatNumber(percent)}%',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          _formatMoney(amount),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final quantityLabel = _type == OrderFormType.hourly
        ? 'Количество часов'
        : 'Расстояние';

    final quantitySuffix = _type == OrderFormType.hourly ? 'ч' : 'км';

    final rateLabel = switch (_type) {
      OrderFormType.hourly => 'Цена за час',
      OrderFormType.intercity => 'Цена за километр',
      OrderFormType.fixed => 'Фиксированная сумма заказа',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order == null ? 'Новый заказ' : 'Редактировать заказ'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                textCapitalization:
                TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название заказа',
                  hintText: 'Например: Аэропорт',
                  prefixIcon: Icon(Icons.local_taxi),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Введите название заказа';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              SegmentedButton<OrderFormType>(
                segments: const [
                  ButtonSegment(
                    value: OrderFormType.hourly,
                    icon: Icon(Icons.schedule),
                    label: Text('Часы'),
                  ),
                  ButtonSegment(
                    value: OrderFormType.intercity,
                    icon: Icon(Icons.route),
                    label: Text('Межгород'),
                  ),
                  ButtonSegment(
                    value: OrderFormType.fixed,
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Фикс.'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) {
                  _changeType(selection.first);
                },
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(
                        Icons.calendar_month,
                      ),
                      label: Text(
                        _formatDate(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectTime,
                      icon: const Icon(
                        Icons.access_time,
                      ),
                      label: Text(
                        _selectedTime.format(context),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (_type != OrderFormType.fixed) ...[
                TextFormField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: quantityLabel,
                    suffixText: quantitySuffix,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                  validator: (value) {
                    final number = double.tryParse(
                      (value ?? '').replaceAll(',', '.'),
                    );

                    if (number == null || number <= 0) {
                      return 'Введите значение больше нуля';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _rateController,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: rateLabel,
                  suffixText: '₽',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {});
                },
                validator: (value) {
                  final number = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );

                  if (number == null || number <= 0) {
                    return _type == OrderFormType.fixed
                        ? 'Введите сумму больше нуля'
                        : 'Введите тариф больше нуля';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  hintText: 'Необязательно',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Итого',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatMoney(_amount),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined),
                          SizedBox(width: 10),
                          Text(
                            'Предварительное распределение',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Расчёт по процентам из настроек. '
                        'В доход распределение попадёт после '
                        'отметки заказа «Выполнен».',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(height: 24),
                      _buildDistributionRow(
                        title: 'На машину',
                        percent: _settings.workFundPercent,
                        amount: _workFundAmount,
                        icon: Icons.build_outlined,
                      ),
                      const SizedBox(height: 12),
                      if (_credits.isEmpty)
                        _buildDistributionRow(
                          title: 'На кредит',
                          percent: _settings.loanFundPercent,
                          amount: _loanFundAmount,
                          icon: Icons.credit_card,
                        )
                      else
                        for (final credit in _credits.where(
                          (credit) => !credit.archived && !credit.isClosed,
                        )) ...[
                          _buildDistributionRow(
                            title: credit.title,
                            percent: credit.incomePercent,
                            amount:
                                _amount * credit.incomePercent / 100,
                            icon: Icons.credit_card,
                          ),
                          const SizedBox(height: 12),
                        ],
                      if (_credits.isEmpty) const SizedBox(height: 12),
                      _buildDistributionRow(
                        title: 'Себе',
                        percent: _settings.personalFundPercent,
                        amount: _personalFundAmount,
                        icon: Icons.person_outline,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Напоминание: за $_reminderHours ч',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),

              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed:
                _isSaving ? null : _saveOrder,
                icon: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'Сохраняем...'
                      : (widget.order == null
                          ? 'Сохранить заказ'
                          : 'Сохранить изменения'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}