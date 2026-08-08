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

    // По выходным обычных утреннего/вечернего рейсов нет.
    // Удаляем только автоматически созданные НЕвыполненные системные рейсы,
    // чтобы не потерять случайно уже отмеченную историческую запись.
    if (date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday) {
      for (final row in rows) {
        final type = row['type']?.toString();
        final completed = row['completed'] == 1;
        final isStandard = type == TripType.morning.name ||
            type == TripType.evening.name;

        if (isStandard && !completed) {
          final id = row['id'];
          if (id is int) {
            await _databaseHelper.deleteTrip(id);
          }
        }
      }
      return;
    }

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

  /// Добавляет конкретный обычный рейс на выбранную дату.
  ///
  /// Если такой рейс уже существует, новый дубль не создаётся.
  /// Рейс создаётся как невыполненный — его можно отметить выполненным
  /// из календаря в любой момент.
  Future<void> addStandardTrip({
    required DateTime date,
    required TripType type,
  }) async {
    if (type == TripType.extra) {
      throw ArgumentError('Для дополнительного рейса используйте addExtraTrip.');
    }

    if (date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday) {
      throw StateError(
        'По выходным утренний и вечерний рейсы не добавляются.',
      );
    }

    final databaseDate = _databaseDate(date);
    final rows = await _databaseHelper.getTripsByDate(databaseDate);
    final typeName = type.name;

    final alreadyExists = rows.any(
      (row) => row['type']?.toString() == typeName,
    );
    if (alreadyExists) return;

    final price = await _getStandardTripPrice();
    final title = type == TripType.morning
        ? 'Утренний рейс'
        : 'Вечерний рейс';

    await _databaseHelper.addTrip(
      date: databaseDate,
      title: title,
      type: typeName,
      price: price,
      completed: false,
      ignoreConflict: true,
    );
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

  /// Удаляет дополнительный рейс.
  ///
  /// Утренний и вечерний рейсы являются системными и при необходимости
  /// автоматически создаются снова, поэтому из календаря удаляем только
  /// дополнительные рейсы.
  Future<void> deleteExtraTrip(int tripId) {
    return _databaseHelper.deleteTrip(tripId);
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