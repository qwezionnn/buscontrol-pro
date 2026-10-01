import 'dart:convert';

import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/app_settings.dart';
import '../../repositories/financial_assistant_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../services/monthly_report_export_service.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/simple_bar_chart.dart';
import 'finance_detail_screen.dart';
import 'credits_screen.dart';
import 'distribution_calculator_screen.dart';
import 'fund_transfer_screen.dart';
import 'reserve_screen.dart';
import 'notes_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final _reports = ReportRepository.instance;
  final _settings = SettingsRepository.instance;
  final _assistant = FinancialAssistantRepository.instance;
  final _export = MonthlyReportExportService.instance;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  MonthReport? _report;
  AppSettings? _appSettings;
  FinancialSnapshot? _snapshot;
  double _tripIncomeTarget = 0;
  double _monthPayoutTotal = 0;
  List<Map<String, Object?>> _monthPayouts = const [];
  Map<String, double> _personalTransfers = const {};
  bool _loading = true;
  bool _busy = false;
  List<double> _chartValues = const [];
  List<String> _chartLabels = const [];

  static const _months = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await _reports.getMonthReport(_month);
    final settings = await _settings.getSettings();
    final snapshot = await _assistant.getSnapshot(personalMonth: _month);
    final personalTransfers = await _assistant.getPersonalTransferSummary(_month);
    final tripIncomeTarget = await _assistant.getTripIncomeTarget(
      month: _month,
      calculatedAmount: report.tripIncome,
    );
    final monthPayouts = await _assistant.getTripPayoutsForMonth(_month);
    final monthPayoutTotal = monthPayouts.fold<double>(
      0,
      (sum, row) => sum + ((row['gross_amount'] as num?)?.toDouble() ?? 0),
    );

    final values = <double>[];
    final labels = <String>[];
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final events = await _reports.getMonthEvents(_month);
    for (var start = 1; start <= days; start += 7) {
      var total = 0.0;
      final end = (start + 6).clamp(1, days);
      for (var day = start; day <= end; day++) {
        final key =
            '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        final event = events[key];
        if (event == null) continue;
        total += event.trips
            .where((row) => row['completed'] == 1)
            .fold<double>(0, (sum, row) {
              final price = (row['price'] as num?)?.toDouble() ?? 0;
              final waitHours = (row['wait_hours'] as num?)?.toDouble() ?? 0;
              final waitRate = (row['wait_rate'] as num?)?.toDouble() ?? 0;
              return sum + price + waitHours * waitRate;
            });
        total += event.orders
            .where((row) => row['status'] == 'completed')
            .fold<double>(0, (sum, row) =>
                sum + ((row['paid_amount'] as num?)?.toDouble() ?? 0));
      }
      values.add(total);
      labels.add('$start–$end');
    }

    if (!mounted) return;
    setState(() {
      _report = report;
      _appSettings = settings;
      _snapshot = snapshot;
      _personalTransfers = personalTransfers;
      _tripIncomeTarget = tripIncomeTarget;
      _monthPayouts = monthPayouts;
      _monthPayoutTotal = monthPayoutTotal;
      _chartValues = values;
      _chartLabels = labels;
      _loading = false;
    });
  }

  void _changeMonth(int offset) {
    _month = DateTime(_month.year, _month.month + offset);
    _load();
  }

  String _personalTransferLabel(String key) {
    const names = <String, String>{
      'vehicle': 'Автобус',
      'credit': 'Кредит',
      'personal': 'Личные',
      'reserve': 'Заначка',
    };
    final parts = key.split('->');
    if (parts.length != 2) return key;
    return '${names[parts[0]] ?? parts[0]} → ${names[parts[1]] ?? parts[1]}';
  }

  String _money(double value) {
    final sign = value < 0 ? '−' : '';
    return '$sign${value.abs().toStringAsFixed(0)} ₽';
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  Future<void> _receiveTripPayout() async {
    final report = _report;
    if (report == null || _tripIncomeTarget <= 0) return;

    final remaining = (_tripIncomeTarget - _monthPayoutTotal).clamp(0, double.infinity).toDouble();
    final amount = TextEditingController(
      text: (remaining > 0 ? remaining : _tripIncomeTarget).toStringAsFixed(0),
    );
    final vehicle = TextEditingController(text: '30');
    final credit = TextEditingController(text: '35');
    final personal = TextEditingController(text: '25');
    final reserve = TextEditingController(text: '10');
    var amountMode = false;

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Предприятие выплатило'),
        content: StatefulBuilder(
          builder: (context, setLocal) {
            double value(TextEditingController c) =>
                double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
            final total = value(vehicle) + value(credit) + value(personal) + value(reserve);
            final payoutAmount = value(amount);
            final valid = amountMode ? (total - payoutAmount).abs() <= 0.01 : (total - 100).abs() <= 0.01;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<bool>(segments: const [ButtonSegment(value:false,label:Text('% Проценты')),ButtonSegment(value:true,label:Text('₽ Суммы'))], selected:{amountMode}, onSelectionChanged:(v)=>setLocal((){amountMode=v.first;})),
                  const SizedBox(height: 8),
                  Text(
                    remaining > 0
                        ? 'Осталось получить: ${_money(remaining)}. Можно указать всю сумму или только полученную часть.'
                        : 'Вся ожидаемая сумма уже отмечена полученной. При необходимости можно добавить ещё выплату.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Сколько выплатили сейчас', suffixText: '₽')),
                  TextField(controller: vehicle, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}), decoration: InputDecoration(labelText: 'Автобус', suffixText: amountMode ? '₽' : '%')),
                  TextField(controller: credit, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}), decoration: InputDecoration(labelText: 'Кредиты', suffixText: amountMode ? '₽' : '%')),
                  TextField(controller: personal, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}), decoration: InputDecoration(labelText: 'Личные', suffixText: amountMode ? '₽' : '%')),
                  TextField(controller: reserve, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}), decoration: InputDecoration(labelText: 'Заначка', suffixText: amountMode ? '₽' : '%')),
                  const SizedBox(height: 8),
                  Text(amountMode ? 'Распределено: ${total.toStringAsFixed(0)} ₽ из ${payoutAmount.toStringAsFixed(0)} ₽' : 'Итого: ${total.toStringAsFixed(1)}%'),
                  if (!valid)
                    Text(amountMode ? 'Суммы должны быть равны выплате.' : 'Проценты должны составлять ровно 100%.', style: const TextStyle(color: Colors.red)),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              double v(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
              final total = v(vehicle) + v(credit) + v(personal) + v(reserve);
              final a = double.tryParse(amount.text.replaceAll(',', '.'));
              if (a == null || a <= 0) return;
              if (amountMode && (total-a).abs()>0.01) return;
              if (!amountMode && (total-100).abs()>0.01) return;
              double p(TextEditingController c) => amountMode ? (v(c)/a*100) : v(c);
              Navigator.pop(context, {'amount': a, 'vehicle': p(vehicle), 'credit': p(credit), 'personal': p(personal), 'reserve': p(reserve)});
            },
            child: const Text('Сохранить выплату'),
          ),
        ],
      ),
    );

    amount.dispose(); vehicle.dispose(); credit.dispose(); personal.dispose(); reserve.dispose();
    if (result == null) return;
    await _assistant.receiveTripPayout(
      month: _month,
      amount: result['amount']!,
      vehiclePercent: result['vehicle'],
      creditPercent: result['credit'],
      personalPercent: result['personal'],
      reservePercent: result['reserve'],
    );
    await _load();
  }

  Future<void> _editTripIncomeTarget() async {
    final controller = TextEditingController(
      text: _tripIncomeTarget.toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сумма от предприятия'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Укажи сколько предприятие должно выплатить за этот месяц. '
              'Сумму можно менять вручную, например если часть рейсов была на другом автобусе с другой ценой.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Начислено предприятием',
                suffixText: '₽',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(
                controller.text.replaceAll(',', '.').trim(),
              );
              if (value == null || value < 0) return;
              Navigator.pop(context, value);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await _assistant.setTripIncomeTarget(month: _month, amount: result);
    await _load();
  }

  Future<void> _editTripPayout(Map<String, Object?> payout) async {
    final id = (payout['id'] as num?)?.toInt();
    if (id == null) return;
    final amountController = TextEditingController(
      text: ((payout['gross_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
    );
    final vehicleController = TextEditingController(
      text: ((payout['vehicle_percent'] as num?)?.toDouble() ?? 0).toStringAsFixed(1),
    );
    final creditController = TextEditingController(
      text: ((payout['credit_percent'] as num?)?.toDouble() ?? 0).toStringAsFixed(1),
    );
    final personalController = TextEditingController(
      text: ((payout['personal_percent'] as num?)?.toDouble() ?? 0).toStringAsFixed(1),
    );
    final reserveController = TextEditingController(
      text: ((payout['reserve_percent'] as num?)?.toDouble() ?? 0).toStringAsFixed(1),
    );

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать выплату'),
        content: StatefulBuilder(
          builder: (context, setLocal) {
            double parse(TextEditingController c) =>
                double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
            final total = parse(vehicleController) +
                parse(creditController) +
                parse(personalController) +
                parse(reserveController);
            final valid = (total - 100).abs() <= 0.01;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Полученная сумма',
                      suffixText: '₽',
                    ),
                  ),
                  TextField(
                    controller: vehicleController,
                    onChanged: (_) => setLocal(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Автобус', suffixText: '%'),
                  ),
                  TextField(
                    controller: creditController,
                    onChanged: (_) => setLocal(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Кредит', suffixText: '%'),
                  ),
                  TextField(
                    controller: personalController,
                    onChanged: (_) => setLocal(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Личные', suffixText: '%'),
                  ),
                  TextField(
                    controller: reserveController,
                    onChanged: (_) => setLocal(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Заначка', suffixText: '%'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    valid ? 'Итого: 100%' : 'Итого: ${total.toStringAsFixed(1)}% — должно быть 100%',
                    style: TextStyle(
                      color: valid ? null : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              double parse(TextEditingController c) =>
                  double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
              final amount = parse(amountController);
              final v = parse(vehicleController);
              final c = parse(creditController);
              final p = parse(personalController);
              final r = parse(reserveController);
              if (amount <= 0 || (v + c + p + r - 100).abs() > 0.01) return;
              Navigator.pop(context, {
                'amount': amount,
                'vehicle': v,
                'credit': c,
                'personal': p,
                'reserve': r,
              });
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    amountController.dispose();
    vehicleController.dispose();
    creditController.dispose();
    personalController.dispose();
    reserveController.dispose();
    if (result == null) return;
    await _assistant.updateTripPayout(
      id: id,
      amount: result['amount']!,
      vehiclePercent: result['vehicle']!,
      creditPercent: result['credit']!,
      personalPercent: result['personal']!,
      reservePercent: result['reserve']!,
      note: payout['note']?.toString(),
    );
    await _load();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Future<MonthlyExportOptions?> _chooseExportOptions() async {
    final db = DatabaseHelper.instance;
    Map<String, dynamic> saved = const {};
    try {
      final raw = await db.getSetting('flex_export_options_v1');
      if (raw != null && raw.isNotEmpty) {
        saved = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    bool v(String key, [bool fallback = true]) =>
        saved[key] is bool ? saved[key] as bool : fallback;

    var summary = v('summary');
    var trips = v('trips');
    var orders = v('orders');
    var fuel = v('fuel');
    var expenses = v('expenses');
    var repairs = v('repairs');
    var mileage = v('mileage');

    var summaryRegularTrips = v('summaryRegularTrips');
    var summaryRegularTripsTotal = v('summaryRegularTripsTotal');
    var summaryRegularTripsFull = v('summaryRegularTripsFull');
    var summaryRegularTripsPartial = v('summaryRegularTripsPartial');
    var summaryRegularTripsMorning = v('summaryRegularTripsMorning');
    var summaryRegularTripsEvening = v('summaryRegularTripsEvening');

    var summaryExtraTrips = v('summaryExtraTrips');
    var summaryExtraTripsTotal = v('summaryExtraTripsTotal');
    var summaryExtraTripsWait = v('summaryExtraTripsWait');

    var summaryOrders = v('summaryOrders');
    var summaryOrdersRevenue = v('summaryOrdersRevenue');
    var summaryOrderVehicle = v('summaryOrderVehicle');
    var summaryOrderCredit = v('summaryOrderCredit');
    var summaryOrderReserve = v('summaryOrderReserve');
    var summaryOrderPersonal = v('summaryOrderPersonal');

    var summaryTripDistribution = v('summaryTripDistribution');
    var summaryTripVehicle = v('summaryTripVehicle');
    var summaryTripCredit = v('summaryTripCredit');
    var summaryTripReserve = v('summaryTripReserve');
    var summaryTripPersonal = v('summaryTripPersonal');

    var summaryPersonal = v('summaryPersonal');
    var summaryPersonalTrips = v('summaryPersonalTrips');
    var summaryPersonalOrders = v('summaryPersonalOrders');
    var summaryPersonalTotal = v('summaryPersonalTotal');

    var summaryFuel = v('summaryFuel');
    var summaryFuelLiters = v('summaryFuelLiters');
    var summaryFuelCost = v('summaryFuelCost');
    var summaryFuelAverage = v('summaryFuelAverage');

    var summaryExpenses = v('summaryExpenses');
    var summaryExpensesTotal = v('summaryExpensesTotal');
    var summaryExpenseParts = v('summaryExpenseParts');
    var summaryExpenseRepairs = v('summaryExpenseRepairs');
    var summaryExpenseOther = v('summaryExpenseOther');

    var summaryMileage = v('summaryMileage');
    var summaryMileageDistance = v('summaryMileageDistance');

    var tripsRegular = v('tripsRegular');
    var tripsExtra = v('tripsExtra');

    var fuelShowLiters = v('fuelShowLiters');
    var fuelShowCost = v('fuelShowCost');
    var fuelShowMileage = v('fuelShowMileage');
    var fuelShowComments = v('fuelShowComments');

    MonthlyExportOptions buildOptions() => MonthlyExportOptions(
          summary: summary,
          trips: trips,
          orders: orders,
          fuel: fuel,
          expenses: expenses,
          repairs: repairs,
          mileage: mileage,
          summaryRegularTrips: summaryRegularTrips,
          summaryRegularTripsTotal: summaryRegularTripsTotal,
          summaryRegularTripsFull: summaryRegularTripsFull,
          summaryRegularTripsPartial: summaryRegularTripsPartial,
          summaryRegularTripsMorning: summaryRegularTripsMorning,
          summaryRegularTripsEvening: summaryRegularTripsEvening,
          summaryExtraTrips: summaryExtraTrips,
          summaryExtraTripsTotal: summaryExtraTripsTotal,
          summaryExtraTripsWait: summaryExtraTripsWait,
          summaryOrders: summaryOrders,
          summaryOrdersRevenue: summaryOrdersRevenue,
          summaryOrderVehicle: summaryOrderVehicle,
          summaryOrderCredit: summaryOrderCredit,
          summaryOrderReserve: summaryOrderReserve,
          summaryOrderPersonal: summaryOrderPersonal,
          summaryTripDistribution: summaryTripDistribution,
          summaryTripVehicle: summaryTripVehicle,
          summaryTripCredit: summaryTripCredit,
          summaryTripReserve: summaryTripReserve,
          summaryTripPersonal: summaryTripPersonal,
          summaryPersonal: summaryPersonal,
          summaryPersonalTrips: summaryPersonalTrips,
          summaryPersonalOrders: summaryPersonalOrders,
          summaryPersonalTotal: summaryPersonalTotal,
          summaryFuel: summaryFuel,
          summaryFuelLiters: summaryFuelLiters,
          summaryFuelCost: summaryFuelCost,
          summaryFuelAverage: summaryFuelAverage,
          summaryExpenses: summaryExpenses,
          summaryExpensesTotal: summaryExpensesTotal,
          summaryExpenseParts: summaryExpenseParts,
          summaryExpenseRepairs: summaryExpenseRepairs,
          summaryExpenseOther: summaryExpenseOther,
          summaryMileage: summaryMileage,
          summaryMileageDistance: summaryMileageDistance,
          tripsRegular: tripsRegular,
          tripsExtra: tripsExtra,
          fuelShowLiters: fuelShowLiters,
          fuelShowCost: fuelShowCost,
          fuelShowMileage: fuelShowMileage,
          fuelShowComments: fuelShowComments,
        );

    Map<String, bool> optionMap() => {
          'summary': summary,
          'trips': trips,
          'orders': orders,
          'fuel': fuel,
          'expenses': expenses,
          'repairs': repairs,
          'mileage': mileage,
          'summaryRegularTrips': summaryRegularTrips,
          'summaryRegularTripsTotal': summaryRegularTripsTotal,
          'summaryRegularTripsFull': summaryRegularTripsFull,
          'summaryRegularTripsPartial': summaryRegularTripsPartial,
          'summaryRegularTripsMorning': summaryRegularTripsMorning,
          'summaryRegularTripsEvening': summaryRegularTripsEvening,
          'summaryExtraTrips': summaryExtraTrips,
          'summaryExtraTripsTotal': summaryExtraTripsTotal,
          'summaryExtraTripsWait': summaryExtraTripsWait,
          'summaryOrders': summaryOrders,
          'summaryOrdersRevenue': summaryOrdersRevenue,
          'summaryOrderVehicle': summaryOrderVehicle,
          'summaryOrderCredit': summaryOrderCredit,
          'summaryOrderReserve': summaryOrderReserve,
          'summaryOrderPersonal': summaryOrderPersonal,
          'summaryTripDistribution': summaryTripDistribution,
          'summaryTripVehicle': summaryTripVehicle,
          'summaryTripCredit': summaryTripCredit,
          'summaryTripReserve': summaryTripReserve,
          'summaryTripPersonal': summaryTripPersonal,
          'summaryPersonal': summaryPersonal,
          'summaryPersonalTrips': summaryPersonalTrips,
          'summaryPersonalOrders': summaryPersonalOrders,
          'summaryPersonalTotal': summaryPersonalTotal,
          'summaryFuel': summaryFuel,
          'summaryFuelLiters': summaryFuelLiters,
          'summaryFuelCost': summaryFuelCost,
          'summaryFuelAverage': summaryFuelAverage,
          'summaryExpenses': summaryExpenses,
          'summaryExpensesTotal': summaryExpensesTotal,
          'summaryExpenseParts': summaryExpenseParts,
          'summaryExpenseRepairs': summaryExpenseRepairs,
          'summaryExpenseOther': summaryExpenseOther,
          'summaryMileage': summaryMileage,
          'summaryMileageDistance': summaryMileageDistance,
          'tripsRegular': tripsRegular,
          'tripsExtra': tripsExtra,
          'fuelShowLiters': fuelShowLiters,
          'fuelShowCost': fuelShowCost,
          'fuelShowMileage': fuelShowMileage,
          'fuelShowComments': fuelShowComments,
        };

    return showDialog<MonthlyExportOptions>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) {
          final hasAny =
              summary || trips || orders || fuel || expenses || repairs || mileage;

          Widget subTile({
            required bool value,
            required String title,
            required ValueChanged<bool?> onChanged,
          }) => Padding(
                padding: const EdgeInsets.only(left: 28),
                child: CheckboxListTile(
                  value: value,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  title: Text(title),
                  onChanged: onChanged,
                ),
              );

          return AlertDialog(
            title: const Text('Настройка экспорта'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Общая сводка',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    CheckboxListTile(
                      value: summary,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Добавить общую сводку'),
                      onChanged: (x) => setLocal(() => summary = x ?? false),
                    ),
                    if (summary) ...[
                      CheckboxListTile(
                        value: summaryRegularTrips,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Мои смены (утро / вечер)'),
                        onChanged: (x) => setLocal(() {
                          summaryRegularTrips = x ?? false;
                          summaryRegularTripsTotal = summaryRegularTrips;
                          summaryRegularTripsFull = summaryRegularTrips;
                          summaryRegularTripsPartial = summaryRegularTrips;
                          summaryRegularTripsMorning = summaryRegularTrips;
                          summaryRegularTripsEvening = summaryRegularTrips;
                        }),
                      ),
                      if (summaryRegularTrips) ...[
                        subTile(value: summaryRegularTripsTotal, title: 'Всего смен и общая сумма', onChanged: (x) => setLocal(() => summaryRegularTripsTotal = x ?? false)),
                        subTile(value: summaryRegularTripsFull, title: 'Полные смены', onChanged: (x) => setLocal(() => summaryRegularTripsFull = x ?? false)),
                        subTile(value: summaryRegularTripsPartial, title: 'Неполные смены', onChanged: (x) => setLocal(() => summaryRegularTripsPartial = x ?? false)),
                        subTile(value: summaryRegularTripsMorning, title: 'Утренние смены', onChanged: (x) => setLocal(() => summaryRegularTripsMorning = x ?? false)),
                        subTile(value: summaryRegularTripsEvening, title: 'Вечерние смены', onChanged: (x) => setLocal(() => summaryRegularTripsEvening = x ?? false)),
                      ],
                      CheckboxListTile(
                        value: summaryExtraTrips,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Дополнительные смены'),
                        onChanged: (x) => setLocal(() {
                          summaryExtraTrips = x ?? false;
                          summaryExtraTripsTotal = summaryExtraTrips;
                          summaryExtraTripsWait = summaryExtraTrips;
                        }),
                      ),
                      if (summaryExtraTrips) ...[
                        subTile(value: summaryExtraTripsTotal, title: 'Количество и общая сумма', onChanged: (x) => setLocal(() => summaryExtraTripsTotal = x ?? false)),
                        subTile(value: summaryExtraTripsWait, title: 'Ожидание и сумма ожидания', onChanged: (x) => setLocal(() => summaryExtraTripsWait = x ?? false)),
                      ],
                      CheckboxListTile(
                        value: summaryOrders,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Заказы'),
                        onChanged: (x) => setLocal(() {
                          summaryOrders = x ?? false;
                          summaryOrdersRevenue = summaryOrders;
                          summaryOrderVehicle = summaryOrders;
                          summaryOrderCredit = summaryOrders;
                          summaryOrderReserve = summaryOrders;
                          summaryOrderPersonal = summaryOrders;
                        }),
                      ),
                      if (summaryOrders) ...[
                        subTile(value: summaryOrdersRevenue, title: 'Общая выручка', onChanged: (x) => setLocal(() => summaryOrdersRevenue = x ?? false)),
                        subTile(value: summaryOrderVehicle, title: 'Распределено на автобус', onChanged: (x) => setLocal(() => summaryOrderVehicle = x ?? false)),
                        subTile(value: summaryOrderCredit, title: 'Распределено на кредит', onChanged: (x) => setLocal(() => summaryOrderCredit = x ?? false)),
                        subTile(value: summaryOrderReserve, title: 'Распределено в заначку', onChanged: (x) => setLocal(() => summaryOrderReserve = x ?? false)),
                        subTile(value: summaryOrderPersonal, title: 'Оставлено себе', onChanged: (x) => setLocal(() => summaryOrderPersonal = x ?? false)),
                      ],
                      CheckboxListTile(
                        value: summaryTripDistribution,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Распределение выплаты за рейсы'),
                        onChanged: (x) => setLocal(() {
                          summaryTripDistribution = x ?? false;
                          summaryTripVehicle = summaryTripDistribution;
                          summaryTripCredit = summaryTripDistribution;
                          summaryTripReserve = summaryTripDistribution;
                          summaryTripPersonal = summaryTripDistribution;
                        }),
                      ),
                      if (summaryTripDistribution) ...[
                        subTile(value: summaryTripVehicle, title: 'На автобус', onChanged: (x) => setLocal(() => summaryTripVehicle = x ?? false)),
                        subTile(value: summaryTripCredit, title: 'На кредит', onChanged: (x) => setLocal(() => summaryTripCredit = x ?? false)),
                        subTile(value: summaryTripReserve, title: 'В заначку', onChanged: (x) => setLocal(() => summaryTripReserve = x ?? false)),
                        subTile(value: summaryTripPersonal, title: 'Себе', onChanged: (x) => setLocal(() => summaryTripPersonal = x ?? false)),
                      ],
                      CheckboxListTile(
                        value: summaryPersonal,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Заработано себе'),
                        onChanged: (x) => setLocal(() {
                          summaryPersonal = x ?? false;
                          summaryPersonalTrips = summaryPersonal;
                          summaryPersonalOrders = summaryPersonal;
                          summaryPersonalTotal = summaryPersonal;
                        }),
                      ),
                      if (summaryPersonal) ...[
                        subTile(value: summaryPersonalTrips, title: 'Со смен', onChanged: (x) => setLocal(() => summaryPersonalTrips = x ?? false)),
                        subTile(value: summaryPersonalOrders, title: 'С заказов', onChanged: (x) => setLocal(() => summaryPersonalOrders = x ?? false)),
                        subTile(value: summaryPersonalTotal, title: 'Всего себе', onChanged: (x) => setLocal(() => summaryPersonalTotal = x ?? false)),
                      ],
                      CheckboxListTile(
                        value: summaryFuel,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Топливо'),
                        onChanged: (x) => setLocal(() {
                          summaryFuel = x ?? false;
                          summaryFuelLiters = summaryFuel;
                          summaryFuelCost = summaryFuel;
                          summaryFuelAverage = summaryFuel;
                        }),
                      ),
                      if (summaryFuel) ...[
                        subTile(value: summaryFuelLiters, title: 'Заправлено литров', onChanged: (x) => setLocal(() => summaryFuelLiters = x ?? false)),
                        subTile(value: summaryFuelCost, title: 'Потрачено на топливо', onChanged: (x) => setLocal(() => summaryFuelCost = x ?? false)),
                        subTile(value: summaryFuelAverage, title: 'Средний расход, л/100 км', onChanged: (x) => setLocal(() => summaryFuelAverage = x ?? false)),
                      ],
                      CheckboxListTile(
                        value: summaryExpenses,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Расходы'),
                        onChanged: (x) => setLocal(() {
                          summaryExpenses = x ?? false;
                          summaryExpenseParts = summaryExpenses;
                          summaryExpenseRepairs = summaryExpenses;
                          summaryExpenseOther = summaryExpenses;
                          summaryExpensesTotal = summaryExpenses;
                        }),
                      ),
                      if (summaryExpenses) ...[
                        subTile(value: summaryExpenseParts, title: 'Запчасти', onChanged: (x) => setLocal(() => summaryExpenseParts = x ?? false)),
                        subTile(value: summaryExpenseRepairs, title: 'Ремонты / ТО', onChanged: (x) => setLocal(() => summaryExpenseRepairs = x ?? false)),
                        subTile(value: summaryExpenseOther, title: 'Прочие расходы', onChanged: (x) => setLocal(() => summaryExpenseOther = x ?? false)),
                        subTile(value: summaryExpensesTotal, title: 'Всего расходов', onChanged: (x) => setLocal(() => summaryExpensesTotal = x ?? false)),
                      ],
                      CheckboxListTile(
                        value: summaryMileage,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Пробег'),
                        onChanged: (x) => setLocal(() {
                          summaryMileage = x ?? false;
                          summaryMileageDistance = summaryMileage;
                        }),
                      ),
                      if (summaryMileage)
                        subTile(value: summaryMileageDistance, title: 'Общий пробег за месяц', onChanged: (x) => setLocal(() => summaryMileageDistance = x ?? false)),
                    ],
                    const Divider(height: 28),
                    const Text(
                      'Подробные таблицы',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    CheckboxListTile(
                      value: trips,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Рейсы'),
                      onChanged: (x) => setLocal(() {
                        trips = x ?? false;
                        tripsRegular = trips;
                        tripsExtra = trips;
                      }),
                    ),
                    if (trips) ...[
                      subTile(value: tripsRegular, title: 'Мои смены', onChanged: (x) => setLocal(() => tripsRegular = x ?? false)),
                      subTile(value: tripsExtra, title: 'Доп. смены', onChanged: (x) => setLocal(() => tripsExtra = x ?? false)),
                    ],
                    CheckboxListTile(value: orders, contentPadding: EdgeInsets.zero, title: const Text('Заказы'), onChanged: (x) => setLocal(() => orders = x ?? false)),
                    CheckboxListTile(
                      value: fuel,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Топливо'),
                      onChanged: (x) => setLocal(() {
                        fuel = x ?? false;
                        fuelShowLiters = fuel;
                        fuelShowCost = fuel;
                        fuelShowMileage = fuel;
                        fuelShowComments = fuel;
                      }),
                    ),
                    if (fuel) ...[
                      subTile(value: fuelShowLiters, title: 'Литры', onChanged: (x) => setLocal(() => fuelShowLiters = x ?? false)),
                      subTile(value: fuelShowCost, title: 'Цена и сумма', onChanged: (x) => setLocal(() => fuelShowCost = x ?? false)),
                      subTile(value: fuelShowMileage, title: 'Пробег при заправке', onChanged: (x) => setLocal(() => fuelShowMileage = x ?? false)),
                      subTile(value: fuelShowComments, title: 'Комментарии', onChanged: (x) => setLocal(() => fuelShowComments = x ?? false)),
                    ],
                    CheckboxListTile(value: expenses, contentPadding: EdgeInsets.zero, title: const Text('Расходы / запчасти'), onChanged: (x) => setLocal(() => expenses = x ?? false)),
                    CheckboxListTile(value: repairs, contentPadding: EdgeInsets.zero, title: const Text('Ремонты'), onChanged: (x) => setLocal(() => repairs = x ?? false)),
                    CheckboxListTile(value: mileage, contentPadding: EdgeInsets.zero, title: const Text('Пробег'), onChanged: (x) => setLocal(() => mileage = x ?? false)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setLocal(() {
                  summary = false;
                  trips = false;
                  orders = false;
                  fuel = false;
                  expenses = false;
                  repairs = false;
                  mileage = false;
                }),
                child: const Text('Снять всё'),
              ),
              TextButton(
                onPressed: () => setLocal(() {
                  summary = true;
                  trips = true;
                  orders = true;
                  fuel = true;
                  expenses = true;
                  repairs = true;
                  mileage = true;
                  summaryRegularTrips = true;
                  summaryRegularTripsTotal = true;
                  summaryRegularTripsFull = true;
                  summaryRegularTripsPartial = true;
                  summaryRegularTripsMorning = true;
                  summaryRegularTripsEvening = true;
                  summaryExtraTrips = true;
                  summaryExtraTripsTotal = true;
                  summaryExtraTripsWait = true;
                  summaryOrders = true;
                  summaryOrdersRevenue = true;
                  summaryOrderVehicle = true;
                  summaryOrderCredit = true;
                  summaryOrderReserve = true;
                  summaryOrderPersonal = true;
                  summaryTripDistribution = true;
                  summaryTripVehicle = true;
                  summaryTripCredit = true;
                  summaryTripReserve = true;
                  summaryTripPersonal = true;
                  summaryPersonal = true;
                  summaryPersonalTrips = true;
                  summaryPersonalOrders = true;
                  summaryPersonalTotal = true;
                  summaryFuel = true;
                  summaryFuelLiters = true;
                  summaryFuelCost = true;
                  summaryFuelAverage = true;
                  summaryExpenses = true;
                  summaryExpensesTotal = true;
                  summaryExpenseParts = true;
                  summaryExpenseRepairs = true;
                  summaryExpenseOther = true;
                  summaryMileage = true;
                  summaryMileageDistance = true;
                  tripsRegular = true;
                  tripsExtra = true;
                  fuelShowLiters = true;
                  fuelShowCost = true;
                  fuelShowMileage = true;
                  fuelShowComments = true;
                }),
                child: const Text('Выбрать всё'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: hasAny
                    ? () async {
                        final result = buildOptions();
                        await db.setSetting(
                          'flex_export_options_v1',
                          jsonEncode(optionMap()),
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, result);
                        }
                      }
                    : null,
                child: const Text('Продолжить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportPdf() async {
    final options = await _chooseExportOptions();
    if (options == null) return;
    await _run(() => _export.sharePdf(_month, options: options));
  }

  Future<void> _exportExcel() async {
    final options = await _chooseExportOptions();
    if (options == null || !mounted) return;

    final size = MediaQuery.sizeOf(context);
    final sharePositionOrigin = Rect.fromLTWH(
      size.width / 2,
      size.height / 2,
      1,
      1,
    );

    await _run(
      () => _export.shareExcel(
        _month,
        options: options,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Widget _metric({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: BusCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, double value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Text(
            _money(value),
            style: TextStyle(
              fontSize: strong ? 18 : 15,
              fontWeight: strong ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final settings = _appSettings;
    final snapshot = _snapshot;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Финансы',
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
                      '${_months[_month.month - 1]} ${_month.year}',
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
            BusCard(
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const CreditsScreen(),
                  ),
                );
                await _load();
              },
              child: const Row(
                children: [
                  Icon(Icons.credit_score_outlined, size: 34),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Счёт Кредит',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('Накопление денег и простая оплата кредита'),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BusCard(
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const ReserveScreen()),
                );
                await _load();
              },
              child: const Row(
                children: [
                  Icon(Icons.savings_outlined, size: 34),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Заначка',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('Баланс, пополнение, снятие и история'),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BusCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DistributionCalculatorScreen(),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.calculate_outlined, size: 34),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Калькулятор распределения',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Введите сумму и сами настройте проценты',
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BusCard(
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const FundTransferScreen(),
                  ),
                );
                await _load();
              },
              child: const Row(
                children: [
                  Icon(Icons.swap_horiz, size: 34),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Перевод между счетами',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Автобус ↔ Кредит ↔ Заначка ↔ личные',
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BusCard(
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const NotesScreen()),
                );
              },
              child: const Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 34),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Заметки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('Личные пометки, дела и напоминания'),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (report != null && settings != null && snapshot != null) ...[
              BusCard(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Доступно сейчас',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _row('Автобус', snapshot.vehicleCash, strong: true),
                    _row('Кредит', snapshot.creditCash, strong: true),
                    _row('Заработал себе (${_months[_month.month - 1].toLowerCase()})', snapshot.personalFund, strong: true),
                    _row('Заначка', snapshot.reserveCash, strong: true),
                    if (snapshot.reserveDebt > 0)
                      _row('Нужно вернуть в заначку', snapshot.reserveDebt),
                    const SizedBox(height: 6),
                    Text(
                      'Автобус, кредит и заначка — реальные остатки сейчас. '
                      '«Заработал себе» считается отдельно за ${_months[_month.month - 1].toLowerCase()} ${_month.year}.',
                    ),
                    if (_personalTransfers.isNotEmpty) ...[
                      const Divider(height: 20),
                      const Text(
                        'Переводы личных за выбранный месяц',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      for (final entry in _personalTransfers.entries)
                        _row(_personalTransferLabel(entry.key), entry.value),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Счета и распределение',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _row('На счёт автобуса', snapshot.vehicleFund),
                    if (snapshot.creditAllocations.isEmpty)
                      _row('На кредит', snapshot.creditFund)
                    else
                      for (final entry
                          in snapshot.creditAllocations.entries)
                        _row(entry.key, entry.value),
                    _row('Заработано себе за выбранный месяц', snapshot.personalFund),
                    const Divider(height: 24),
                    _row('Топливо', -snapshot.fuelCost),
                    _row('Другие расходы автобуса', -snapshot.otherExpenses),
                    const SizedBox(height: 6),
                    Text(
                      'Все расходы, связанные с транспортом, уменьшают '
                      'только счёт автобуса.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Выплата от предприятия',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Изменить начисленную сумму',
                          onPressed: _editTripIncomeTarget,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    _row('Начислено предприятием', _tripIncomeTarget),
                    _row('Уже выплачено', _monthPayoutTotal),
                    _row(
                      'Осталось получить',
                      (_tripIncomeTarget - _monthPayoutTotal)
                          .clamp(0, double.infinity)
                          .toDouble(),
                      strong: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Можно отмечать выплату частями. Каждая полученная часть '
                      'сразу распределяется по выбранным счетам.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _tripIncomeTarget > 0 ? _receiveTripPayout : null,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Предприятие выплатило'),
                      ),
                    ),
                    if (_monthPayouts.isNotEmpty) ...[
                      const Divider(height: 28),
                      const Text(
                        'История выплат за месяц',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      for (final payout in _monthPayouts)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.account_balance_wallet_outlined),
                          title: Text(_money(
                            (payout['gross_amount'] as num?)?.toDouble() ?? 0,
                          )),
                          subtitle: Text(
                            payout['received_at']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: 'Редактировать выплату',
                            onPressed: () => _editTripPayout(payout),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metric(
                    title: 'Рейсы',
                    value: '${report.completedTrips}',
                    icon: Icons.directions_bus,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FinanceDetailScreen(
                          month: _month,
                          type: FinanceDetailType.trips,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _metric(
                    title: 'Заказы',
                    value: '${report.completedOrders}',
                    icon: Icons.local_taxi,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FinanceDetailScreen(
                          month: _month,
                          type: FinanceDetailType.orders,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metric(
                    title: 'Топливо',
                    value: '${_number(report.fuelLiters)} л',
                    icon: Icons.local_gas_station,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FinanceDetailScreen(
                          month: _month,
                          type: FinanceDetailType.fuel,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _metric(
                    title: 'Пробег',
                    value: '${report.distance} км',
                    icon: Icons.speed,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Доход по неделям',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SimpleBarChart(
                      values: _chartValues,
                      labels: _chartLabels,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final availableTripIncome = _monthPayoutTotal;
                  final available =
                      report.orderIncome + availableTripIncome;
                  final vehicle =
                      available * settings.workFundPercent / 100;
                  final credit =
                      available * settings.loanFundPercent / 100;
                  final personal =
                      available * settings.personalFundPercent / 100;
                  final vehicleAfterCosts =
                      vehicle - report.fuelCost - report.expenseCost;

                  return BusCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Финансовый помощник',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _row('Доступно для распределения', available),
                        const Divider(),
                        _row(
                          'На автобус (${_number(settings.workFundPercent)}%)',
                          vehicle,
                        ),
                        _row('Топливо', -report.fuelCost),
                        _row('Другие расходы', -report.expenseCost),
                        _row(
                          vehicleAfterCosts >= 0
                              ? 'Остаток кассы автобуса'
                              : 'Дефицит кассы автобуса',
                          vehicleAfterCosts,
                          strong: true,
                        ),
                        const Divider(),
                        _row(
                          'На кредит (${_number(settings.loanFundPercent)}%)',
                          credit,
                        ),
                        _row(
                          'Можно оставить себе '
                          '(${_number(settings.personalFundPercent)}%)',
                          personal,
                        ),
                        if (_monthPayoutTotal + 0.005 < _tripIncomeTarget &&
                            _tripIncomeTarget > 0) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Подсказка: в фонды попадает только фактически '
                            'полученная от предприятия сумма.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                        if (vehicleAfterCosts < 0) ...[
                          const SizedBox(height: 10),
                          Text(
                            '⚠️ Фонду автобуса не хватает '
                            '${_money(vehicleAfterCosts.abs())}.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              BusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Отчёт за месяц',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Экспорт PDF'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : _exportExcel,
                        icon: const Icon(Icons.table_view_outlined),
                        label: const Text('Экспорт Excel'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
