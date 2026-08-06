class FuelLog {
  const FuelLog({
    this.id,
    required this.date,
    this.time,
    required this.liters,
    required this.pricePerLiter,
    required this.total,
    this.mileage,
    this.note,
  });

  final int? id;

  /// Дата в формате YYYY-MM-DD.
  final String date;

  /// Время в формате HH:mm.
  final String? time;

  /// Количество заправленных литров.
  final double liters;

  /// Цена одного литра.
  final double pricePerLiter;

  /// Общая стоимость заправки.
  final double total;

  /// Пробег в момент заправки.
  final int? mileage;

  final String? note;

  FuelLog copyWith({
    int? id,
    String? date,
    String? time,
    double? liters,
    double? pricePerLiter,
    double? total,
    int? mileage,
    String? note,
  }) {
    return FuelLog(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      liters: liters ?? this.liters,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      total: total ?? this.total,
      mileage: mileage ?? this.mileage,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': date,
      'time': time,
      'liters': liters,
      'price_per_liter': pricePerLiter,
      'total': total,
      'mileage': mileage,
      'note': note,
    };
  }

  factory FuelLog.fromMap(Map<String, Object?> map) {
    return FuelLog(
      id: map['id'] as int?,
      date: map['date']?.toString() ?? '',
      time: map['time']?.toString(),
      liters: (map['liters'] as num?)?.toDouble() ?? 0,
      pricePerLiter:
      (map['price_per_liter'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      mileage: (map['mileage'] as num?)?.toInt(),
      note: map['note']?.toString(),
    );
  }

  String get litersText {
    return '${_formatNumber(liters)} л';
  }

  String get priceText {
    return '${pricePerLiter.toStringAsFixed(2)} ₽/л';
  }

  String get totalText {
    return '${total.toStringAsFixed(0)} ₽';
  }

  String get mileageText {
    if (mileage == null) {
      return 'Пробег не указан';
    }

    return '$mileage км';
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }
}