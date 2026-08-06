
import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/vehicle.dart';

class VehicleRepository extends ChangeNotifier {
  VehicleRepository._();

  static final VehicleRepository instance = VehicleRepository._();

  final DatabaseHelper _database = DatabaseHelper.instance;

  Future<List<Vehicle>> getVehicles({
    bool includeArchived = false,
  }) async {
    final rows = await _database.getVehicles(
      includeArchived: includeArchived,
    );
    return rows.map(Vehicle.fromMap).toList();
  }

  Future<Vehicle> getActiveVehicle() async {
    final activeId = await _database.getActiveVehicleId();
    final vehicles = await getVehicles(includeArchived: true);
    return vehicles.firstWhere(
      (vehicle) => vehicle.id == activeId,
      orElse: () => vehicles.first,
    );
  }

  Future<void> setActiveVehicle(int id) async {
    await _database.setActiveVehicleId(id);
    notifyListeners();
  }

  Future<int> addVehicle(Vehicle vehicle) async {
    final id = await _database.addVehicle(
      name: vehicle.name,
      registrationNumber: vehicle.registrationNumber,
      note: vehicle.note,
      initialMileage: vehicle.initialMileage,
    );
    notifyListeners();
    return id;
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    if (vehicle.id == null) {
      throw ArgumentError('У транспорта отсутствует идентификатор.');
    }
    await _database.updateVehicle(
      id: vehicle.id!,
      name: vehicle.name,
      registrationNumber: vehicle.registrationNumber,
      note: vehicle.note,
      initialMileage: vehicle.initialMileage,
      archived: vehicle.archived,
    );
    notifyListeners();
  }

  Future<void> archiveVehicle(int id) async {
    await _database.archiveVehicle(id);
    notifyListeners();
  }
}
