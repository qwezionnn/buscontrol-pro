import 'package:flutter/material.dart';

import '../../../models/fuel.dart';
import '../../../repositories/fuel_repository.dart';
import '../../../widgets/bus_card.dart';
import '../../fuel/add_fuel_screen.dart';

class TodayFuelSection extends StatefulWidget {
  const TodayFuelSection({super.key});

  @override
  State<TodayFuelSection> createState() => _TodayFuelSectionState();
}

class _TodayFuelSectionState extends State<TodayFuelSection> {
  final FuelRepository _repository = FuelRepository.instance;

  List<FuelLog> _fuelLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFuelLogs();
  }

  Future<void> _loadFuelLogs() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final fuelLogs = await _repository.getFuelLogsForDate(
        DateTime.now(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _fuelLogs = fuelLogs;
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
          content: Text(
            'Не удалось загрузить заправки: $error',
          ),
        ),
      );
    }
  }

  Future<void> _openAddFuelScreen() async {
    final wasSaved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddFuelScreen(),
      ),
    );

    if (wasSaved != true) {
      return;
    }

    await _loadFuelLogs();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Заправка сохранена'),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return BusCard(
      onTap: _openAddFuelScreen,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.local_gas_station,
              color: Theme.of(context)
                  .colorScheme
                  .onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Заправка',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text('Добавить'),
              ],
            ),
          ),
          const Icon(Icons.add_circle_outline),
        ],
      ),
    );
  }

  Widget _buildFuelLogCard(FuelLog fuelLog) {
    return BusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_gas_station,
                  color: Theme.of(context)
                      .colorScheme
                      .onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Заправка',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (fuelLog.time != null &&
                            fuelLog.time!.isNotEmpty)
                          fuelLog.time!,
                        fuelLog.litersText,
                        fuelLog.priceText,
                      ].join(' · '),
                    ),
                  ],
                ),
              ),
              Text(
                fuelLog.totalText,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          if (fuelLog.mileage != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.speed,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(fuelLog.mileageText),
              ],
            ),
          ],

          if (fuelLog.note != null &&
              fuelLog.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(fuelLog.note!),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const BusCard(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_fuelLogs.isEmpty) {
      return _buildEmptyCard();
    }

    return Column(
      children: [
        for (final fuelLog in _fuelLogs) ...[
          _buildFuelLogCard(fuelLog),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openAddFuelScreen,
            icon: const Icon(Icons.add),
            label: const Text('Ещё заправка'),
          ),
        ),
      ],
    );
  }
}