
class Credit {
  const Credit({
    this.id,
    required this.title,
    required this.initialAmount,
    required this.remainingAmount,
    required this.incomePercent,
    this.monthlyPayment,
    this.paymentDay,
    this.vehicleId,
    this.note,
    this.archived = false,
  });

  final int? id;
  final String title;
  final double initialAmount;
  final double remainingAmount;

  /// Доля от каждого фактически полученного дохода.
  final double incomePercent;

  final double? monthlyPayment;
  final int? paymentDay;
  final int? vehicleId;
  final String? note;
  final bool archived;

  bool get isClosed => remainingAmount <= 0.001;

  factory Credit.fromMap(Map<String, Object?> map) {
    return Credit(
      id: (map['id'] as num?)?.toInt(),
      title: map['title']?.toString() ?? 'Кредит',
      initialAmount:
          (map['initial_amount'] as num?)?.toDouble() ?? 0,
      remainingAmount:
          (map['remaining_amount'] as num?)?.toDouble() ?? 0,
      incomePercent:
          (map['income_percent'] as num?)?.toDouble() ?? 0,
      monthlyPayment:
          (map['monthly_payment'] as num?)?.toDouble(),
      paymentDay: (map['payment_day'] as num?)?.toInt(),
      vehicleId: (map['vehicle_id'] as num?)?.toInt(),
      note: map['note']?.toString(),
      archived: (map['archived'] as num?)?.toInt() == 1,
    );
  }
}

class CreditPayment {
  const CreditPayment({
    this.id,
    required this.creditId,
    required this.amount,
    required this.paidAt,
    this.note,
  });

  final int? id;
  final int creditId;
  final double amount;
  final DateTime paidAt;
  final String? note;

  factory CreditPayment.fromMap(Map<String, Object?> map) {
    return CreditPayment(
      id: (map['id'] as num?)?.toInt(),
      creditId: (map['credit_id'] as num).toInt(),
      amount: (map['amount'] as num).toDouble(),
      paidAt: DateTime.parse(map['paid_at'].toString()),
      note: map['note']?.toString(),
    );
  }
}
