import '../database/database_helper.dart';
import '../services/notification_service.dart';

class CalendarNoteRepository {
  CalendarNoteRepository._();
  static final instance = CalendarNoteRepository._();

  Future<int> save({
    int? id,
    required String date,
    String? time,
    required String title,
    String? body,
    required bool reminderEnabled,
    required int reminderMinutes,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final vehicleId = await DatabaseHelper.instance.getActiveVehicleId();
    final now = DateTime.now().toIso8601String();
    final values = <String, Object?>{
      'vehicle_id': vehicleId,
      'date': date,
      'time': time,
      'title': title.trim(),
      'body': body?.trim().isEmpty == true ? null : body?.trim(),
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'reminder_minutes': reminderMinutes,
      'updated_at': now,
    };
    late int noteId;
    if (id == null) {
      values['created_at'] = now;
      noteId = await db.insert('calendar_notes', values);
    } else {
      await db.update('calendar_notes', values, where: 'id = ?', whereArgs: [id]);
      noteId = id;
    }
    await NotificationService.instance.scheduleCalendarNote(
      id: noteId,
      date: date,
      time: time,
      title: title.trim(),
      body: body?.trim(),
      enabled: reminderEnabled,
      reminderMinutes: reminderMinutes,
    );
    return noteId;
  }

  Future<void> delete(int id) async {
    await NotificationService.instance.cancelCalendarNote(id);
    final db = await DatabaseHelper.instance.database;
    await db.delete('calendar_notes', where: 'id = ?', whereArgs: [id]);
  }
}
