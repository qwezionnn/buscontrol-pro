
import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/credit.dart';

class CreditRepository extends ChangeNotifier {
  CreditRepository._();

  static final CreditRepository instance = CreditRepository._();

  final DatabaseHelper _database = DatabaseHelper.instance;

  Future<List<Credit>> getCredits({
    bool includeArchived = false,
  }) async {
    final rows = await _database.getCredits(
      includeArchived: includeArchived,
    );
    return rows.map(Credit.fromMap).toList();
  }

  Future<double> getActivePercentTotal() async {
    final credits = await getCredits();
    return credits
        .where((credit) => !credit.isClosed)
        .fold<double>(
          0,
          (sum, credit) => sum + credit.incomePercent,
        );
  }

  Future<int> addCredit(Credit credit) async {
    final id = await _database.addCredit(
      title: credit.title,
      initialAmount: credit.initialAmount,
      remainingAmount: credit.remainingAmount,
      incomePercent: credit.incomePercent,
      monthlyPayment: credit.monthlyPayment,
      paymentDay: credit.paymentDay,
      vehicleId: credit.vehicleId,
      note: credit.note,
    );
    notifyListeners();
    return id;
  }

  Future<void> updateCredit(Credit credit) async {
    if (credit.id == null) {
      throw ArgumentError('У кредита отсутствует идентификатор.');
    }
    await _database.updateCredit(
      id: credit.id!,
      title: credit.title,
      initialAmount: credit.initialAmount,
      remainingAmount: credit.remainingAmount,
      incomePercent: credit.incomePercent,
      monthlyPayment: credit.monthlyPayment,
      paymentDay: credit.paymentDay,
      vehicleId: credit.vehicleId,
      note: credit.note,
      archived: credit.archived,
    );
    notifyListeners();
  }

  Future<void> addPayment({
    required int creditId,
    required double amount,
    String? note,
  }) async {
    await _database.addCreditPayment(
      creditId: creditId,
      amount: amount,
      note: note,
    );
    notifyListeners();
  }

  Future<List<CreditPayment>> getPayments(int creditId) async {
    final rows = await _database.getCreditPayments(creditId);
    return rows.map(CreditPayment.fromMap).toList();
  }

  Future<void> deleteCredit(int id) async {
    await _database.deleteCredit(id);
    notifyListeners();
  }
}
