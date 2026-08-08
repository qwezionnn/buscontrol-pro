import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/trip.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../repositories/fuel_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../widgets/bus_card.dart';
import '../expenses/add_expense_screen.dart';
import '../fuel/add_fuel_screen.dart';
import '../orders/add_order_screen.dart';
import '../orders/order_payment_screen.dart';
import '../trips/add_extra_trip_screen.dart';

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
      // Убираем автоматически созданные невыполненные обычные рейсы
      // с суббот и воскресений текущего месяца.
      final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
      for (var day = 1; day <= daysInMonth; day++) {
        final date = DateTime(_month.year, _month.month, day);
        if (date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday) {
          await TripRepository.instance.ensureStandardTrips(date);
        }
      }

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

  Future<void> _openForDate(
    DateTime date,
    Widget screen,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _showAddMenu(DateTime date) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Добавить на ${date.day.toString().padLeft(2, '0')}.'
                '${date.month.toString().padLeft(2, '0')}.${date.year}',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              if (date.weekday != DateTime.saturday &&
                  date.weekday != DateTime.sunday) ...[
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Утренний рейс'),
                  subtitle: const Text('Добавить обычный утренний рейс'),
                  onTap: () => Navigator.pop(sheetContext, 'morning_trip'),
                ),
                ListTile(
                  leading: const Icon(Icons.nightlight_outlined),
                  title: const Text('Вечерний рейс'),
                  subtitle: const Text('Добавить обычный вечерний рейс'),
                  onTap: () => Navigator.pop(sheetContext, 'evening_trip'),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.add_road),
                title: const Text('Дополнительный рейс'),
                onTap: () => Navigator.pop(sheetContext, 'trip'),
              ),
              ListTile(
                leading: const Icon(Icons.local_taxi),
                title: const Text('Заказ'),
                onTap: () => Navigator.pop(sheetContext, 'order'),
              ),
              ListTile(
                leading: const Icon(Icons.local_gas_station),
                title: const Text('Заправка'),
                onTap: () => Navigator.pop(sheetContext, 'fuel'),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Расход'),
                onTap: () => Navigator.pop(sheetContext, 'expense'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'morning_trip':
        await TripRepository.instance.addStandardTrip(
          date: date,
          type: TripType.morning,
        );
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Утренний рейс добавлен. Нажмите на него, чтобы отметить выполненным.'),
            ),
          );
        }
        break;
      case 'evening_trip':
        await TripRepository.instance.addStandardTrip(
          date: date,
          type: TripType.evening,
        );
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Вечерний рейс добавлен. Нажмите на него, чтобы отметить выполненным.'),
            ),
          );
        }
        break;
      case 'trip':
        await _openForDate(
          date,
          AddExtraTripScreen(initialDate: date),
        );
        break;
      case 'order':
        await _openForDate(
          date,
          AddOrderScreen(initialDate: date),
        );
        break;
      case 'fuel':
        await _openForDate(
          date,
          AddFuelScreen(initialDate: date),
        );
        break;
      case 'expense':
        await _openForDate(
          date,
          AddExpenseScreen(initialDate: date),
        );
        break;
    }
  }

  Future<void> _editOrderFromCalendar(
    Map<String, Object?> row,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddOrderScreen(
          order: Order.fromMap(row),
        ),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _showOrderActions(
    Map<String, Object?> row,
  ) async {
    var order = Order.fromMap(row);

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Редактировать'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            if (order.isPlanned)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Отметить выполненным'),
                onTap: () => Navigator.pop(sheetContext, 'complete'),
              ),
            if (order.isCompleted && !order.isFullyPaid)
              ListTile(
                leading: const Icon(Icons.add_card),
                title: const Text('Добавить оплату'),
                onTap: () => Navigator.pop(sheetContext, 'payment'),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Удалить заказ',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      await _editOrderFromCalendar(row);
      return;
    }

    if (action == 'delete' && order.id != null) {
      final confirmed = await _confirmDelete(
        title: 'Удалить заказ?',
        message:
            'Заказ «${order.title}» и все связанные с ним оплаты будут удалены.',
      );
      if (confirmed) {
        await OrderRepository.instance.deleteOrder(order.id!);
        await _load();
      }
      return;
    }

    if (action == 'complete' && order.id != null) {
      await OrderRepository.instance.markCompleted(order.id!);
      order = order.copyWith(status: OrderStatus.completed);
      if (!mounted) return;

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OrderPaymentScreen(order: order),
        ),
      );
      if (mounted) {
        await _load();
      }
      return;
    }

    if (action == 'payment') {
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OrderPaymentScreen(order: order),
        ),
      );
      if (paid == true) {
        await _load();
      }
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showTripActions(Map<String, Object?> row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;

    final type = row['type']?.toString() ?? '';
    final completed = row['completed'] == 1;
    final isExtra = type == 'extra';

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                completed
                    ? Icons.radio_button_unchecked
                    : Icons.check_circle_outline,
              ),
              title: Text(
                completed
                    ? 'Отметить не выполненным'
                    : 'Отметить выполненным',
              ),
              onTap: () => Navigator.pop(sheetContext, 'toggle'),
            ),
            if (isExtra) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Удалить рейс',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ],
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'toggle') {
      await TripRepository.instance.setCompleted(
        tripId: id,
        completed: !completed,
      );
      await _load();
      return;
    }

    if (action == 'delete' && isExtra) {
      final confirmed = await _confirmDelete(
        title: 'Удалить рейс?',
        message:
            'Дополнительный рейс «${row['title'] ?? 'Рейс'}» будет удалён.',
      );
      if (!confirmed) return;
      await TripRepository.instance.deleteExtraTrip(id);
      await _load();
    }
  }

  Future<void> _showFuelActions(Map<String, Object?> row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Удалить заправку',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action != 'delete') return;

    final confirmed = await _confirmDelete(
      title: 'Удалить заправку?',
      message:
          'Заправка на ${_number(row['liters'])} л (${_money(row['total'])}) будет удалена.',
    );
    if (!confirmed) return;

    await FuelRepository.instance.deleteFuelLog(id);
    await _load();
  }

  Future<void> _showExpenseActions(Map<String, Object?> row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Удалить расход',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action != 'delete') return;

    final confirmed = await _confirmDelete(
      title: 'Удалить расход?',
      message:
          'Расход «${row['category'] ?? 'Расход'}» на сумму ${_money(row['amount'])} будет удалён.',
    );
    if (!confirmed) return;

    await ExpenseRepository.instance.deleteExpense(id);
    await _load();
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Future<void>.delayed(
                          const Duration(milliseconds: 120),
                          () => _showAddMenu(date),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить запись'),
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
                      onTap: () {
                        Navigator.pop(context);
                        Future<void>.delayed(
                          const Duration(milliseconds: 120),
                          () => _showTripActions(trip),
                        );
                      },
                      trailing: const Icon(Icons.more_horiz),
                    ),
                  for (final order in data.orders)
                    _eventTile(
                      Icons.local_taxi,
                      order['title']?.toString() ?? 'Заказ',
                      '${order['time'] ?? ''} · ${_orderStatus(order['status'])} · ${_money(order['amount'])}',
                      onTap: () {
                        Navigator.pop(context);
                        Future<void>.delayed(
                          const Duration(milliseconds: 120),
                          () => _showOrderActions(order),
                        );
                      },
                      trailing: const Icon(Icons.more_horiz),
                    ),
                  for (final fuel in data.fuelLogs)
                    _eventTile(
                      Icons.local_gas_station,
                      'Заправка',
                      '${_number(fuel['liters'])} л · ${_money(fuel['total'])}',
                      onTap: () {
                        Navigator.pop(context);
                        Future<void>.delayed(
                          const Duration(milliseconds: 120),
                          () => _showFuelActions(fuel),
                        );
                      },
                      trailing: const Icon(Icons.more_horiz),
                    ),
                  for (final expense in data.expenses)
                    _eventTile(
                      Icons.receipt_long,
                      expense['category']?.toString() ?? 'Расход',
                      _money(expense['amount']),
                      onTap: () {
                        Navigator.pop(context);
                        Future<void>.delayed(
                          const Duration(milliseconds: 120),
                          () => _showExpenseActions(expense),
                        );
                      },
                      trailing: const Icon(Icons.more_horiz),
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

  Widget _eventTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BusCard(
        padding: const EdgeInsets.all(12),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: trailing,
          onTap: onTap,
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
      onLongPress: () => _showAddMenu(date),
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
