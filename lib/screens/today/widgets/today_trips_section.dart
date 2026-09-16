import 'package:flutter/material.dart';

import '../../../models/trip.dart';
import '../../../repositories/trip_repository.dart';
import '../../../services/home_widget_service.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/time_wheel_picker.dart';
import '../../../widgets/bus_card.dart';
import '../../trips/add_extra_trip_screen.dart';

class TodayTripsSection extends StatefulWidget {
  const TodayTripsSection({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<TodayTripsSection> createState() => _TodayTripsSectionState();
}

class _TodayTripsSectionState extends State<TodayTripsSection> {
  final TripRepository _repository = TripRepository.instance;

  List<Trip> _trips = [];
  bool _isLoading = true;
  bool _endMileageReminderEnabled = false;
  int _endMileageReminderHour = 18;
  int _endMileageReminderMinute = 5;
  bool _reminderLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _loadEndMileageReminder();
  }

  Future<void> _loadEndMileageReminder() async {
    final settings =
        await NotificationService.instance.getEndMileageReminderSettings();
    if (!mounted) return;
    setState(() {
      _endMileageReminderEnabled = settings.enabled;
      _endMileageReminderHour = settings.hour;
      _endMileageReminderMinute = settings.minute;
      _reminderLoading = false;
    });
  }

  Future<void> _setEndMileageReminderEnabled(bool enabled) async {
    setState(() => _endMileageReminderEnabled = enabled);

    if (enabled) {
      await NotificationService.instance.requestPermissions();
    }

    await NotificationService.instance.saveEndMileageReminderSettings(
      enabled: enabled,
      hour: _endMileageReminderHour,
      minute: _endMileageReminderMinute,
    );
  }

  Future<void> _pickEndMileageReminderTime() async {
    final picked = await showBusTimeWheelPicker(
      context,
      initialTime: TimeOfDay(
        hour: _endMileageReminderHour,
        minute: _endMileageReminderMinute,
      ),
      title: 'Напоминание о пробеге',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _endMileageReminderHour = picked.hour;
      _endMileageReminderMinute = picked.minute;
    });

    await NotificationService.instance.saveEndMileageReminderSettings(
      enabled: _endMileageReminderEnabled,
      hour: picked.hour,
      minute: picked.minute,
    );
  }

  String get _endMileageReminderTimeLabel =>
      '${_endMileageReminderHour.toString().padLeft(2, '0')}:'
      '${_endMileageReminderMinute.toString().padLeft(2, '0')}';

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
      await HomeWidgetService.instance.updateTodaySnapshot();

      await _loadTrips();
      widget.onChanged?.call();
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
    widget.onChanged?.call();

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
      if (value != null && value >= 0) {
        await _repository.editStandardTrip(
          tripId: trip.id!,
          price: value,
          note: note.text,
        );
        await _loadTrips();
        widget.onChanged?.call();
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

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.route_outlined, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Напоминание о конечном пробеге',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _endMileageReminderEnabled
                            ? 'Только по будням'
                            : 'Выключено • по выходным не приходит',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _reminderLoading
                      ? null
                      : _pickEndMileageReminderTime,
                  child: Text(
                    _endMileageReminderTimeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Switch.adaptive(
                  value: _endMileageReminderEnabled,
                  onChanged: _reminderLoading
                      ? null
                      : _setEndMileageReminderEnabled,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}