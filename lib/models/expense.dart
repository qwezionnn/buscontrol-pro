class Expense {
  const Expense({
    this.id,
    required this.date,
    this.time,
    required this.category,
    this.description,
    required this.amount,
  });

  final int? id;

  /// Дата в формате YYYY-MM-DD.
  final String date;

  /// Время в формате HH:mm.
  final String? time;

  /// Категория расхода:
  /// мойка, ремонт, запчасти, страховка и т.д.
  final String category;

  /// Дополнительное описание.
  final String? description;

  /// Сумма расхода.
  final double amount;

  Expense copyWith({
    int? id,
    String? date,
    String? time,
    String? category,
    String? description,
    double? amount,
  }) {
    return Expense(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': date,
      'time': time,
      'category': category,
      'description': description,
      'amount': amount,
    };
  }

  factory Expense.fromMap(Map<String, Object?> map) {
    return Expense(
      id: map['id'] as int?,
      date: map['date']?.toString() ?? '',
      time: map['time']?.toString(),
      category: map['category']?.toString() ?? '',
      description: map['description']?.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  String get amountText {
    return '${amount.toStringAsFixed(0)} ₽';
  }

  String get detailsText {
    final parts = <String>[
      if (time != null && time!.isNotEmpty) time!,
      category,
    ];

    return parts.join(' · ');
  }
}