import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/app_settings.dart';
import '../../repositories/settings_repository.dart';
import '../../widgets/bus_card.dart';

enum FinanceDetailType {
  trips,
  orders,
  fuel,
}

class FinanceDetailScreen extends StatefulWidget {
  const FinanceDetailScreen({
    super.key,
    required this.month,
    required this.type,
  });

  final DateTime month;
  final FinanceDetailType type;

  @override
  State<FinanceDetailScreen> createState() =>
      _FinanceDetailScreenState();
}

class _FinanceDetailScreenState extends State<FinanceDetailScreen> {
  final DatabaseHelper _database = DatabaseHelper.instance;
  final SettingsRepository _settingsRepository =
      SettingsRepository.instance;

  List<Map<String, Object?>> _items = [];
  AppSettings _settings = AppSettings.defaults();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDate(String value) {
    final parts = value.split('-');

    if (parts.length != 3) {
      return value;
    }

    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  String _money(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return '${number.toStringAsFixed(0)} ₽';
  }

  String _number(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;

    if (number == number.roundToDouble()) {
      return number.toStringAsFixed(0);
    }

    return number.toStringAsFixed(1);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final from = _databaseDate(
        DateTime(widget.month.year, widget.month.month),
      );
      final to = _databaseDate(
        DateTime(widget.month.year, widget.month.month + 1, 0),
      );

      final settings = await _settingsRepository.getSettings();

      List<Map<String, Object?>> rows;

      switch (widget.type) {
        case FinanceDetailType.trips:
          final allTrips = await _database.getTripsBetween(from, to);
          rows = allTrips
              .where((trip) => trip['completed'] == 1)
              .toList();
          break;

        case FinanceDetailType.orders:
          rows = await _database.getOrdersBetween(from, to);
          break;

        case FinanceDetailType.fuel:
          rows = await _database.getFuelLogsBetween(from, to);
          break;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _items = rows;
        _settings = settings;
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
          content: Text('Не удалось загрузить историю: $error'),
        ),
      );
    }
  }

  String get _title {
    switch (widget.type) {
      case FinanceDetailType.trips:
        return 'История рейсов';
      case FinanceDetailType.orders:
        return 'История заказов';
      case FinanceDetailType.fuel:
        return 'История заправок';
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case FinanceDetailType.trips:
        return Icons.directions_bus;
      case FinanceDetailType.orders:
        return Icons.local_taxi;
      case FinanceDetailType.fuel:
        return Icons.local_gas_station;
    }
  }

  String get _emptyText {
    switch (widget.type) {
      case FinanceDetailType.trips:
        return 'В этом месяце выполненных рейсов нет.';
      case FinanceDetailType.orders:
        return 'В этом месяце заказов нет.';
      case FinanceDetailType.fuel:
        return 'В этом месяце заправок нет.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BusCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_icon),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _monthTitle(widget.month),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${_items.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (!_isLoading &&
                  widget.type == FinanceDetailType.orders)
                _buildOrderDistributionSummary(),
              if (!_isLoading &&
                  widget.type == FinanceDetailType.orders)
                const SizedBox(height: 14),
              if (!_isLoading &&
                  widget.type == FinanceDetailType.fuel)
                _buildFuelSummary(),
              if (!_isLoading &&
                  widget.type == FinanceDetailType.fuel)
                const SizedBox(height: 14),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_items.isEmpty)
                BusCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                    ),
                    child: Center(
                      child: Text(
                        _emptyText,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                for (var index = 0;
                    index < _items.length;
                    index++) ...[
                  _buildItem(_items[index]),
                  if (index != _items.length - 1)
                    const SizedBox(height: 12),
                ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFuelSummary() {
    final totalLiters = _items.fold<double>(
      0,
      (sum, item) =>
          sum + ((item['liters'] as num?)?.toDouble() ?? 0),
    );
    final totalCost = _items.fold<double>(
      0,
      (sum, item) =>
          sum + ((item['total'] as num?)?.toDouble() ?? 0),
    );

    return BusCard(
      backgroundColor: Theme.of(context)
          .colorScheme
          .secondaryContainer
          .withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_gas_station),
              SizedBox(width: 10),
              Text(
                'Топливо за месяц',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDistributionSummaryRow(
            'Заправлено',
            0,
            totalLiters,
            valueSuffix: ' л',
          ),
          const SizedBox(height: 10),
          _buildDistributionSummaryRow(
            'Оплачено из фонда автобуса',
            0,
            totalCost,
          ),
          const SizedBox(height: 8),
          const Text(
            'Расходы на топливо уменьшают только фонд автобуса '
            'и не вычитаются из личной части.',
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDistributionSummary() {
    final total = _items.fold<double>(
      0,
      (sum, item) =>
          sum + ((item['paid_amount'] as num?)?.toDouble() ?? 0),
    );

    final work = total * _settings.workFundPercent / 100;
    final loan = total * _settings.loanFundPercent / 100;
    final personal = total * _settings.personalFundPercent / 100;

    return BusCard(
      backgroundColor: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_balance_wallet_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Распределение полученных оплат',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Фактически получено за месяц: ${_money(total)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Divider(height: 24),
          _buildDistributionSummaryRow(
            'На машину',
            _settings.workFundPercent,
            work,
          ),
          const SizedBox(height: 10),
          _buildDistributionSummaryRow(
            'На кредит',
            _settings.loanFundPercent,
            loan,
          ),
          const SizedBox(height: 10),
          _buildDistributionSummaryRow(
            'Себе',
            _settings.personalFundPercent,
            personal,
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionSummaryRow(
    String title,
    double percent,
    double amount, {
    String? valueSuffix,
  }) {
    final percentText = percent.toStringAsFixed(
      percent == percent.roundToDouble() ? 0 : 1,
    );
    final titleText = percent > 0
        ? '$title · $percentText%'
        : title;
    final valueText = valueSuffix == null
        ? _money(amount)
        : '${_number(amount)}$valueSuffix';

    return Row(
      children: [
        Expanded(
          child: Text(titleText),
        ),
        Text(
          valueText,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildItem(Map<String, Object?> item) {
    switch (widget.type) {
      case FinanceDetailType.trips:
        return _buildTrip(item);
      case FinanceDetailType.orders:
        return _buildOrder(item);
      case FinanceDetailType.fuel:
        return _buildFuel(item);
    }
  }

  Widget _buildTrip(Map<String, Object?> trip) {
    final type = trip['type']?.toString() ?? '';
    final time = trip['time']?.toString();
    final isExtra = type == 'extra';

    final subtitleParts = <String>[
      _formatDate(trip['date']?.toString() ?? ''),
      if (time != null && time.isNotEmpty) time,
      isExtra ? 'Дополнительный рейс' : 'Стандартный рейс',
    ];

    return BusCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isExtra ? Icons.add_road : Icons.directions_bus,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip['title']?.toString() ?? 'Рейс',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(subtitleParts.join(' · ')),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _money(trip['price']),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrder(Map<String, Object?> order) {
    final status = order['status']?.toString() ?? 'planned';
    final type = order['type']?.toString() ?? 'hourly';
    final time = order['time']?.toString() ?? '';

    final quantity = type == 'intercity'
        ? '${_number(order['kilometers'])} км'
        : '${_number(order['hours'])} ч';

    return BusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.local_taxi,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['title']?.toString() ?? 'Заказ',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        _formatDate(
                          order['date']?.toString() ?? '',
                        ),
                        if (time.isNotEmpty) time,
                        quantity,
                      ].join(' · '),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _money(order['amount']),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statusChip(status),
          if (status == 'completed') ...[
            const SizedBox(height: 10),
            _paymentSummary(order),
          ],
        ],
      ),
    );
  }

  Widget _paymentSummary(Map<String, Object?> order) {
    final amount = (order['amount'] as num?)?.toDouble() ?? 0;
    final paid = (order['paid_amount'] as num?)?.toDouble() ?? 0;
    final remaining = (amount - paid).clamp(0, double.infinity);

    late final String label;
    late final IconData icon;
    if (remaining <= 0.001) {
      label = 'Оплачено полностью: ${_money(paid)}';
      icon = Icons.check_circle_outline;
    } else if (paid > 0.001) {
      label =
          'Получено ${_money(paid)} · осталось ${_money(remaining)}';
      icon = Icons.timelapse;
    } else {
      label = 'Не оплачено · долг ${_money(amount)}';
      icon = Icons.schedule;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    late final String label;
    late final IconData icon;

    switch (status) {
      case 'completed':
        label = 'Выполнен';
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        label = 'Отменён';
        icon = Icons.cancel_outlined;
        break;
      default:
        label = 'Запланирован';
        icon = Icons.schedule;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFuel(Map<String, Object?> fuel) {
    final time = fuel['time']?.toString();
    final mileage = (fuel['mileage'] as num?)?.toInt();
    final note = fuel['note']?.toString();

    return BusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.local_gas_station,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_number(fuel['liters'])} л',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        _formatDate(
                          fuel['date']?.toString() ?? '',
                        ),
                        if (time != null && time.isNotEmpty) time,
                        '${_number(fuel['price_per_liter'])} ₽/л',
                      ].join(' · '),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _money(fuel['total']),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (mileage != null || (note != null && note.isNotEmpty)) ...[
            const SizedBox(height: 12),
            if (mileage != null)
              Text('Пробег при заправке: $mileage км'),
            if (note != null && note.isNotEmpty) ...[
              if (mileage != null) const SizedBox(height: 5),
              Text('Комментарий: $note'),
            ],
          ],
        ],
      ),
    );
  }

  String _monthTitle(DateTime month) {
    const names = <String>[
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    return '${names[month.month - 1]} ${month.year}';
  }
}
