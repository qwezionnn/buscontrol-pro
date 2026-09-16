import 'package:flutter/material.dart';

import '../../../repositories/report_repository.dart';
import '../../../widgets/bus_card.dart';

class TodayMonthSummarySection extends StatefulWidget {
  const TodayMonthSummarySection({super.key});

  @override
  State<TodayMonthSummarySection> createState() =>
      _TodayMonthSummarySectionState();
}

class _TodayMonthSummarySectionState extends State<TodayMonthSummarySection> {
  final _repository = ReportRepository.instance;

  MonthReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final report = await _repository.getMonthReport(DateTime.now());
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  String _money(double value) {
    final rounded = value.round();
    final raw = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(raw[i]);
    }
    return '${buffer.toString()} ₽';
  }

  String _number(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  Widget _cell({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BusCard(
        child: SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final report = _report;
    if (report == null) return const SizedBox.shrink();
    final consumption = report.approximateFuelPer100Km;

    return BusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Этот месяц',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Обновить',
                visualDensity: VisualDensity.compact,
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _cell(
                  icon: Icons.route_outlined,
                  title: 'Рейсы',
                  value: report.completedTrips.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _cell(
                  icon: Icons.payments_outlined,
                  title: 'Доход',
                  value: _money(report.income),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _cell(
                  icon: Icons.speed_outlined,
                  title: 'Пробег',
                  value: '${report.distance} км',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _cell(
                  icon: Icons.local_gas_station_outlined,
                  title: 'Топливо',
                  value: '${_number(report.fuelLiters)} л',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _cell(
                  icon: Icons.trending_down,
                  title: 'Расходы',
                  value: _money(report.costs),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _cell(
                  icon: Icons.speed,
                  title: '≈ Расход',
                  value: consumption == null
                      ? '—'
                      : '${consumption.toStringAsFixed(1)} л/100 км',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
