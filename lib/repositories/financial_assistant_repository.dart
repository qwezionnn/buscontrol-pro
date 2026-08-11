import 'dart:convert';

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
    required this.vehicleTransferNet,
    required this.creditTransferNet,
    required this.personalTransferNet,
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

  /// Чистое изменение счёта из-за ручных переводов между фондами.
  final double vehicleTransferNet;
  final double creditTransferNet;
  final double personalTransferNet;

  double get allocatedCreditFund =>
      creditAllocations.values.fold<double>(0, (sum, value) => sum + value);

  double get availableIncome => orderIncome + receivedTripIncome;

  /// Текущие доступные остатки после расходов и ручных переводов.
  double get vehicleCash =>
      vehicleFund - fuelCost - otherExpenses + vehicleTransferNet;
  double get creditCash => creditFund + creditTransferNet;
  double get personalCash => personalFund + personalTransferNet;
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
    final trips =
        await _database.getTripsBetween('2000-01-01', '2999-12-31');
    final payouts = await _database.getTripPayouts();
    final fuel =
        await _database.getFuelLogsBetween('2000-01-01', '2999-12-31');
    final expenses =
        await _database.getExpensesBetween('2000-01-01', '2999-12-31');
    final payments = await _database.getCompletedOrderPayments();
    final transfers = await _database.getFundTransfers();

    final credits = await _credits.getCredits();
    final activeVehicleId = await _database.getActiveVehicleId();
    final activeCredits = credits
        .where(
          (credit) =>
              !credit.archived &&
              !credit.isClosed &&
              (credit.vehicleId == null ||
                  credit.vehicleId == activeVehicleId),
        )
        .toList();

    final creditAllocations = <String, double>{};
    var vehicleFund = 0.0;
    var personalFund = 0.0;

    void addCreditAmount(String title, double amount) {
      if (amount.abs() <= 0.0001) return;
      creditAllocations[title] =
          (creditAllocations[title] ?? 0) + amount;
    }

    void applyDefaultDistribution(double amount) {
      vehicleFund += amount * settings.workFundPercent / 100;
      personalFund += amount * settings.personalFundPercent / 100;

      if (activeCredits.isEmpty) {
        addCreditAmount(
          'Кредит',
          amount * settings.loanFundPercent / 100,
        );
        return;
      }

      final namedCreditPercent = activeCredits.fold<double>(
        0,
        (sum, credit) => sum + credit.incomePercent,
      );

      for (final credit in activeCredits) {
        addCreditAmount(
          credit.title,
          amount * credit.incomePercent / 100,
        );
      }

      final reservePercent =
          (settings.loanFundPercent - namedCreditPercent)
              .clamp(0, double.infinity)
              .toDouble();
      if (reservePercent > 0.001) {
        addCreditAmount(
          'Кредитный резерв',
          amount * reservePercent / 100,
        );
      }
    }

    var orderIncome = 0.0;
    for (final payment in payments) {
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
      orderIncome += amount;

      final vehiclePercent =
          (payment['vehicle_percent'] as num?)?.toDouble();
      final personalPercent =
          (payment['personal_percent'] as num?)?.toDouble();
      final rawCredits = payment['credit_distribution']?.toString();

      if (vehiclePercent == null ||
          personalPercent == null ||
          rawCredits == null ||
          rawCredits.trim().isEmpty) {
        // Старые оплаты, созданные до BusControl PRO 4.1,
        // продолжают использовать общие проценты из настроек.
        applyDefaultDistribution(amount);
        continue;
      }

      vehicleFund += amount * vehiclePercent / 100;
      personalFund += amount * personalPercent / 100;

      try {
        final decoded = jsonDecode(rawCredits);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final percent = entry.value is num
                ? (entry.value as num).toDouble()
                : double.tryParse(entry.value.toString()) ?? 0;
            addCreditAmount(
              entry.key.toString(),
              amount * percent / 100,
            );
          }
        }
      } catch (_) {
        // Если старая/повреждённая запись не читается,
        // оставляем уже рассчитанные машину и личные деньги.
      }
    }

    final accruedTripIncome = trips
        .where((row) => row['completed'] == 1)
        .fold<double>(
          0,
          (sum, row) =>
              sum + ((row['price'] as num?)?.toDouble() ?? 0),
        );

    final receivedTripIncome = payouts.fold<double>(
      0,
      (sum, row) =>
          sum + ((row['gross_amount'] as num?)?.toDouble() ?? 0),
    );

    // Выплаты за обычные рейсы распределяются по общим настройкам.
    // Индивидуальное распределение применяется только к оплатам заказов.
    for (final payout in payouts) {
      final amount =
          (payout['gross_amount'] as num?)?.toDouble() ?? 0;
      applyDefaultDistribution(amount);
    }

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
    final otherExpenses = expenses
        .where((row) => row['category']?.toString() != 'Домашнее топливо')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );

    var vehicleTransferNet = 0.0;
    var creditTransferNet = 0.0;
    var personalTransferNet = 0.0;

    void applyTransfer(String account, double delta) {
      switch (account) {
        case 'vehicle':
          vehicleTransferNet += delta;
          break;
        case 'credit':
          creditTransferNet += delta;
          break;
        case 'personal':
          personalTransferNet += delta;
          break;
      }
    }

    for (final transfer in transfers) {
      final amount = (transfer['amount'] as num?)?.toDouble() ?? 0;
      if (amount <= 0) continue;
      applyTransfer(transfer['from_account']?.toString() ?? '', -amount);
      applyTransfer(transfer['to_account']?.toString() ?? '', amount);
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
      vehicleFund: vehicleFund,
      creditFund: allocatedCredit,
      personalFund: personalFund,
      pendingTripPayout: (accruedTripIncome - receivedTripIncome)
          .clamp(0, double.infinity)
          .toDouble(),
      creditAllocations: creditAllocations,
      vehicleTransferNet: vehicleTransferNet,
      creditTransferNet: creditTransferNet,
      personalTransferNet: personalTransferNet,
    );
  }

  Future<void> transferFunds({
    required String fromAccount,
    required String toAccount,
    required double amount,
    String? note,
  }) async {
    if (fromAccount == toAccount) {
      throw ArgumentError('Выберите разные счета.');
    }
    if (amount <= 0) {
      throw ArgumentError('Введите сумму больше нуля.');
    }

    final snapshot = await getSnapshot();
    final available = switch (fromAccount) {
      'vehicle' => snapshot.vehicleCash,
      'credit' => snapshot.creditCash,
      'personal' => snapshot.personalCash,
      _ => 0.0,
    };

    if (amount - available > 0.005) {
      throw StateError(
        'На выбранном счёте недостаточно средств. '
        'Доступно ${available.toStringAsFixed(0)} ₽.',
      );
    }

    await _database.addFundTransfer(
      fromAccount: fromAccount,
      toAccount: toAccount,
      amount: amount,
      note: note,
    );
  }

  Future<List<Map<String, Object?>>> getFundTransfers() {
    return _database.getFundTransfers();
  }

  Future<void> deleteFundTransfer(int id) {
    return _database.deleteFundTransfer(id);
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
