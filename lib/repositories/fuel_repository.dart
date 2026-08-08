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

  Future<List<FuelLog>> getFuelLogsForDate(DateTime date) async {
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

  Future<int> addFuelLog(FuelLog fuelLog) {
    return _databaseHelper.addFuelLog(
      date: fuelLog.date,
      time: fuelLog.time,
      liters: fuelLog.liters,
      pricePerLiter: fuelLog.pricePerLiter,
      source: fuelLog.source,
      mileage: fuelLog.mileage,
      note: fuelLog.note,
    );
  }

  Future<void> deleteFuelLog(int id) async {
    await _databaseHelper.deleteFuelLog(id);
  }

  Future<double> getHomeLitersForMonth(DateTime month) async {
    final from =
        '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final to =
        '${month.year}-${month.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final rows = await _databaseHelper.getFuelLogsBetween(from, to);
    return rows
        .where((row) => row['source']?.toString() == 'home')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['liters'] as num?)?.toDouble() ?? 0),
        );
  }

  Future<double> getTotalCostForDate(DateTime date) async {
    final fuelLogs = await getFuelLogsForDate(date);
    return fuelLogs.fold<double>(
      0,
      (total, fuelLog) => total + fuelLog.total,
    );
  }

  Future<double> getTotalLitersForDate(DateTime date) async {
    final fuelLogs = await getFuelLogsForDate(date);
    return fuelLogs.fold<double>(
      0,
      (total, fuelLog) => total + fuelLog.liters,
    );
  }

  Future<FuelDaySummary> getDaySummary(DateTime date) async {
    final fuelLogs = await getFuelLogsForDate(date);
    final totalLiters = fuelLogs.fold<double>(
      0,
      (total, fuelLog) => total + fuelLog.liters,
    );
    final totalCost = fuelLogs.fold<double>(
      0,
      (total, fuelLog) => total + fuelLog.total,
    );
    final stationLiters = fuelLogs
        .where((log) => log.isStation)
        .fold<double>(0, (sum, log) => sum + log.liters);
    final stationCost = fuelLogs
        .where((log) => log.isStation)
        .fold<double>(0, (sum, log) => sum + log.total);
    final averagePrice =
        stationLiters > 0 ? stationCost / stationLiters : 0.0;

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
