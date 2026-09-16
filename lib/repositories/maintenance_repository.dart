import '../database/database_helper.dart';
import '../models/maintenance_item.dart';
import '../services/notification_service.dart';

class MaintenanceRepository {
  MaintenanceRepository._();

  static final MaintenanceRepository instance = MaintenanceRepository._();

  final DatabaseHelper _database = DatabaseHelper.instance;

  Future<List<MaintenanceItem>> getItems() async {
    final rows = await _database.getMaintenanceItems();
    return rows.map(MaintenanceItem.fromMap).toList();
  }

  Future<int> addMileageItem({
    required String title,
    required int intervalKm,
    required int lastMileage,
    String? note,
  }) {
    return _database.addMaintenanceItem(
      title: title,
      kind: 'mileage',
      intervalValue: intervalKm,
      lastValue: lastMileage,
      nextValue: lastMileage + intervalKm,
      note: note,
    );
  }

  Future<int> addDateItem({
    required String title,
    required DateTime date,
    String? note,
  }) async {
    final id = await _database.addMaintenanceItem(
      title: title,
      kind: 'date',
      nextValue: date.millisecondsSinceEpoch,
      note: note,
    );
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.scheduleMaintenanceReminders(
      itemId: id,
      title: title,
      dueDate: date,
    );
    return id;
  }

  Future<void> completeMileageItem(
    MaintenanceItem item,
    int currentMileage,
  ) async {
    final id = item.id;
    if (id == null) return;
    final interval = item.intervalValue ?? 0;
    await _database.updateMaintenanceItem(
      id: id,
      title: item.title,
      kind: item.kind,
      intervalValue: interval,
      lastValue: currentMileage,
      nextValue: currentMileage + interval,
      note: item.note,
    );
  }

  Future<void> completeDateItem(
    MaintenanceItem item,
    DateTime nextDate,
  ) async {
    final id = item.id;
    if (id == null) return;
    await _database.updateMaintenanceItem(
      id: id,
      title: item.title,
      kind: item.kind,
      nextValue: nextDate.millisecondsSinceEpoch,
      note: item.note,
    );
    await NotificationService.instance.scheduleMaintenanceReminders(
      itemId: id,
      title: item.title,
      dueDate: nextDate,
    );
  }

  Future<void> delete(int id) async {
    await NotificationService.instance.cancelMaintenanceReminders(id);
    await _database.deleteMaintenanceItem(id);
  }
}
