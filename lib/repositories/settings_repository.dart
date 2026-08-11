import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/app_settings.dart';

class SettingsRepository extends ChangeNotifier {
  SettingsRepository._();

  static final SettingsRepository instance = SettingsRepository._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  int _revision = 0;
  int get revision => _revision;

  Future<AppSettings> getSettings() async {
    final defaults = AppSettings.defaults();

    final vehicleId = await _databaseHelper.getActiveVehicleId();
    final currentMileageValue = await _databaseHelper.getSetting(
      'current_mileage_$vehicleId',
    );
    final initialMileageValue = await _databaseHelper.getSetting(
      'initial_mileage_$vehicleId',
    );
    final legacyCurrent =
        await _databaseHelper.getSetting('current_mileage');
    final legacyInitial =
        await _databaseHelper.getSetting('initial_mileage');

    return AppSettings(
      initialMileage: int.tryParse(
        currentMileageValue ??
            initialMileageValue ??
            (vehicleId == 1 ? legacyCurrent : null) ??
            (vehicleId == 1 ? legacyInitial : null) ??
            '',
      ),
      standardTripPrice: _parseDouble(
        await _databaseHelper.getSetting('enterprise_trip_price'),
        defaults.standardTripPrice,
      ),
      hourlyOrderRate: _parseDouble(
        await _databaseHelper.getSetting('hourly_order_rate'),
        defaults.hourlyOrderRate,
      ),
      intercityOrderRate: _parseDouble(
        await _databaseHelper.getSetting('intercity_order_rate'),
        defaults.intercityOrderRate,
      ),
      defaultFuelPrice: _parseDouble(
        await _databaseHelper.getSetting('default_fuel_price'),
        defaults.defaultFuelPrice,
      ),
      summerConsumption: _parseDouble(
        await _databaseHelper.getSetting('summer_consumption'),
        defaults.summerConsumption,
      ),
      winterConsumption: _parseDouble(
        await _databaseHelper.getSetting('winter_consumption'),
        defaults.winterConsumption,
      ),
      tankVolume: _parseDouble(
        await _databaseHelper.getSetting('tank_volume'),
        defaults.tankVolume,
      ),
      orderReminderHours: int.tryParse(
            await _databaseHelper.getSetting('order_reminder_hours') ?? '',
          ) ??
          defaults.orderReminderHours,
      workFundPercent: _parseDouble(
        await _databaseHelper.getSetting('work_fund_percent'),
        defaults.workFundPercent,
      ),
      loanFundPercent: _parseDouble(
        await _databaseHelper.getSetting('loan_fund_percent'),
        defaults.loanFundPercent,
      ),
      personalFundPercent: _parseDouble(
        await _databaseHelper.getSetting('personal_fund_percent'),
        defaults.personalFundPercent,
      ),
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    _validateSettings(settings);
    final vehicleId = await _databaseHelper.getActiveVehicleId();

    final values = <String, String>{
      if (settings.initialMileage != null) ...{
        'initial_mileage_$vehicleId': settings.initialMileage.toString(),
        'current_mileage_$vehicleId': settings.initialMileage.toString(),
      },
      'enterprise_trip_price': settings.standardTripPrice.toString(),
      'hourly_order_rate': settings.hourlyOrderRate.toString(),
      'intercity_order_rate': settings.intercityOrderRate.toString(),
      'default_fuel_price': settings.defaultFuelPrice.toString(),
      'summer_consumption': settings.summerConsumption.toString(),
      'winter_consumption': settings.winterConsumption.toString(),
      'tank_volume': settings.tankVolume.toString(),
      'order_reminder_hours': settings.orderReminderHours.toString(),
      'work_fund_percent': settings.workFundPercent.toString(),
      'loan_fund_percent': settings.loanFundPercent.toString(),
      'personal_fund_percent': settings.personalFundPercent.toString(),
    };

    await _databaseHelper.setSettings(values);

    if (settings.initialMileage == null) {
      await _databaseHelper.deleteSetting('initial_mileage_$vehicleId');
      await _databaseHelper.deleteSetting('current_mileage_$vehicleId');
    }

    _revision++;
    notifyListeners();
  }

  Future<void> saveCurrentMileage(int mileage) async {
    if (mileage < 0) {
      throw ArgumentError(
        'Пробег не может быть отрицательным.',
      );
    }

    final vehicleId = await _databaseHelper.getActiveVehicleId();
    await _databaseHelper.setSettings({
      'initial_mileage_$vehicleId': mileage.toString(),
      'current_mileage_$vehicleId': mileage.toString(),
    });

    _revision++;
    notifyListeners();
  }

  Future<void> updateMileageAfterCompletedDay(int mileage) async {
    if (mileage < 0) {
      return;
    }

    final vehicleId = await _databaseHelper.getActiveVehicleId();
    await _databaseHelper.setSetting(
      'current_mileage_$vehicleId',
      mileage.toString(),
    );

    _revision++;
    notifyListeners();
  }


  Future<void> notifyMileageChanged() async {
    _revision++;
    notifyListeners();
  }

  Future<void> resetMileage() async {
    await _databaseHelper.resetMileageData();

    _revision++;
    notifyListeners();
  }

  Future<void> resetAllData() async {
    await _databaseHelper.resetAllData();

    _revision++;
    notifyListeners();
  }

  void _validateSettings(AppSettings settings) {
    if (settings.initialMileage != null &&
        settings.initialMileage! < 0) {
      throw ArgumentError(
        'Пробег не может быть отрицательным.',
      );
    }

    _validatePositiveValue(
      settings.standardTripPrice,
      'Стоимость стандартного рейса',
    );
    _validatePositiveValue(
      settings.hourlyOrderRate,
      'Почасовая ставка',
    );
    _validatePositiveValue(
      settings.intercityOrderRate,
      'Ставка межгорода',
    );

    if (settings.defaultFuelPrice < 0) {
      throw ArgumentError(
        'Цена топлива не может быть отрицательной.',
      );
    }

    _validatePositiveValue(
      settings.summerConsumption,
      'Летний расход топлива',
    );
    _validatePositiveValue(
      settings.winterConsumption,
      'Зимний расход топлива',
    );
    _validatePositiveValue(
      settings.tankVolume,
      'Объём бака',
    );

    if (settings.orderReminderHours < 0) {
      throw ArgumentError(
        'Время напоминания не может быть отрицательным.',
      );
    }

    if (!settings.hasValidFundPercent) {
      throw ArgumentError(
        'Сумма процентов фондов должна быть равна 100.',
      );
    }
  }

  void _validatePositiveValue(double value, String fieldName) {
    if (value <= 0) {
      throw ArgumentError(
        '$fieldName должна быть больше нуля.',
      );
    }
  }

  double _parseDouble(String? value, double fallback) {
    return double.tryParse(
          (value ?? '').replaceAll(',', '.'),
        ) ??
        fallback;
  }
}
