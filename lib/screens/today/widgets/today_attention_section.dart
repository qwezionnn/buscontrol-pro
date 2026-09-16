import 'package:flutter/material.dart';

import '../../../models/maintenance_item.dart';
import '../../../repositories/daily_log_repository.dart';
import '../../../repositories/maintenance_repository.dart';
import '../../../repositories/report_repository.dart';
import '../../../widgets/bus_card.dart';
import '../../bus/maintenance_screen.dart';
import '../../bus/quick_end_mileage_screen.dart';

class TodayAttentionSection extends StatefulWidget {
  const TodayAttentionSection({
    super.key,
    this.onChanged,
  });

  final VoidCallback? onChanged;

  @override
  State<TodayAttentionSection> createState() => _TodayAttentionSectionState();
}

class _TodayAttentionSectionState extends State<TodayAttentionSection> {
  final _reportRepository = ReportRepository.instance;
  final _maintenanceRepository = MaintenanceRepository.instance;
  final _mileageRepository = DailyLogRepository.instance;

  DateTime? _missedMileageDate;
  List<MaintenanceItem> _urgentMaintenance = const [];
  int _currentMileage = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    DateTime? missed;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Find the most recent day where there were actual trip records but the
    // end mileage was never saved. We intentionally do not create historical
    // standard trips here.
    for (var offset = 1; offset <= 14; offset++) {
      final date = today.subtract(Duration(days: offset));
      final events = await _reportRepository.getDayEvents(date);
      final hadCompletedTrip =
          events.trips.any((row) => row['completed'] == 1);
      if (hadCompletedTrip && events.endMileage == null) {
        missed = date;
        break;
      }
    }

    final mileage = await _mileageRepository.getLastMileage() ??
        await _mileageRepository.getInitialMileage() ??
        0;
    final items = await _maintenanceRepository.getItems();
    final urgent = items.where((item) {
      if (item.isMileage) {
        final next = item.nextValue;
        if (next == null) return false;
        return next - mileage <= 1000;
      }
      final raw = item.nextValue;
      if (raw == null || raw <= 0) return false;
      final due = DateTime.fromMillisecondsSinceEpoch(raw);
      final normalizedDue = DateTime(due.year, due.month, due.day);
      final days = normalizedDue.difference(today).inDays;
      return days <= 30;
    }).toList();

    urgent.sort((a, b) => _urgencyValue(a, mileage, today)
        .compareTo(_urgencyValue(b, mileage, today)));

    if (!mounted) return;
    setState(() {
      _missedMileageDate = missed;
      _currentMileage = mileage;
      _urgentMaintenance = urgent;
      _loading = false;
    });
  }

  int _urgencyValue(MaintenanceItem item, int mileage, DateTime today) {
    if (item.isMileage) {
      return (item.nextValue ?? mileage) - mileage;
    }
    final raw = item.nextValue ?? 0;
    final due = DateTime.fromMillisecondsSinceEpoch(raw);
    return DateTime(due.year, due.month, due.day).difference(today).inDays * 100;
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  String _maintenanceSubtitle(MaintenanceItem item) {
    if (item.isMileage) {
      final left = (item.nextValue ?? _currentMileage) - _currentMileage;
      if (left < 0) return 'Просрочено на ${left.abs()} км';
      if (left == 0) return 'Пора выполнить сейчас';
      return 'Осталось $left км';
    }

    final due = DateTime.fromMillisecondsSinceEpoch(item.nextValue ?? 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(due.year, due.month, due.day).difference(today).inDays;
    if (days < 0) return 'Просрочено на ${days.abs()} дн.';
    if (days == 0) return 'Срок сегодня';
    if (days == 1) return 'Срок завтра';
    return 'Через $days дн. • ${_formatDate(due)}';
  }

  Future<void> _fixMileage() async {
    final date = _missedMileageDate;
    if (date == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickEndMileageScreen(initialDate: date),
      ),
    );
    if (changed == true) {
      await _load();
      widget.onChanged?.call();
    }
  }

  Future<void> _openMaintenance() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
    );
    await _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_missedMileageDate == null && _urgentMaintenance.isEmpty) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_missedMileageDate != null) ...[
          BusCard(
            onTap: _fixMileage,
            backgroundColor: scheme.errorContainer.withValues(alpha: 0.45),
            borderColor: scheme.error.withValues(alpha: 0.35),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: scheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Не указан конечный пробег',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'За ${_formatDate(_missedMileageDate!)}. Нажмите, чтобы заполнить.',
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          if (_urgentMaintenance.isNotEmpty) const SizedBox(height: 10),
        ],
        if (_urgentMaintenance.isNotEmpty)
          BusCard(
            onTap: _openMaintenance,
            backgroundColor: scheme.tertiaryContainer.withValues(alpha: 0.35),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.build_circle_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _urgentMaintenance.length == 1
                            ? 'Скоро ТО / документ'
                            : 'Требуют внимания: ${_urgentMaintenance.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_urgentMaintenance.first.title} — ${_maintenanceSubtitle(_urgentMaintenance.first)}',
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
      ],
    );
  }
}
