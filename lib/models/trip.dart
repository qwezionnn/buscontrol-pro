enum TripType {
  morning,
  evening,
  extra,
}

class Trip {
  const Trip({
    this.id,
    required this.date,
    this.time,
    required this.title,
    required this.type,
    required this.price,
    this.completed = false,
  });

  final int? id;
  final String date;
  final String? time;
  final String title;
  final TripType type;
  final double price;
  final bool completed;

  Trip copyWith({
    int? id,
    String? date,
    String? time,
    String? title,
    TripType? type,
    double? price,
    bool? completed,
  }) {
    return Trip(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      title: title ?? this.title,
      type: type ?? this.type,
      price: price ?? this.price,
      completed: completed ?? this.completed,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': date,
      'time': time,
      'title': title,
      'type': type.name,
      'price': price,
      'completed': completed ? 1 : 0,
    };
  }

  factory Trip.fromMap(Map<String, Object?> map) {
    return Trip(
      id: map['id'] as int?,
      date: map['date']?.toString() ?? '',
      time: map['time']?.toString(),
      title: map['title']?.toString() ?? '',
      type: _tripTypeFromString(
        map['type']?.toString(),
      ),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      completed: map['completed'] == 1,
    );
  }

  static TripType _tripTypeFromString(String? value) {
    switch (value) {
      case 'morning':
        return TripType.morning;
      case 'evening':
        return TripType.evening;
      case 'extra':
      default:
        return TripType.extra;
    }
  }
}