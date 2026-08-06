import 'package:flutter/material.dart';

import '../../repositories/financial_assistant_repository.dart';
import '../../repositories/maintenance_repository.dart';
import '../../repositories/report_repository.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/simple_bar_chart.dart';
import '../expenses/emergency_expense_screen.dart';
import '../finance/finance_detail_screen.dart';
import 'mileage_history_screen.dart';
import 'maintenance_screen.dart';

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  final _reports = ReportRepository.instance;
  final _assistant = FinancialAssistantRepository.instance;
  final _maintenance = MaintenanceRepository.instance;

  bool _loading = true;
  FinancialSnapshot? _snapshot;
  MonthReport? _monthReport;
  int _maintenanceCount = 0;
  List<double> _profitValues = const [];
  List<String> _monthLabels = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final now = DateTime.now();
    final snapshot = await _assistant.getSnapshot();
    final monthReport = await _reports.getMonthReport(now);
    final maintenance = await _maintenance.getItems();

    final values = <double>[];
    final labels = <String>[];
    const names = [
      'Янв',
      'Фев',
      'Мар',
      'Апр',
      'Май',
      'Июн',
      'Июл',
      'Авг',
      'Сен',
      'Окт',
      'Ноя',
      'Дек',
    ];

    for (var offset = 5; offset >= 0; offset--) {
      final month = DateTime(now.year, now.month - offset);
      final report = await _reports.getMonthReport(month);
      values.add(report.profit < 0 ? 0 : report.profit);
      labels.add(names[month.month - 1]);
    }

    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _monthReport = monthReport;
      _maintenanceCount = maintenance.length;
      _profitValues = values;
      _monthLabels = labels;
      _loading = false;
    });
  }

  String _money(double value) => '${value.toStringAsFixed(0)} ₽';

  Future<void> _openEmergency() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const EmergencyExpenseScreen(),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _openFinanceDetail(FinanceDetailType type) async {
    final now = DateTime.now();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FinanceDetailScreen(
          month: DateTime(now.year, now.month),
          type: type,
        ),
      ),
    );
  }

  Future<void> _openMileageHistory() async {
    final now = DateTime.now();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MileageHistoryScreen(
          month: DateTime(now.year, now.month),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _monthReport;
    final snapshot = _snapshot;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Автобус',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Статистика, обслуживание и касса',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (report != null && snapshot != null) ...[
              BusCard(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Касса автобуса',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _money(snapshot.vehicleCash),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'В кассу попадает доля с выполненных заказов сразу, '
                      'а доля с рейсов — только после отметки месячной выплаты.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Рейсы',
                      '${report.completedTrips}',
                      Icons.directions_bus,
                      onTap: () => _openFinanceDetail(
                        FinanceDetailType.trips,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      'Заказы',
                      '${report.completedOrders}',
                      Icons.local_taxi,
                      onTap: () => _openFinanceDetail(
                        FinanceDetailType.orders,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Пробег',
                      '${report.distance} км',
                      Icons.speed,
                      onTap: _openMileageHistory,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      'Топливо',
                      '${report.fuelLiters.toStringAsFixed(1)} л',
                      Icons.local_gas_station,
                      onTap: () => _openFinanceDetail(
                        FinanceDetailType.fuel,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Прибыль за 6 месяцев',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SimpleBarChart(
                      values: _profitValues,
                      labels: _monthLabels,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BusCard(
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const MaintenanceScreen(),
                    ),
                  );
                  await _load();
                },
                child: Row(
                  children: [
                    const Icon(Icons.build_circle_outlined, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ТО автобуса',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _maintenanceCount == 0
                                ? 'Добавить обслуживание'
                                : 'Записей: $_maintenanceCount',
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BusCard(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.45),
                onTap: _openEmergency,
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 34,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Экстренный расход',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text('Поломка, эвакуатор или срочная покупка'),
                        ],
                      ),
                    ),
                    const Icon(Icons.add_circle_outline),
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

  Widget _statCard(
    String title,
    String value,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return BusCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
