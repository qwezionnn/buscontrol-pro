import '../database/database_helper.dart';

class MonthReport {
  const MonthReport({
    required this.completedTrips,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.tripIncome,
    required this.orderIncome,
    required this.fuelLiters,
    required this.fuelCost,
    required this.expenseCost,
    required this.distance,
  });

  final int completedTrips;
  final int completedOrders;
  final int cancelledOrders;
  final double tripIncome;
  final double orderIncome;
  final double fuelLiters;
  final double fuelCost;
  final double expenseCost;
  final int distance;

  double get income => tripIncome + orderIncome;
  double get costs => fuelCost + expenseCost;
  double get profit => income - costs;
}

class DayEvents {
  const DayEvents({
    required this.date,
    required this.trips,
    required this.orders,
    required this.fuelLogs,
    required this.expenses,
    required this.distance,
    required this.startMileage,
    required this.endMileage,
  });

  final String date;
  final List<Map<String, Object?>> trips;
  final List<Map<String, Object?>> orders;
  final List<Map<String, Object?>> fuelLogs;
  final List<Map<String, Object?>> expenses;
  final int? distance;
  final int? startMileage;
  final int? endMileage;

  bool get hasTrips => trips.isNotEmpty;
  bool get hasOrders => orders.isNotEmpty;
  bool get hasFuel => fuelLogs.isNotEmpty;
  bool get hasExpenses => expenses.isNotEmpty;
  bool get hasMileage => distance != null;
}

class ReportRepository {
  ReportRepository._();

  static final ReportRepository instance = ReportRepository._();

  final DatabaseHelper _database = DatabaseHelper.instance;

  String _date(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  DateTime _monthStart(DateTime month) => DateTime(month.year, month.month);

  DateTime _monthEnd(DateTime month) =>
      DateTime(month.year, month.month + 1, 0);

  Future<MonthReport> getMonthReport(DateTime month) async {
    final from = _date(_monthStart(month));
    final to = _date(_monthEnd(month));

    final trips = await _database.getTripsBetween(from, to);
    final orders = await _database.getOrdersBetween(from, to);
    final fuel = await _database.getFuelLogsBetween(from, to);
    final expenses = await _database.getExpensesBetween(from, to);
    final logs = await _database.getDailyLogsBetween(from, to);

    final completedTrips =
        trips.where((row) => row['completed'] == 1).toList();
    final completedOrders =
        orders.where((row) => row['status'] == 'completed').toList();
    final cancelledOrders =
        orders.where((row) => row['status'] == 'cancelled').length;

    final tripIncome = completedTrips.fold<double>(
      0,
      (sum, row) => sum + ((row['price'] as num?)?.toDouble() ?? 0),
    );
    final orderIncome = completedOrders.fold<double>(
      0,
      (sum, row) => sum + ((row['paid_amount'] as num?)?.toDouble() ?? 0),
    );
    final fuelLiters = fuel.fold<double>(
      0,
      (sum, row) => sum + ((row['liters'] as num?)?.toDouble() ?? 0),
    );
    final homeFuelSettlements = expenses
        .where((row) => row['category']?.toString() == 'Домашнее топливо')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );
    final fuelCost = fuel.fold<double>(
          0,
          (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0),
        ) +
        homeFuelSettlements;
    final expenseCost = expenses
        .where((row) => row['category']?.toString() != 'Домашнее топливо')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );
    final distance = logs.fold<int>(
      0,
      (sum, row) {
        final start = (row['start_mileage'] as num?)?.toInt();
        final end = (row['end_mileage'] as num?)?.toInt();
        return start == null || end == null ? sum : sum + end - start;
      },
    );

    return MonthReport(
      completedTrips: completedTrips.length,
      completedOrders: completedOrders.length,
      cancelledOrders: cancelledOrders,
      tripIncome: tripIncome,
      orderIncome: orderIncome,
      fuelLiters: fuelLiters,
      fuelCost: fuelCost,
      expenseCost: expenseCost,
      distance: distance,
    );
  }

  Future<Map<String, DayEvents>> getMonthEvents(DateTime month) async {
    final from = _date(_monthStart(month));
    final to = _date(_monthEnd(month));

    final trips = await _database.getTripsBetween(from, to);
    final orders = await _database.getOrdersBetween(from, to);
    final fuel = await _database.getFuelLogsBetween(from, to);
    final expenses = await _database.getExpensesBetween(from, to);
    final logs = await _database.getDailyLogsBetween(from, to);

    final tripMap = <String, List<Map<String, Object?>>>{};
    final orderMap = <String, List<Map<String, Object?>>>{};
    final fuelMap = <String, List<Map<String, Object?>>>{};
    final expenseMap = <String, List<Map<String, Object?>>>{};
    final distanceMap = <String, int>{};
    final startMileageMap = <String, int>{};
    final endMileageMap = <String, int>{};

    for (final row in trips) {
      tripMap.putIfAbsent(row['date'].toString(), () => []).add(row);
    }
    for (final row in orders) {
      orderMap.putIfAbsent(row['date'].toString(), () => []).add(row);
    }
    for (final row in fuel) {
      fuelMap.putIfAbsent(row['date'].toString(), () => []).add(row);
    }
    for (final row in expenses) {
      expenseMap.putIfAbsent(row['date'].toString(), () => []).add(row);
    }
    for (final row in logs) {
      final start = (row['start_mileage'] as num?)?.toInt();
      final end = (row['end_mileage'] as num?)?.toInt();
      final date = row['date'].toString();
      if (start != null) startMileageMap[date] = start;
      if (end != null) endMileageMap[date] = end;
      if (start != null && end != null) {
        distanceMap[date] = end - start;
      }
    }

    final dates = <String>{
      ...tripMap.keys,
      ...orderMap.keys,
      ...fuelMap.keys,
      ...expenseMap.keys,
      ...distanceMap.keys,
    };

    return {
      for (final date in dates)
        date: DayEvents(
          date: date,
          trips: tripMap[date] ?? const [],
          orders: orderMap[date] ?? const [],
          fuelLogs: fuelMap[date] ?? const [],
          expenses: expenseMap[date] ?? const [],
          distance: distanceMap[date],
          startMileage: startMileageMap[date],
          endMileage: endMileageMap[date],
        ),
    };
  }

  Future<DayEvents> getDayEvents(DateTime date) async {
    final value = _date(date);
    final trips = await _database.getTripsByDate(value);
    final orders = await _database.getOrdersByDate(value);
    final fuel = await _database.getFuelLogsByDate(value);
    final expenses = await _database.getExpensesByDate(value);
    final log = await _database.getDailyLog(value);
    final start = (log?['start_mileage'] as num?)?.toInt();
    final end = (log?['end_mileage'] as num?)?.toInt();

    return DayEvents(
      date: value,
      trips: trips,
      orders: orders,
      fuelLogs: fuel,
      expenses: expenses,
      distance: start != null && end != null ? end - start : null,
      startMileage: start,
      endMileage: end,
    );
  }
}
