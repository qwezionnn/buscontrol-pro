import '../database/database_helper.dart';
import 'settings_repository.dart';
import 'credit_repository.dart';

class FinancialSnapshot {
  const FinancialSnapshot({
    required this.orderIncome,
    required this.receivedTripIncome,
    required this.accruedTripIncome,
    required this.fuelCost,
    required this.otherExpenses,
    required this.vehicleFund,
    required this.creditFund,
    required this.personalFund,
    required this.pendingTripPayout,
    required this.creditAllocations,
  });

  final double orderIncome;
  final double receivedTripIncome;
  final double accruedTripIncome;
  final double fuelCost;
  final double otherExpenses;
  final double vehicleFund;
  final double creditFund;
  final double personalFund;
  final double pendingTripPayout;

  /// Сумма, рассчитанная отдельно для каждого активного кредита.
  final Map<String, double> creditAllocations;

  double get allocatedCreditFund =>
      creditAllocations.values.fold<double>(0, (sum, value) => sum + value);

  double get availableIncome => orderIncome + receivedTripIncome;
  double get vehicleCash => vehicleFund - fuelCost - otherExpenses;
}

class FinancialAssistantRepository {
  FinancialAssistantRepository._();

  static final FinancialAssistantRepository instance =
      FinancialAssistantRepository._();

  final DatabaseHelper _database = DatabaseHelper.instance;
  final SettingsRepository _settings = SettingsRepository.instance;
  final CreditRepository _credits = CreditRepository.instance;

  Future<FinancialSnapshot> getSnapshot() async {
    final settings = await _settings.getSettings();
    final orders = await _database.getOrdersBetween('2000-01-01', '2999-12-31');
    final trips = await _database.getTripsBetween('2000-01-01', '2999-12-31');
    final payouts = await _database.getTripPayouts();
    final fuel = await _database.getFuelLogsBetween('2000-01-01', '2999-12-31');
    final expenses =
        await _database.getExpensesBetween('2000-01-01', '2999-12-31');

    final orderIncome = orders
        .where((row) => row['status'] == 'completed')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['paid_amount'] as num?)?.toDouble() ?? 0),
        );

    final accruedTripIncome = trips
        .where((row) => row['completed'] == 1)
        .fold<double>(
          0,
          (sum, row) => sum + ((row['price'] as num?)?.toDouble() ?? 0),
        );

    final receivedTripIncome = payouts.fold<double>(
      0,
      (sum, row) => sum + ((row['gross_amount'] as num?)?.toDouble() ?? 0),
    );

    final fuelCost = fuel.fold<double>(
      0,
      (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0),
    );
    final otherExpenses = expenses.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );

    final available = orderIncome + receivedTripIncome;
    final credits = await _credits.getCredits();
    final activeVehicleId = await _database.getActiveVehicleId();
    final activeCredits = credits.where(
      (credit) =>
          !credit.archived &&
          !credit.isClosed &&
          (credit.vehicleId == null || credit.vehicleId == activeVehicleId),
    );
    final creditAllocations = <String, double>{
      for (final credit in activeCredits)
        credit.title: available * credit.incomePercent / 100,
    };
    final namedCreditPercent = activeCredits.fold<double>(
      0,
      (sum, credit) => sum + credit.incomePercent,
    );
    final reservePercent =
        (settings.loanFundPercent - namedCreditPercent)
            .clamp(0, double.infinity)
            .toDouble();
    if (creditAllocations.isNotEmpty && reservePercent > 0.001) {
      creditAllocations['Кредитный резерв'] =
          available * reservePercent / 100;
    }
    final allocatedCredit = creditAllocations.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );

    return FinancialSnapshot(
      orderIncome: orderIncome,
      receivedTripIncome: receivedTripIncome,
      accruedTripIncome: accruedTripIncome,
      fuelCost: fuelCost,
      otherExpenses: otherExpenses,
      vehicleFund: available * settings.workFundPercent / 100,
      creditFund: creditAllocations.isEmpty
          ? available * settings.loanFundPercent / 100
          : allocatedCredit,
      personalFund: available * settings.personalFundPercent / 100,
      pendingTripPayout: (accruedTripIncome - receivedTripIncome)
          .clamp(0, double.infinity)
          .toDouble(),
      creditAllocations: creditAllocations,
    );
  }

  Future<void> receiveTripPayout({
    required DateTime month,
    required double amount,
    String? note,
  }) {
    final key =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return _database.saveTripPayout(
      month: key,
      grossAmount: amount,
      note: note,
    );
  }

  Future<bool> isTripPayoutReceived(DateTime month) async {
    final key =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return await _database.getTripPayout(key) != null;
  }
}
