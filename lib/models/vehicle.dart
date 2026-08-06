
class Vehicle {
  const Vehicle({
    this.id,
    required this.name,
    this.registrationNumber,
    this.note,
    this.initialMileage,
    this.archived = false,
  });

  final int? id;
  final String name;
  final String? registrationNumber;
  final String? note;
  final int? initialMileage;
  final bool archived;

  String get displayName {
    final number = registrationNumber?.trim() ?? '';
    return number.isEmpty ? name : '$name · $number';
  }

  factory Vehicle.fromMap(Map<String, Object?> map) {
    return Vehicle(
      id: (map['id'] as num?)?.toInt(),
      name: map['name']?.toString() ?? 'Транспорт',
      registrationNumber: map['registration_number']?.toString(),
      note: map['note']?.toString(),
      initialMileage: (map['initial_mileage'] as num?)?.toInt(),
      archived: (map['archived'] as num?)?.toInt() == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'registration_number': registrationNumber,
      'note': note,
      'initial_mileage': initialMileage,
      'archived': archived ? 1 : 0,
    };
  }
}
