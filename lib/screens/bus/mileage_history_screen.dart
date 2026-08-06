import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../widgets/bus_card.dart';

class MileageHistoryScreen extends StatefulWidget {
  const MileageHistoryScreen({
    super.key,
    required this.month,
  });

  final DateTime month;

  @override
  State<MileageHistoryScreen> createState() =>
      _MileageHistoryScreenState();
}

class _MileageHistoryScreenState extends State<MileageHistoryScreen> {
  final DatabaseHelper _database = DatabaseHelper.instance;

  bool _loading = true;
  List<Map<String, Object?>> _logs = const [];

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
    if (parts.length != 3) return value;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final from = _databaseDate(
        DateTime(widget.month.year, widget.month.month),
      );
      final to = _databaseDate(
        DateTime(widget.month.year, widget.month.month + 1, 0),
      );
      final logs = await _database.getDailyLogsBetween(from, to);
      if (!mounted) return;
      setState(() {
        _logs = logs.reversed.toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить пробег: $error')),
      );
    }
  }

  int get _totalDistance => _logs.fold<int>(0, (sum, log) {
        final start = (log['start_mileage'] as num?)?.toInt();
        final end = (log['end_mileage'] as num?)?.toInt();
        if (start == null || end == null || end < start) return sum;
        return sum + end - start;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История пробега')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BusCard(
                child: Row(
                  children: [
                    const Icon(Icons.speed, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Пробег за месяц',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text('${_totalDistance} км'),
                        ],
                      ),
                    ),
                    Text(
                      '${_logs.length} дн.',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_logs.isEmpty)
                const BusCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text('В этом месяце завершённых дней нет.'),
                    ),
                  ),
                )
              else
                for (var index = 0; index < _logs.length; index++) ...[
                  _buildLog(_logs[index]),
                  if (index != _logs.length - 1)
                    const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLog(Map<String, Object?> log) {
    final start = (log['start_mileage'] as num?)?.toInt();
    final end = (log['end_mileage'] as num?)?.toInt();
    final distance =
        start != null && end != null && end >= start ? end - start : null;

    return BusCard(
      child: Row(
        children: [
          const Icon(Icons.route),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(log['date']?.toString() ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  start == null || end == null
                      ? 'Пробег не заполнен'
                      : '$start → $end км',
                ),
              ],
            ),
          ),
          if (distance != null)
            Text(
              '$distance км',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
