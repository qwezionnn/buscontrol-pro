import '../database/database_helper.dart';
import '../models/trip.dart';

class TripRepository {
  TripRepository._();

  static final TripRepository instance = TripRepository._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  String _databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  Future<double> _getStandardTripPrice() async {
    final value = await _databaseHelper.getSetting(
      'enterprise_trip_price',
    );

    return double.tryParse(value ?? '') ?? 2700;
  }

  Future<void> ensureStandardTrips(DateTime date) async {
    final databaseDate = _databaseDate(date);

    final rows = await _databaseHelper.getTripsByDate(
      databaseDate,
    );

    final price = await _getStandardTripPrice();

    Map<String, Object?>? morningRow;
    Map<String, Object?>? eveningRow;

    for (final row in rows) {
      final type = row['type']?.toString();

      if (type == TripType.morning.name) {
        morningRow = row;
      }

      if (type == TripType.evening.name) {
        eveningRow = row;
      }
    }

    if (morningRow == null) {
      await _databaseHelper.addTrip(
        date: databaseDate,
        title: 'Утренний рейс',
        type: TripType.morning.name,
        price: price,
        ignoreConflict: true,
      );
    } else {
      final id = morningRow['id'];
      final oldPrice =
          (morningRow['price'] as num?)?.toDouble() ?? 0;

      if (id is int && oldPrice != price) {
        await _databaseHelper.updateTripPrice(
          id,
          price,
        );
      }
    }

    if (eveningRow == null) {
      await _databaseHelper.addTrip(
        date: databaseDate,
        title: 'Вечерний рейс',
        type: TripType.evening.name,
        price: price,
        ignoreConflict: true,
      );
    } else {
      final id = eveningRow['id'];
      final oldPrice =
          (eveningRow['price'] as num?)?.toDouble() ?? 0;

      if (id is int && oldPrice != price) {
        await _databaseHelper.updateTripPrice(
          id,
          price,
        );
      }
    }
  }

  Future<List<Trip>> getTripsForDate(
      DateTime date,
      ) async {
    await ensureStandardTrips(date);

    final rows = await _databaseHelper.getTripsByDate(
      _databaseDate(date),
    );

    final trips = rows.map(Trip.fromMap).toList();

    trips.sort((first, second) {
      final typeResult = _sortOrder(first.type).compareTo(
        _sortOrder(second.type),
      );

      if (typeResult != 0) {
        return typeResult;
      }

      return (first.time ?? '').compareTo(
        second.time ?? '',
      );
    });

    return trips;
  }

  Future<int> addExtraTrip({
    required DateTime date,
    String? time,
    required String title,
    required double price,
  }) {
    return _databaseHelper.addTrip(
      date: _databaseDate(date),
      time: time,
      title: title,
      type: TripType.extra.name,
      price: price,
    );
  }

  Future<void> setCompleted({
    required int tripId,
    required bool completed,
  }) {
    return _databaseHelper.setTripCompleted(
      tripId,
      completed,
    );
  }

  int _sortOrder(TripType type) {
    switch (type) {
      case TripType.morning:
        return 0;

      case TripType.evening:
        return 1;

      case TripType.extra:
        return 2;
    }
  }
}