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
    final dateText = databaseDate(date);
    final existingRow = await _databaseHelper.getDailyLog(dateText);

    if (existingRow != null) {
      return DailyLog.fromMap(existingRow);
    }

    // Настройка текущего пробега имеет приоритет. Это позволяет
    // исправить пробег вручную, даже если в тестовой базе уже есть история.
    final configuredMileage = await _getConfiguredMileage();
    final lastMileage = await _databaseHelper.getLastMileage();

    return DailyLog(
      date: dateText,
      startMileage: configuredMileage ?? lastMileage,
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

    await _settingsRepository.updateMileageAfterCompletedDay(
      endMileage,
    );

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
