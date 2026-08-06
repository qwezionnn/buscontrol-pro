class DailyLog {
  const DailyLog({
    this.id,
    required this.date,
    this.startMileage,
    this.endMileage,
    this.completedAt,
  });

  final int? id;

  /// Дата в формате YYYY-MM-DD.
  final String date;

  /// Пробег в начале дня.
  final int? startMileage;

  /// Конечный пробег дня.
  final int? endMileage;

  /// Время завершения дня в формате ISO 8601.
  final String? completedAt;

  bool get isCompleted => endMileage != null;

  int? get distance {
    final start = startMileage;
    final end = endMileage;

    if (start == null || end == null) {
      return null;
    }

    return end - start;
  }

  DailyLog copyWith({
    int? id,
    String? date,
    int? startMileage,
    int? endMileage,
    String? completedAt,
  }) {
    return DailyLog(
      id: id ?? this.id,
      date: date ?? this.date,
      startMileage: startMileage ?? this.startMileage,
      endMileage: endMileage ?? this.endMileage,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': date,
      'start_mileage': startMileage,
      'end_mileage': endMileage,
      'completed_at': completedAt,
    };
  }

  factory DailyLog.fromMap(Map<String, Object?> map) {
    return DailyLog(
      id: map['id'] as int?,
      date: map['date']?.toString() ?? '',
      startMileage: (map['start_mileage'] as num?)?.toInt(),
      endMileage: (map['end_mileage'] as num?)?.toInt(),
      completedAt: map['completed_at']?.toString(),
    );
  }

  String get startMileageText {
    if (startMileage == null) {
      return 'Не указан';
    }

    return '$startMileage км';
  }

  String get endMileageText {
    if (endMileage == null) {
      return 'Не указан';
    }

    return '$endMileage км';
  }

  String get distanceText {
    final value = distance;

    if (value == null) {
      return 'Ожидает конечный пробег';
    }

    return '$value км';
  }
}