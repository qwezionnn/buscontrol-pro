import '../database/database_helper.dart';
import '../models/fuel.dart';

class FuelRepository {
  FuelRepository._();

  static final FuelRepository instance = FuelRepository._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  String _databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  /// Возвращает все заправки выбранного дня.
  Future<List<FuelLog>> getFuelLogsForDate(
      DateTime date,
      ) async {
    final rows = await _databaseHelper.getFuelLogsByDate(
      _databaseDate(date),
    );

    final fuelLogs = rows.map(FuelLog.fromMap).toList();

    fuelLogs.sort((first, second) {
      final firstTime = first.time ?? '';
      final secondTime = second.time ?? '';

      return firstTime.compareTo(secondTime);
    });

    return fuelLogs;
  }

  /// Добавляет новую заправку.
  Future<int> addFuelLog(FuelLog fuelLog) {
    return _databaseHelper.addFuelLog(
      date: fuelLog.date,
      time: fuelLog.time,
      liters: fuelLog.liters,
      pricePerLiter: fuelLog.pricePerLiter,
      mileage: fuelLog.mileage,
      note: fuelLog.note,
    );
  }

  /// Общая сумма заправок за выбранный день.
  Future<double> getTotalCostForDate(
      DateTime date,
      ) async {
    final fuelLogs = await getFuelLogsForDate(date);

    return fuelLogs.fold<double>(
      0,
          (total, fuelLog) => total + fuelLog.total,
    );
  }

  /// Общее количество заправленных литров за день.
  Future<double> getTotalLitersForDate(
      DateTime date,
      ) async {
    final fuelLogs = await getFuelLogsForDate(date);

    return fuelLogs.fold<double>(
      0,
          (total, fuelLog) => total + fuelLog.liters,
    );
  }

  /// Краткая сводка по заправкам за выбранный день.
  Future<FuelDaySummary> getDaySummary(
      DateTime date,
      ) async {
    final fuelLogs = await getFuelLogsForDate(date);

    final totalLiters = fuelLogs.fold<double>(
      0,
          (total, fuelLog) => total + fuelLog.liters,
    );

    final totalCost = fuelLogs.fold<double>(
      0,
          (total, fuelLog) => total + fuelLog.total,
    );

    final averagePrice = totalLiters > 0
        ? totalCost / totalLiters
        : 0.0;

    return FuelDaySummary(
      count: fuelLogs.length,
      totalLiters: totalLiters,
      totalCost: totalCost,
      averagePricePerLiter: averagePrice,
    );
  }
}

class FuelDaySummary {
  const FuelDaySummary({
    required this.count,
    required this.totalLiters,
    required this.totalCost,
    required this.averagePricePerLiter,
  });

  final int count;
  final double totalLiters;
  final double totalCost;
  final double averagePricePerLiter;
}