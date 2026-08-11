import '../database/database_helper.dart';
import '../models/daily_log.dart';
import 'settings_repository.dart';

class DailyLogRepository {
  DailyLogRepository._();

  static final DailyLogRepository instance = DailyLogRepository._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final SettingsRepository _settingsRepository =
      SettingsRepository.instance;

  String databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  Future<int?> _getConfiguredMileage() async {
    final activeId = await _databaseHelper.getActiveVehicleId();
    final current = await _databaseHelper.getSetting(
      'current_mileage_$activeId',
    );
    if (current != null) {
      return int.tryParse(current);
    }

    final initial = await _databaseHelper.getSetting(
      'initial_mileage_$activeId',
    );
    if (initial != null) {
      return int.tryParse(initial);
    }

    final vehicles = await _databaseHelper.getVehicles(
      includeArchived: true,
    );
    for (final vehicle in vehicles) {
      if ((vehicle['id'] as num?)?.toInt() == activeId) {
        final mileage = (vehicle['initial_mileage'] as num?)?.toInt();
        if (mileage != null) return mileage;
      }
    }

    return null;
  }

  Future<DailyLog> getLogForDate(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dateText = databaseDate(normalizedDate);
    final existingRow = await _databaseHelper.getDailyLog(dateText);

    if (existingRow != null) {
      return DailyLog.fromMap(existingRow);
    }

    // Для прошлой даты берём конечный пробег ближайшего предыдущего
    // завершённого дня. Это позволяет корректно вносить пробег задним числом.
    final previousDay = normalizedDate.subtract(const Duration(days: 1));
    final previousLogs = await _databaseHelper.getDailyLogsBetween(
      '1900-01-01',
      databaseDate(previousDay),
    );

    for (final row in previousLogs.reversed) {
      final endMileage = (row['end_mileage'] as num?)?.toInt();
      if (endMileage != null) {
        return DailyLog(
          date: dateText,
          startMileage: endMileage,
        );
      }
    }

    final configuredMileage = await _getConfiguredMileage();

    return DailyLog(
      date: dateText,
      startMileage: configuredMileage,
    );
  }

  Future<int?> getLastMileage() {
    return _databaseHelper.getLastMileage();
  }

  Future<void> saveInitialMileage(int mileage) {
    return _settingsRepository.saveCurrentMileage(mileage);
  }

  Future<int?> getInitialMileage() {
    return _getConfiguredMileage();
  }

  Future<DailyLog> completeDay({
    required DateTime date,
    required int endMileage,
  }) async {
    final currentLog = await getLogForDate(date);
    final startMileage = currentLog.startMileage;

    if (startMileage == null) {
      throw StateError(
        'Сначала укажите пробег в настройках.',
      );
    }

    if (endMileage < startMileage) {
      throw ArgumentError(
        'Конечный пробег не может быть меньше текущего пробега.',
      );
    }

    await _databaseHelper.saveEndMileage(
      date: databaseDate(date),
      startMileage: startMileage,
      endMileage: endMileage,
    );

    // Если пробег вносится задним числом, не откатываем текущий
    // одометр автобуса назад. Текущий пробег обновляем только если
    // после выбранной даты нет уже завершённых дней.
    final nextDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).add(const Duration(days: 1));
    final futureLogs = await _databaseHelper.getDailyLogsBetween(
      databaseDate(nextDay),
      '9999-12-31',
    );
    final hasCompletedFutureDay = futureLogs.any(
      (row) => row['end_mileage'] != null,
    );

    if (!hasCompletedFutureDay) {
      await _settingsRepository.updateMileageAfterCompletedDay(
        endMileage,
      );
    }

    final savedRow = await _databaseHelper.getDailyLog(
      databaseDate(date),
    );

    if (savedRow == null) {
      throw StateError(
        'Не удалось получить сохранённую запись дня.',
      );
    }

    return DailyLog.fromMap(savedRow);
  }

  Future<bool> isDayCompleted(DateTime date) async {
    final log = await getLogForDate(date);
    return log.isCompleted;
  }

  Future<int?> getDistanceForDate(DateTime date) async {
    final log = await getLogForDate(date);
    return log.distance;
  }
}
