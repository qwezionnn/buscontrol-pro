class MaintenanceItem {
  const MaintenanceItem({
    this.id,
    required this.title,
    required this.kind,
    this.intervalValue,
    this.lastValue,
    this.nextValue,
    this.note,
    this.completed = false,
  });

  final int? id;
  final String title;
  final String kind;
  final int? intervalValue;
  final int? lastValue;
  final int? nextValue;
  final String? note;
  final bool completed;

  bool get isMileage => kind == 'mileage';
  bool get isDate => kind == 'date';

  factory MaintenanceItem.fromMap(Map<String, Object?> map) {
    return MaintenanceItem(
      id: (map['id'] as num?)?.toInt(),
      title: map['title']?.toString() ?? '',
      kind: map['kind']?.toString() ?? 'mileage',
      intervalValue: (map['interval_value'] as num?)?.toInt(),
      lastValue: (map['last_value'] as num?)?.toInt(),
      nextValue: (map['next_value'] as num?)?.toInt(),
      note: map['note']?.toString(),
      completed: map['completed'] == 1,
    );
  }
}
