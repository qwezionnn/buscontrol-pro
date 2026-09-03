import 'package:flutter/material.dart';

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
  bool _tripPayoutReceived = false;
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
    final snapshot = await _assistant.getSnapshot();
    final payout = await _assistant.isTripPayoutReceived(_month);

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
      _tripPayoutReceived = payout;
      _chartValues = values;
      _chartLabels = labels;
      _loading = false;
    });
  }

  void _changeMonth(int offset) {
    _month = DateTime(_month.year, _month.month + offset);
    _load();
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
    if (report == null || report.tripIncome <= 0) return;

    final amount = TextEditingController(text: report.tripIncome.toStringAsFixed(0));
    final vehicle = TextEditingController(text: '30');
    final credit = TextEditingController(text: '35');
    final personal = TextEditingController(text: '25');
    final reserve = TextEditingController(text: '10');
    var amountMode = false;

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Получена выплата предприятия'),
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
                  TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Полученная сумма', suffixText: '₽')),
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
            child: const Text('Получил и распределить'),
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
    var summary = true;
    var trips = true;
    var orders = true;
    var fuel = true;
    var expenses = true;
    var repairs = true;
    var mileage = true;

    return showDialog<MonthlyExportOptions>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) {
          final hasAny =
              summary || trips || orders || fuel || expenses || repairs || mileage;
          return AlertDialog(
            title: const Text('Что добавить в сводку?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: summary,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Общая сводка'),
                    onChanged: (v) => setLocal(() => summary = v ?? false),
                  ),
                  CheckboxListTile(
                    value: trips,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Рейсы'),
                    subtitle: const Text(
                      'Утро, вечер, полные/неполные, доп. рейсы и ожидание',
                    ),
                    onChanged: (v) => setLocal(() => trips = v ?? false),
                  ),
                  CheckboxListTile(
                    value: orders,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Заказы'),
                    onChanged: (v) => setLocal(() => orders = v ?? false),
                  ),
                  CheckboxListTile(
                    value: fuel,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Топливо'),
                    onChanged: (v) => setLocal(() => fuel = v ?? false),
                  ),
                  CheckboxListTile(
                    value: expenses,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Расходы / запчасти'),
                    onChanged: (v) => setLocal(() => expenses = v ?? false),
                  ),
                  CheckboxListTile(
                    value: repairs,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ремонты'),
                    onChanged: (v) => setLocal(() => repairs = v ?? false),
                  ),
                  CheckboxListTile(
                    value: mileage,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Пробег'),
                    onChanged: (v) => setLocal(() => mileage = v ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
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
                }),
                child: const Text('Выбрать всё'),
              ),
              FilledButton(
                onPressed: hasAny
                    ? () => Navigator.pop(
                          dialogContext,
                          MonthlyExportOptions(
                            summary: summary,
                            trips: trips,
                            orders: orders,
                            fuel: fuel,
                            expenses: expenses,
                            repairs: repairs,
                            mileage: mileage,
                          ),
                        )
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
    if (options == null) return;
    await _run(() => _export.shareExcel(_month, options: options));
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
                          'Кредиты',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('Несколько кредитов и отдельный процент для каждого'),
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
                          'Автобус ↔ кредиты ↔ личные деньги',
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
                    _row('Кредиты', snapshot.creditCash, strong: true),
                    _row('Заработал себе (всего)', snapshot.personalFund, strong: true),
                    _row('Заначка', snapshot.reserveCash, strong: true),
                    if (snapshot.reserveDebt > 0)
                      _row('Нужно вернуть в заначку', snapshot.reserveDebt),
                    const SizedBox(height: 6),
                    const Text(
                      'Автобус, кредиты и заначка — реальные остатки. «Заработал себе» — статистика, а не личный баланс.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Распределение фактически полученных денег',
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
                    _row('Личные деньги', snapshot.personalFund),
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
                    const Text(
                      'Выплата за рейсы',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _row('Начислено за месяц', report.tripIncome),
                    if (_tripPayoutReceived)
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Выплата получена и доступна для распределения.',
                            ),
                          ),
                        ],
                      )
                    else ...[
                      const Text(
                        'Эти деньги пока не входят в доступную кассу и '
                        'не распределяются между фондами.',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: report.tripIncome > 0
                              ? _receiveTripPayout
                              : null,
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Я получил выплату'),
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
                  final availableTripIncome =
                      _tripPayoutReceived ? report.tripIncome : 0.0;
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
                        if (!_tripPayoutReceived &&
                            report.tripIncome > 0) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Подсказка: начисление за рейсы не распределено, '
                            'потому что выплата ещё не отмечена полученной.',
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
