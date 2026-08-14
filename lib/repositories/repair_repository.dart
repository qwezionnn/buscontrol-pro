import '../database/database_helper.dart';

class RepairRepository {
  RepairRepository._();
  static final instance = RepairRepository._();
  final _db = DatabaseHelper.instance;

  Future<List<Map<String, Object?>>> getAll() => _db.getRepairs();
  Future<List<Map<String, Object?>>> getExpenses() => _db.getAllExpenses();

  Future<int> save(Map<String, Object?> values, {int? id}) =>
      _db.saveRepair(values, id: id);

  Future<void> delete(int id) => _db.deleteRepair(id);
}
