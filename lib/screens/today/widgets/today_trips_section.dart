import 'package:flutter/material.dart';

import '../../../models/trip.dart';
import '../../../repositories/trip_repository.dart';
import '../../../widgets/bus_card.dart';
import '../../trips/add_extra_trip_screen.dart';

class TodayTripsSection extends StatefulWidget {
  const TodayTripsSection({super.key});

  @override
  State<TodayTripsSection> createState() => _TodayTripsSectionState();
}

class _TodayTripsSectionState extends State<TodayTripsSection> {
  final TripRepository _repository = TripRepository.instance;

  List<Trip> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final trips = await _repository.getTripsForDate(
        DateTime.now(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _trips = trips;
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
            'Не удалось загрузить рейсы: $error',
          ),
        ),
      );
    }
  }

  Future<void> _setCompleted(
      Trip trip,
      bool completed,
      ) async {
    final tripId = trip.id;

    if (tripId == null) {
      return;
    }

    try {
      await _repository.setCompleted(
        tripId: tripId,
        completed: completed,
      );

      await _loadTrips();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось изменить рейс: $error',
          ),
        ),
      );
    }
  }

  Future<void> _openAddExtraTrip() async {
    final wasSaved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddExtraTripScreen(),
      ),
    );

    if (wasSaved != true) {
      return;
    }

    await _loadTrips();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Дополнительный рейс сохранён',
        ),
      ),
    );
  }

  Future<void> _editStandardTrip(Trip trip) async {
    if (trip.id == null || trip.type == TripType.extra) return;
    final price = TextEditingController(text: trip.price.toStringAsFixed(trip.price == trip.price.roundToDouble() ? 0 : 2));
    final note = TextEditingController(text: trip.priceNote ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(trip.type == TripType.morning ? 'Утренний рейс' : 'Вечерний рейс'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Фактическая цена', suffixText: '₽')),
          const SizedBox(height: 10),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Комментарий', hintText: 'Например: другой автобус')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (ok == true) {
      final value = double.tryParse(price.text.trim().replaceAll(',', '.'));
      if (value != null && value > 0) {
        await _repository.editStandardTrip(tripId: trip.id!, price: value, note: note.text);
        await _loadTrips();
      }
    }
    price.dispose(); note.dispose();
  }

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(0)} ₽';
  }

  Widget _buildTripTile(Trip trip) {
    final isExtra = trip.type == TripType.extra;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Checkbox(
            value: trip.completed,
            onChanged: (value) {
              _setCompleted(
                trip,
                value ?? false,
              );
            },
          ),

          if (isExtra) ...[
            const Icon(
              Icons.add_road,
              size: 20,
            ),
            const SizedBox(width: 8),
          ],

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isExtra
                        ? FontWeight.w600
                        : FontWeight.normal,
                    decoration: trip.completed
                        ? TextDecoration.lineThrough
                        : null,
                    decorationThickness: trip.completed ? 2 : null,
                    color: trip.completed
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),

                if (trip.time != null &&
                    trip.time!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 3,
                    ),
                    child: Text(
                      trip.time!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            decoration: trip.completed
                                ? TextDecoration.lineThrough
                                : null,
                            decorationThickness:
                                trip.completed ? 2 : null,
                          ),
                    ),
                  ),
                if (!isExtra && trip.priceOverridden && (trip.priceNote?.trim().isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('(${trip.priceNote})', style: Theme.of(context).textTheme.bodySmall),
                  ),
                if (isExtra && trip.waitHours > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Ожидание: ${trip.waitHours.toStringAsFixed(trip.waitHours == trip.waitHours.roundToDouble() ? 0 : 1)} ч × ${_formatMoney(trip.waitRate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Text(
            _formatMoney(trip.totalPrice),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              decoration:
                  trip.completed ? TextDecoration.lineThrough : null,
              decorationThickness: trip.completed ? 2 : null,
            ),
          ),
          if (!isExtra)
            IconButton(
              tooltip: 'Изменить цену рейса',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.settings_outlined, size: 20),
              onPressed: () => _editStandardTrip(trip),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BusCard(
      child: Column(
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_trips.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Рейсов на сегодня нет',
              ),
            )
          else
            for (
            var index = 0;
            index < _trips.length;
            index++
            ) ...[
              _buildTripTile(_trips[index]),
              if (index != _trips.length - 1)
                const Divider(height: 1),
            ],

          if (!_isLoading)
            const Divider(height: 1),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.add_road,
            ),
            title: const Text(
              'Дополнительный рейс',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(Icons.add),
            onTap: _openAddExtraTrip,
          ),
        ],
      ),
    );
  }
}