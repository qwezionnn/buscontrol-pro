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
              ],
            ),
          ),

          const SizedBox(width: 12),

          Text(
            _formatMoney(trip.price),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              decoration:
                  trip.completed ? TextDecoration.lineThrough : null,
              decorationThickness: trip.completed ? 2 : null,
            ),
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