import 'package:flutter/material.dart';

import '../../../models/trip.dart';
import '../../../repositories/daily_log_repository.dart';
import '../../../repositories/fuel_repository.dart';
import '../../../repositories/trip_repository.dart';
import '../../../widgets/bus_card.dart';

class TodayDayStatusSection extends StatefulWidget {
  const TodayDayStatusSection({super.key});

  @override
  State<TodayDayStatusSection> createState() => _TodayDayStatusSectionState();
}

class _TodayDayStatusSectionState extends State<TodayDayStatusSection> {
  final _tripRepository = TripRepository.instance;
  final _mileageRepository = DailyLogRepository.instance;
  final _fuelRepository = FuelRepository.instance;

  bool _loading = true;
  bool _hide = false;
  bool _morningDone = false;
  bool _eveningDone = false;
  int _extraCount = 0;
  int _extraDone = 0;
  bool _mileageDone = false;
  int? _distance;
  int _fuelCount = 0;
  double _fuelLiters = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final trips = await _tripRepository.getTripsForDate(today);
    final log = await _mileageRepository.getLogForDate(today);
    final fuel = await _fuelRepository.getFuelLogsForDate(today);

    final isWeekend = today.weekday == DateTime.saturday ||
        today.weekday == DateTime.sunday;
    Trip? morning;
    Trip? evening;
    final extras = <Trip>[];
    for (final trip in trips) {
      switch (trip.type) {
        case TripType.morning:
          morning = trip;
          break;
        case TripType.evening:
          evening = trip;
          break;
        case TripType.extra:
          extras.add(trip);
          break;
      }
    }

    if (!mounted) return;
    setState(() {
      _hide = isWeekend && trips.isEmpty && !log.isCompleted && fuel.isEmpty;
      _morningDone = isWeekend || (morning?.completed ?? false);
      _eveningDone = isWeekend || (evening?.completed ?? false);
      _extraCount = extras.length;
      _extraDone = extras.where((trip) => trip.completed).length;
      _mileageDone = log.isCompleted;
      _distance = log.distance;
      _fuelCount = fuel.length;
      _fuelLiters = fuel.fold<double>(0, (sum, item) => sum + item.liters);
      _loading = false;
    });
  }

  bool get _extrasDone => _extraCount == 0 || _extraDone == _extraCount;
  bool get _closed =>
      _morningDone && _eveningDone && _extrasDone && _mileageDone;

  Widget _statusChip(String text, bool done) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? scheme.primaryContainer.withValues(alpha: 0.7)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: done ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _number(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _hide) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return BusCard(
      backgroundColor: _closed
          ? scheme.primaryContainer.withValues(alpha: 0.28)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _closed ? Icons.task_alt : Icons.fact_check_outlined,
                color: _closed ? Colors.green : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _closed ? 'День закрыт' : 'Контроль дня',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_distance != null)
                Text(
                  '${_distance!} км',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _statusChip('Утро', _morningDone),
              _statusChip('Вечер', _eveningDone),
              _statusChip(
                _extraCount == 0 ? 'Доп. —' : 'Доп. $_extraDone/$_extraCount',
                _extrasDone,
              ),
              _statusChip('Пробег', _mileageDone),
            ],
          ),
          if (_fuelCount > 0 || _distance != null) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (_distance != null) 'За день: $_distance км',
                if (_fuelCount > 0)
                  'Заправки: $_fuelCount • ${_number(_fuelLiters)} л',
              ].join('   •   '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
