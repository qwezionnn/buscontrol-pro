import 'dart:convert';

import '../database/database_helper.dart';
import 'settings_repository.dart';

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
    required this.reserveFund,
    required this.reserveTransferNet,
    required this.reserveSpent,
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
  final Map<String, double> creditAllocations;
  final double vehicleTransferNet;
  final double creditTransferNet;
  final double personalTransferNet;
  final double reserveFund;
  final double reserveTransferNet;
  final double reserveSpent;

  double get allocatedCreditFund =>
      creditAllocations.values.fold<double>(0, (sum, value) => sum + value);

  double get availableIncome => orderIncome + receivedTripIncome;

  double get vehicleCash =>
      vehicleFund - fuelCost - otherExpenses + vehicleTransferNet;
  double get creditCash => creditFund + creditTransferNet;
  double get personalCash => personalFund;
  double get reserveCash => reserveFund - reserveSpent + reserveTransferNet;

  // Заначка теперь обычный денежный счёт. Обязательное "вернуть" не считаем.
  double get reserveDebt => 0;
}

class FinancialAssistantRepository {
  FinancialAssistantRepository._();

  static final FinancialAssistantRepository instance =
      FinancialAssistantRepository._();

  final DatabaseHelper _database = DatabaseHelper.instance;
  final SettingsRepository _settings = SettingsRepository.instance;

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

    var vehicleFund = 0.0;
    var creditFund = 0.0;
    var personalFund = 0.0;
    var reserveFund = 0.0;

    void applyDefaultDistribution(double amount) {
      vehicleFund += amount * settings.workFundPercent / 100;
      creditFund += amount * settings.loanFundPercent / 100;
      personalFund += amount * settings.personalFundPercent / 100;
    }

    double creditPercentFromDistribution(String? raw) {
      if (raw == null || raw.trim().isEmpty) return 0;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.values.fold<double>(0, (sum, value) {
            final percent = value is num
                ? value.toDouble()
                : double.tryParse(value.toString()) ?? 0;
            return sum + percent;
          });
        }
      } catch (_) {}
      return 0;
    }

    var orderIncome = 0.0;
    for (final payment in payments) {
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
      orderIncome += amount;

      final vehiclePercent =
          (payment['vehicle_percent'] as num?)?.toDouble();
      final personalPercent =
          (payment['personal_percent'] as num?)?.toDouble();
      final reservePercent =
          (payment['reserve_percent'] as num?)?.toDouble() ?? 0;
      final rawCredits = payment['credit_distribution']?.toString();

      if (vehiclePercent == null ||
          personalPercent == null ||
          rawCredits == null ||
          rawCredits.trim().isEmpty) {
        applyDefaultDistribution(amount);
        continue;
      }

      vehicleFund += amount * vehiclePercent / 100;
      personalFund += amount * personalPercent / 100;
      reserveFund += amount * reservePercent / 100;
      creditFund += amount * creditPercentFromDistribution(rawCredits) / 100;
    }

    final accruedTripIncome = trips
        .where((row) => row['completed'] == 1)
        .fold<double>(0, (sum, row) {
      final price = (row['price'] as num?)?.toDouble() ?? 0;
      final waitHours = (row['wait_hours'] as num?)?.toDouble() ?? 0;
      final waitRate = (row['wait_rate'] as num?)?.toDouble() ?? 0;
      return sum + price + waitHours * waitRate;
    });

    final receivedTripIncome = payouts.fold<double>(
      0,
      (sum, row) => sum + ((row['gross_amount'] as num?)?.toDouble() ?? 0),
    );

    for (final payout in payouts) {
      final amount = (payout['gross_amount'] as num?)?.toDouble() ?? 0;
      final vp = (payout['vehicle_percent'] as num?)?.toDouble();
      final cp = (payout['credit_percent'] as num?)?.toDouble();
      final pp = (payout['personal_percent'] as num?)?.toDouble();
      final rp = (payout['reserve_percent'] as num?)?.toDouble();
      if (vp == null || cp == null || pp == null || rp == null) {
        applyDefaultDistribution(amount);
      } else {
        vehicleFund += amount * vp / 100;
        creditFund += amount * cp / 100;
        personalFund += amount * pp / 100;
        reserveFund += amount * rp / 100;
      }
    }

    final homeFuelSettlements = expenses
        .where((row) =>
            row['category']?.toString() == 'Домашнее топливо' &&
            (row['payment_account']?.toString() ?? 'vehicle') == 'vehicle')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );

    final fuelCost = fuel
            .where((row) =>
                (row['payment_account']?.toString() ?? 'vehicle') == 'vehicle')
            .fold<double>(
              0,
              (sum, row) =>
                  sum + ((row['total'] as num?)?.toDouble() ?? 0),
            ) +
        homeFuelSettlements;

    final otherExpenses = expenses
        .where((row) =>
            row['category']?.toString() != 'Домашнее топливо' &&
            (row['payment_account']?.toString() ?? 'vehicle') == 'vehicle')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );

    final reserveFuelCost = fuel
        .where((row) => row['payment_account']?.toString() == 'reserve')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0),
        );
    final reserveExpenseCost = expenses
        .where((row) => row['payment_account']?.toString() == 'reserve')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );
    final reserveSpent = reserveFuelCost + reserveExpenseCost;

    var vehicleTransferNet = 0.0;
    var creditTransferNet = 0.0;
    var personalTransferNet = 0.0;
    var reserveTransferNet = 0.0;

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
        case 'reserve':
          reserveTransferNet += delta;
          break;
      }
    }

    for (final transfer in transfers) {
      final amount = (transfer['amount'] as num?)?.toDouble() ?? 0;
      if (amount <= 0) continue;
      applyTransfer(transfer['from_account']?.toString() ?? '', -amount);
      applyTransfer(transfer['to_account']?.toString() ?? '', amount);
    }

    final creditAllocations = <String, double>{
      if (creditFund.abs() > 0.0001) 'Кредит': creditFund,
    };

    return FinancialSnapshot(
      orderIncome: orderIncome,
      receivedTripIncome: receivedTripIncome,
      accruedTripIncome: accruedTripIncome,
      fuelCost: fuelCost,
      otherExpenses: otherExpenses,
      vehicleFund: vehicleFund,
      creditFund: creditFund,
      personalFund: personalFund,
      reserveFund: reserveFund,
      reserveTransferNet: reserveTransferNet,
      reserveSpent: reserveSpent,
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
      'personal' => double.infinity,
      'reserve' => snapshot.reserveCash,
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

  Future<void> payCredit({required double amount}) {
    return transferFunds(
      fromAccount: 'credit',
      toAccount: 'credit_payment',
      amount: amount,
      note: 'Оплата кредита',
    );
  }

  Future<void> setReserveBalance(double targetAmount) async {
    if (targetAmount < 0) {
      throw ArgumentError('Сумма заначки не может быть отрицательной.');
    }
    final snapshot = await getSnapshot();
    final delta = targetAmount - snapshot.reserveCash;
    if (delta.abs() < 0.005) return;

    if (delta > 0) {
      await _database.addFundTransfer(
        fromAccount: 'adjustment',
        toAccount: 'reserve',
        amount: delta,
        note: 'Ручная корректировка заначки',
      );
    } else {
      await _database.addFundTransfer(
        fromAccount: 'reserve',
        toAccount: 'adjustment',
        amount: -delta,
        note: 'Ручная корректировка заначки',
      );
    }
  }

  Future<List<Map<String, Object?>>> getCreditAccountHistory() async {
    final settings = await _settings.getSettings();
    final payments = await _database.getCompletedOrderPayments();
    final payouts = await _database.getTripPayouts();
    final transfers = await _database.getFundTransfers();
    final history = <Map<String, Object?>>[];

    for (final payment in payments) {
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
      var percent = 0.0;
      final raw = payment['credit_distribution']?.toString();
      if (raw == null || raw.trim().isEmpty) {
        percent = settings.loanFundPercent;
      } else {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            percent = decoded.values.fold<double>(0, (sum, value) {
              return sum +
                  (value is num
                      ? value.toDouble()
                      : double.tryParse(value.toString()) ?? 0);
            });
          }
        } catch (_) {}
      }
      final creditAmount = amount * percent / 100;
      if (creditAmount > 0.005) {
        history.add({
          'kind': 'order',
          'title': 'Из оплаты заказа',
          'amount': creditAmount,
          'date': payment['paid_at']?.toString() ?? '',
          'note': payment['note']?.toString() ?? '',
        });
      }
    }

    for (final payout in payouts) {
      final amount = (payout['gross_amount'] as num?)?.toDouble() ?? 0;
      final percent =
          (payout['credit_percent'] as num?)?.toDouble() ??
              settings.loanFundPercent;
      final creditAmount = amount * percent / 100;
      if (creditAmount > 0.005) {
        history.add({
          'kind': 'payout',
          'title': 'Из выплаты предприятия',
          'amount': creditAmount,
          'date': payout['received_at']?.toString() ?? payout['month']?.toString() ?? '',
          'note': payout['note']?.toString() ?? '',
        });
      }
    }

    for (final row in transfers) {
      final from = row['from_account']?.toString() ?? '';
      final to = row['to_account']?.toString() ?? '';
      if (from != 'credit' && to != 'credit') continue;
      final value = (row['amount'] as num?)?.toDouble() ?? 0;
      final signed = to == 'credit' ? value : -value;
      history.add({
        'kind': to == 'credit_payment' ? 'payment' : 'transfer',
        'title': to == 'credit_payment'
            ? 'Оплата кредита'
            : signed > 0
                ? 'Пополнение счёта Кредит'
                : 'Перевод со счёта Кредит',
        'amount': signed,
        'date': row['transferred_at']?.toString() ?? '',
        'note': row['note']?.toString() ?? '',
      });
    }

    history.sort((a, b) =>
        (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));
    return history;
  }

  Future<List<Map<String, Object?>>> getReserveHistory() async {
    final transfers = await _database.getFundTransfers();
    final expenses =
        await _database.getExpensesBetween('2000-01-01', '2999-12-31');
    final fuel =
        await _database.getFuelLogsBetween('2000-01-01', '2999-12-31');
    final payments = await _database.getCompletedOrderPayments();
    final payouts = await _database.getTripPayouts();
    final history = <Map<String, Object?>>[];

    for (final payment in payments) {
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
      final percent = (payment['reserve_percent'] as num?)?.toDouble() ?? 0;
      final reserveAmount = amount * percent / 100;
      if (reserveAmount <= 0.005) continue;
      history.add({
        'kind': 'order',
        'title': 'Из оплаты заказа',
        'amount': reserveAmount,
        'date': payment['paid_at']?.toString() ?? '',
        'note': payment['note']?.toString() ?? '',
      });
    }

    for (final payout in payouts) {
      final amount = (payout['gross_amount'] as num?)?.toDouble() ?? 0;
      final percent = (payout['reserve_percent'] as num?)?.toDouble() ?? 0;
      final reserveAmount = amount * percent / 100;
      if (reserveAmount <= 0.005) continue;
      history.add({
        'kind': 'payout',
        'title': 'Из выплаты предприятия',
        'amount': reserveAmount,
        'date': payout['received_at']?.toString() ?? payout['month']?.toString() ?? '',
        'note': payout['note']?.toString() ?? '',
      });
    }

    for (final row in transfers) {
      final from = row['from_account']?.toString() ?? '';
      final to = row['to_account']?.toString() ?? '';
      if (from != 'reserve' && to != 'reserve') continue;
      final value = (row['amount'] as num?)?.toDouble() ?? 0;
      final signed = to == 'reserve' ? value : -value;
      final adjustment = from == 'adjustment' || to == 'adjustment';
      history.add({
        'kind': adjustment ? 'adjustment' : 'transfer',
        'title': adjustment
            ? 'Корректировка заначки'
            : signed > 0
                ? 'Пополнение заначки'
                : 'Снятие из заначки',
        'amount': signed,
        'date': row['transferred_at']?.toString() ?? '',
        'note': row['note']?.toString() ?? '',
      });
    }

    for (final row in expenses) {
      if (row['payment_account']?.toString() != 'reserve') continue;
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      history.add({
        'kind': 'expense',
        'title': row['description']?.toString().trim().isNotEmpty == true
            ? row['description'].toString()
            : row['category']?.toString() ?? 'Расход',
        'amount': -amount,
        'date': '${row['date'] ?? ''} ${row['time'] ?? ''}'.trim(),
        'note': row['category']?.toString() ?? '',
      });
    }

    for (final row in fuel) {
      if (row['payment_account']?.toString() != 'reserve') continue;
      final amount = (row['total'] as num?)?.toDouble() ?? 0;
      if (amount <= 0.005) continue;
      history.add({
        'kind': 'fuel',
        'title': 'Топливо',
        'amount': -amount,
        'date': '${row['date'] ?? ''} ${row['time'] ?? ''}'.trim(),
        'note': row['note']?.toString() ?? '',
      });
    }

    history.sort((a, b) =>
        (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));
    return history;
  }

  Future<List<Map<String, Object?>>> getFundTransfers() {
    return _database.getFundTransfers();
  }

  Future<void> deleteFundTransfer(int id) {
    return _database.deleteFundTransfer(id);
  }

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  Future<double> getTripIncomeTarget({
    required DateTime month,
    required double calculatedAmount,
  }) async {
    final vehicleId = await _database.getActiveVehicleId();
    final raw = await _database.getSetting(
      'trip_income_target_${vehicleId}_${_monthKey(month)}',
    );
    return double.tryParse(raw ?? '') ?? calculatedAmount;
  }

  Future<void> setTripIncomeTarget({
    required DateTime month,
    required double amount,
  }) async {
    if (amount < 0) {
      throw ArgumentError('Начисленная сумма не может быть отрицательной.');
    }
    final vehicleId = await _database.getActiveVehicleId();
    await _database.setSetting(
      'trip_income_target_${vehicleId}_${_monthKey(month)}',
      amount.toString(),
    );
  }

  Future<List<Map<String, Object?>>> getTripPayoutsForMonth(
    DateTime month,
  ) async {
    final key = _monthKey(month);
    final rows = await _database.getTripPayouts();
    return rows.where((row) => row['month']?.toString() == key).toList();
  }

  Future<double> getTripPayoutTotal(DateTime month) async {
    final rows = await getTripPayoutsForMonth(month);
    return rows.fold<double>(
      0,
      (sum, row) => sum + ((row['gross_amount'] as num?)?.toDouble() ?? 0),
    );
  }

  Future<void> updateTripPayout({
    required int id,
    required double amount,
    required double vehiclePercent,
    required double creditPercent,
    required double personalPercent,
    required double reservePercent,
    String? note,
  }) {
    if (amount <= 0) {
      throw ArgumentError('Сумма выплаты должна быть больше нуля.');
    }
    return _database.updateTripPayout(
      id: id,
      grossAmount: amount,
      vehiclePercent: vehiclePercent,
      creditPercent: creditPercent,
      personalPercent: personalPercent,
      reservePercent: reservePercent,
      note: note,
    );
  }

  Future<void> receiveTripPayout({
    required DateTime month,
    required double amount,
    double? vehiclePercent,
    double? creditPercent,
    double? personalPercent,
    double? reservePercent,
    String? note,
  }) {
    final key = _monthKey(month);
    return _database.saveTripPayout(
      month: key,
      grossAmount: amount,
      vehiclePercent: vehiclePercent,
      creditPercent: creditPercent,
      personalPercent: personalPercent,
      reservePercent: reservePercent,
      note: note,
    );
  }

  Future<bool> isTripPayoutReceived(DateTime month) async {
    return (await getTripPayoutTotal(month)) > 0.005;
  }
}
