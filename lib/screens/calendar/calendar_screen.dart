import 'package:flutter/material.dart';

import '../../repositories/report_repository.dart';
import '../../widgets/bus_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final ReportRepository _repository = ReportRepository.instance;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, DayEvents> _events = {};
  bool _isLoading = true;

  static const _monthNames = <String>[
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final events = await _repository.getMonthEvents(_month);
      if (!mounted) return;
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить календарь: $error')),
      );
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
    });
    _load();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }

  Future<void> _showDay(DateTime date) async {
    final data = await _repository.getDayEvents(date);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Text(
                    '${date.day} ${_monthNames[date.month - 1].toLowerCase()} ${date.year}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (!data.hasTrips &&
                      !data.hasOrders &&
                      !data.hasFuel &&
                      !data.hasExpenses &&
                      !data.hasMileage)
                    const BusCard(
                      child: Text('На этот день записей нет.'),
                    ),
                  for (final trip in data.trips)
                    _eventTile(
                      Icons.directions_bus,
                      trip['title']?.toString() ?? 'Рейс',
                      '${trip['completed'] == 1 ? 'Выполнен' : 'Не выполнен'} · ${_money(trip['price'])}',
                    ),
                  for (final order in data.orders)
                    _eventTile(
                      Icons.local_taxi,
                      order['title']?.toString() ?? 'Заказ',
                      '${order['time'] ?? ''} · ${_orderStatus(order['status'])} · ${_money(order['amount'])}',
                    ),
                  for (final fuel in data.fuelLogs)
                    _eventTile(
                      Icons.local_gas_station,
                      'Заправка',
                      '${_number(fuel['liters'])} л · ${_money(fuel['total'])}',
                    ),
                  for (final expense in data.expenses)
                    _eventTile(
                      Icons.receipt_long,
                      expense['category']?.toString() ?? 'Расход',
                      _money(expense['amount']),
                    ),
                  if (data.distance != null)
                    _eventTile(
                      Icons.speed,
                      'Пробег за день',
                      '${data.distance} км',
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _eventTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BusCard(
        padding: const EdgeInsets.all(12),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      ),
    );
  }

  String _money(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return '${number.toStringAsFixed(0)} ₽';
  }

  String _number(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return number == number.roundToDouble()
        ? number.toStringAsFixed(0)
        : number.toStringAsFixed(1);
  }

  String _orderStatus(Object? status) {
    switch (status) {
      case 'completed':
        return 'Выполнен';
      case 'cancelled':
        return 'Отменён';
      default:
        return 'Запланирован';
    }
  }

  Widget _dayCell(DateTime? date) {
    if (date == null) return const SizedBox.shrink();

    final data = _events[_dateKey(date)];
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showDay(date),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _isToday(date) ? colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isToday(date)
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: _isToday(date) ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 14,
              child: FittedBox(
                alignment: Alignment.bottomLeft,
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data?.hasTrips == true)
                      const Icon(Icons.directions_bus, size: 13),
                    if (data?.hasOrders == true)
                      const Icon(Icons.local_taxi, size: 13),
                    if (data?.hasFuel == true)
                      const Icon(Icons.local_gas_station, size: 13),
                    if (data?.hasExpenses == true)
                      const Icon(Icons.receipt_long, size: 13),
                    if (data?.hasMileage == true)
                      const Icon(Icons.speed, size: 13),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DateTime?> _monthDays() {
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final result = <DateTime?>[
      ...List<DateTime?>.filled(leading, null),
      for (var day = 1; day <= days; day++)
        DateTime(_month.year, _month.month, day),
    ];
    while (result.length % 7 != 0) {
      result.add(null);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final days = _monthDays();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Календарь',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            BusCard(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthNames[_month.month - 1]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: Text('Пн', textAlign: TextAlign.center)),
                Expanded(child: Text('Вт', textAlign: TextAlign.center)),
                Expanded(child: Text('Ср', textAlign: TextAlign.center)),
                Expanded(child: Text('Чт', textAlign: TextAlign.center)),
                Expanded(child: Text('Пт', textAlign: TextAlign.center)),
                Expanded(child: Text('Сб', textAlign: TextAlign.center)),
                Expanded(child: Text('Вс', textAlign: TextAlign.center)),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) => _dayCell(days[index]),
              ),
            const SizedBox(height: 16),
            const BusCard(
              child: Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  _Legend(Icons.directions_bus, 'Рейсы'),
                  _Legend(Icons.local_taxi, 'Заказы'),
                  _Legend(Icons.local_gas_station, 'Топливо'),
                  _Legend(Icons.receipt_long, 'Расходы'),
                  _Legend(Icons.speed, 'Пробег'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}
