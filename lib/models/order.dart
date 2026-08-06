enum OrderType {
  hourly,
  intercity,
}

enum OrderStatus {
  planned,
  completed,
  cancelled,
}

class Order {
  const Order({
    this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.type,
    this.hours,
    this.kilometers,
    required this.rate,
    required this.amount,
    this.status = OrderStatus.planned,
    this.paid = false,
    this.paidAmount = 0,
    this.reminderHours = 12,
    this.note,
  });

  final int? id;

  /// Название заказа, например «Аэропорт».
  final String title;

  /// Дата в формате YYYY-MM-DD.
  final String date;

  /// Время в формате HH:mm.
  final String time;

  final OrderType type;

  /// Количество часов для почасового заказа.
  final double? hours;

  /// Количество километров для межгорода.
  final double? kilometers;

  /// Ставка за час или за километр.
  final double rate;

  /// Итоговая стоимость заказа.
  final double amount;

  final OrderStatus status;

  /// Получена ли вся оплата от клиента.
  final bool paid;

  /// Фактически полученная сумма. Может быть меньше стоимости заказа.
  final double paidAmount;

  double get remainingAmount {
    final value = amount - paidAmount;
    return value > 0 ? value : 0;
  }

  bool get isUnpaid => paidAmount <= 0.001;
  bool get isPartiallyPaid =>
      paidAmount > 0.001 && remainingAmount > 0.001;
  bool get isFullyPaid => remainingAmount <= 0.001;

  /// За сколько часов напомнить о заказе.
  final int reminderHours;

  final String? note;

  bool get isPlanned => status == OrderStatus.planned;

  bool get isCompleted => status == OrderStatus.completed;

  bool get isCancelled => status == OrderStatus.cancelled;

  String get quantityText {
    switch (type) {
      case OrderType.hourly:
        return '${_formatNumber(hours ?? 0)} ч';

      case OrderType.intercity:
        return '${_formatNumber(kilometers ?? 0)} км';
    }
  }

  Order copyWith({
    int? id,
    String? title,
    String? date,
    String? time,
    OrderType? type,
    double? hours,
    double? kilometers,
    double? rate,
    double? amount,
    OrderStatus? status,
    bool? paid,
    double? paidAmount,
    int? reminderHours,
    String? note,
  }) {
    return Order(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      type: type ?? this.type,
      hours: hours ?? this.hours,
      kilometers: kilometers ?? this.kilometers,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paid: paid ?? this.paid,
      paidAmount: paidAmount ?? this.paidAmount,
      reminderHours: reminderHours ?? this.reminderHours,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'time': time,
      'type': type.name,
      'hours': hours,
      'kilometers': kilometers,
      'rate': rate,
      'amount': amount,
      'status': status.name,
      'paid': paid ? 1 : 0,
      'paid_amount': paidAmount,
      'reminder_hours': reminderHours,
      'note': note,
    };
  }

  factory Order.fromMap(Map<String, Object?> map) {
    return Order(
      id: map['id'] as int?,
      title: map['title']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      time: map['time']?.toString() ?? '',
      type: _orderTypeFromString(
        map['type']?.toString(),
      ),
      hours: (map['hours'] as num?)?.toDouble(),
      kilometers: (map['kilometers'] as num?)?.toDouble(),
      rate: (map['rate'] as num?)?.toDouble() ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: _orderStatusFromString(
        map['status']?.toString(),
      ),
      paid: map['paid'] == 1,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ??
          (map['paid'] == 1
              ? (map['amount'] as num?)?.toDouble() ?? 0
              : 0),
      reminderHours:
      (map['reminder_hours'] as num?)?.toInt() ?? 12,
      note: map['note']?.toString(),
    );
  }

  static OrderType _orderTypeFromString(String? value) {
    switch (value) {
      case 'intercity':
        return OrderType.intercity;

      case 'hourly':
      default:
        return OrderType.hourly;
    }
  }

  static OrderStatus _orderStatusFromString(String? value) {
    switch (value) {
      case 'completed':
        return OrderStatus.completed;

      case 'cancelled':
        return OrderStatus.cancelled;

      case 'planned':
      default:
        return OrderStatus.planned;
    }
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }
}