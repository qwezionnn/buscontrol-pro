import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;
  Future<Database>? _openingDatabase;

  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) {
      return current;
    }

    final opening = _openingDatabase;
    if (opening != null) {
      return opening;
    }

    final future = _openDatabase();
    _openingDatabase = future;

    try {
      final opened = await future;
      _database = opened;
      return opened;
    } finally {
      _openingDatabase = null;
    }
  }

  Future<Database> _openDatabase() async {
    final path = kIsWeb
        ? 'bus_control_pro.db'
        : join(await getDatabasesPath(), 'bus_control_pro.db');

    return openDatabase(
      path,
      version: 9,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await _createTables(db);
    await _insertDefaultSettings(db);
    await _ensureDefaultVehicle(db);
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 6) {
      await _upgradeToVersion6(db);
    }
    if (oldVersion < 8) {
      await _upgradeToVersion8(db);
    }
    if (oldVersion < 9) {
      await _upgradeToVersion9(db);
    }
    await _createTables(db);
    await _insertDefaultSettings(db);
    await _ensureDefaultVehicle(db);
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL DEFAULT 1,
        date TEXT NOT NULL,
        start_mileage INTEGER,
        end_mileage INTEGER,
        completed_at TEXT,
        UNIQUE(vehicle_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS trips(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL DEFAULT 1,
        date TEXT NOT NULL,
        time TEXT,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        price REAL NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL DEFAULT 1,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        type TEXT NOT NULL,
        hours REAL,
        kilometers REAL,
        rate REAL NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'planned',
        paid INTEGER NOT NULL DEFAULT 0,
        reminder_hours INTEGER NOT NULL DEFAULT 12,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        paid_at TEXT NOT NULL,
        note TEXT,
        vehicle_percent REAL,
        personal_percent REAL,
        credit_distribution TEXT,
        FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fuel_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL DEFAULT 1,
        date TEXT NOT NULL,
        time TEXT,
        liters REAL NOT NULL,
        price_per_liter REAL NOT NULL,
        total REAL NOT NULL,
        mileage INTEGER,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL DEFAULT 1,
        date TEXT NOT NULL,
        time TEXT,
        category TEXT NOT NULL,
        description TEXT,
        amount REAL NOT NULL
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL DEFAULT 1,
        title TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'mileage',
        interval_value INTEGER,
        last_value INTEGER,
        next_value INTEGER,
        note TEXT,
        completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS trip_payouts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL DEFAULT 1,
        month TEXT NOT NULL,
        gross_amount REAL NOT NULL,
        received_at TEXT NOT NULL,
        note TEXT,
        UNIQUE(vehicle_id, month)
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS vehicles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        registration_number TEXT,
        note TEXT,
        initial_mileage INTEGER,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credits(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        initial_amount REAL NOT NULL,
        remaining_amount REAL NOT NULL,
        income_percent REAL NOT NULL DEFAULT 0,
        monthly_payment REAL,
        payment_day INTEGER,
        vehicle_id INTEGER,
        note TEXT,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        credit_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        paid_at TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY(credit_id) REFERENCES credits(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_daily_logs_date ON daily_logs(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_trips_date ON trips(date)',
    );
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS index_standard_trips_unique
      ON trips(vehicle_id, date, type)
      WHERE type IN ('morning', 'evening')
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_orders_date ON orders(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_order_payments_order_id ON order_payments(order_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_order_payments_paid_at ON order_payments(paid_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_fuel_logs_date ON fuel_logs(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_expenses_date ON expenses(date)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_trip_payouts_month ON trip_payouts(month)',
    );
  }

  Future<void> _insertDefaultSettings(DatabaseExecutor db) async {
    final settings = <String, String>{
      'enterprise_trip_price': '2700',
      'hourly_order_rate': '2000',
      'intercity_order_rate': '55',
      'default_fuel_price': '0',
      'summer_consumption': '11.5',
      'winter_consumption': '13.2',
      'tank_volume': '80',
      'work_fund_percent': '30',
      'loan_fund_percent': '35',
      'personal_fund_percent': '35',
      'order_reminder_hours': '12',
      'theme_mode': 'system',
      'active_vehicle_id': '1',
    };

    // onCreate/onUpgrade уже выполняются внутри транзакции sqflite.
    // Batch.commit здесь может повторно захватить внутреннюю блокировку
    // базы и оставить запуск приложения на splash-экране.
    for (final entry in settings.entries) {
      await db.insert(
        'settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _upgradeToVersion6(Database db) async {
    Future<bool> hasColumn(String table, String column) async {
      final rows = await db.rawQuery('PRAGMA table_info($table)');
      return rows.any((row) => row['name'] == column);
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS vehicles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        registration_number TEXT,
        note TEXT,
        initial_mileage INTEGER,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.insert(
      'vehicles',
      {
        'id': 1,
        'name': 'Мой автобус',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    for (final table in <String>[
      'trips',
      'orders',
      'fuel_logs',
      'expenses',
      'maintenance_items',
    ]) {
      if (!await hasColumn(table, 'vehicle_id')) {
        await db.execute(
          'ALTER TABLE $table ADD COLUMN vehicle_id INTEGER NOT NULL DEFAULT 1',
        );
      }
    }

    if (!await hasColumn('daily_logs', 'vehicle_id')) {
      await db.execute('ALTER TABLE daily_logs RENAME TO daily_logs_old');
      await db.execute('''
        CREATE TABLE daily_logs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          vehicle_id INTEGER NOT NULL DEFAULT 1,
          date TEXT NOT NULL,
          start_mileage INTEGER,
          end_mileage INTEGER,
          completed_at TEXT,
          UNIQUE(vehicle_id, date)
        )
      ''');
      await db.execute('''
        INSERT INTO daily_logs(
          id, vehicle_id, date, start_mileage, end_mileage, completed_at
        )
        SELECT id, 1, date, start_mileage, end_mileage, completed_at
        FROM daily_logs_old
      ''');
      await db.execute('DROP TABLE daily_logs_old');
    }

    if (!await hasColumn('trip_payouts', 'vehicle_id')) {
      await db.execute('ALTER TABLE trip_payouts RENAME TO trip_payouts_old');
      await db.execute('''
        CREATE TABLE trip_payouts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          vehicle_id INTEGER NOT NULL DEFAULT 1,
          month TEXT NOT NULL,
          gross_amount REAL NOT NULL,
          received_at TEXT NOT NULL,
          note TEXT,
          UNIQUE(vehicle_id, month)
        )
      ''');
      await db.execute('''
        INSERT INTO trip_payouts(
          id, vehicle_id, month, gross_amount, received_at, note
        )
        SELECT id, 1, month, gross_amount, received_at, note
        FROM trip_payouts_old
      ''');
      await db.execute('DROP TABLE trip_payouts_old');
    }
  }

  Future<void> _upgradeToVersion8(Database db) async {
    // Удаляем только повторные стандартные рейсы, оставляя самую раннюю запись.
    await db.execute('''
      DELETE FROM trips
      WHERE type IN ('morning', 'evening')
        AND id NOT IN (
          SELECT MIN(id)
          FROM trips
          WHERE type IN ('morning', 'evening')
          GROUP BY vehicle_id, date, type
        )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS index_standard_trips_unique
      ON trips(vehicle_id, date, type)
      WHERE type IN ('morning', 'evening')
    ''');
  }

  Future<void> _upgradeToVersion9(Database db) async {
    Future<bool> hasColumn(String table, String column) async {
      final rows = await db.rawQuery('PRAGMA table_info($table)');
      return rows.any((row) => row['name'] == column);
    }

    if (!await hasColumn('order_payments', 'vehicle_percent')) {
      await db.execute(
        'ALTER TABLE order_payments ADD COLUMN vehicle_percent REAL',
      );
    }
    if (!await hasColumn('order_payments', 'personal_percent')) {
      await db.execute(
        'ALTER TABLE order_payments ADD COLUMN personal_percent REAL',
      );
    }
    if (!await hasColumn('order_payments', 'credit_distribution')) {
      await db.execute(
        'ALTER TABLE order_payments ADD COLUMN credit_distribution TEXT',
      );
    }
  }

  Future<void> _ensureDefaultVehicle(DatabaseExecutor db) async {
    final rows = await db.query('vehicles', limit: 1);
    if (rows.isEmpty) {
      await db.insert('vehicles', {
        'name': 'Мой автобус',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    final active = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['active_vehicle_id'],
      limit: 1,
    );
    if (active.isEmpty) {
      final vehicles = await db.query('vehicles', columns: ['id'], limit: 1);
      await db.insert(
        'settings',
        {
          'key': 'active_vehicle_id',
          'value': vehicles.first['id'].toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<int> getActiveVehicleId() async {
    final value = await getSetting('active_vehicle_id');
    return int.tryParse(value ?? '') ?? 1;
  }

  Future<void> setActiveVehicleId(int id) async {
    final db = await database;
    final rows = await db.query(
      'vehicles',
      columns: ['id'],
      where: 'id = ? AND archived = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Транспорт не найден или находится в архиве.');
    }
    await setSetting('active_vehicle_id', id.toString());
  }

  Future<List<Map<String, Object?>>> getVehicles({
    bool includeArchived = false,
  }) async {
    final db = await database;
    return db.query(
      'vehicles',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'archived ASC, name ASC',
    );
  }

  Future<int> addVehicle({
    required String name,
    String? registrationNumber,
    String? note,
    int? initialMileage,
  }) async {
    final db = await database;
    return db.insert('vehicles', {
      'name': name.trim(),
      'registration_number': registrationNumber?.trim(),
      'note': note?.trim(),
      'initial_mileage': initialMileage,
      'archived': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateVehicle({
    required int id,
    required String name,
    String? registrationNumber,
    String? note,
    int? initialMileage,
    bool archived = false,
  }) async {
    final db = await database;
    await db.update(
      'vehicles',
      {
        'name': name.trim(),
        'registration_number': registrationNumber?.trim(),
        'note': note?.trim(),
        'initial_mileage': initialMileage,
        'archived': archived ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> archiveVehicle(int id) async {
    final activeId = await getActiveVehicleId();
    if (id == activeId) {
      throw StateError('Сначала выберите другой активный транспорт.');
    }
    final db = await database;
    await db.update(
      'vehicles',
      {'archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteVehicle(int id) async {
    final db = await database;

    await db.transaction((transaction) async {
      final vehicles = await transaction.query(
        'vehicles',
        columns: ['id'],
        where: 'id != ?',
        whereArgs: [id],
        orderBy: 'id ASC',
      );
      if (vehicles.isEmpty) {
        throw StateError('Нельзя удалить единственный транспорт.');
      }

      final orderRows = await transaction.query(
        'orders',
        columns: ['id'],
        where: 'vehicle_id = ?',
        whereArgs: [id],
      );
      final orderIds = orderRows
          .map((row) => row['id'])
          .whereType<int>()
          .toList();
      for (final orderId in orderIds) {
        await transaction.delete(
          'order_payments',
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
      }

      final creditRows = await transaction.query(
        'credits',
        columns: ['id'],
        where: 'vehicle_id = ?',
        whereArgs: [id],
      );
      final creditIds = creditRows
          .map((row) => row['id'])
          .whereType<int>()
          .toList();
      for (final creditId in creditIds) {
        await transaction.delete(
          'credit_payments',
          where: 'credit_id = ?',
          whereArgs: [creditId],
        );
      }

      for (final table in <String>[
        'daily_logs',
        'trips',
        'orders',
        'fuel_logs',
        'expenses',
        'maintenance_items',
        'trip_payouts',
        'credits',
      ]) {
        await transaction.delete(
          table,
          where: 'vehicle_id = ?',
          whereArgs: [id],
        );
      }

      await transaction.delete(
        'vehicles',
        where: 'id = ?',
        whereArgs: [id],
      );

      final activeRows = await transaction.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['active_vehicle_id'],
        limit: 1,
      );
      final activeId = activeRows.isEmpty
          ? null
          : int.tryParse(activeRows.first['value']?.toString() ?? '');
      if (activeId == id) {
        await transaction.insert(
          'settings',
          {
            'key': 'active_vehicle_id',
            'value': vehicles.first['id'].toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, Object?>>> getCredits({
    bool includeArchived = false,
  }) async {
    final db = await database;
    return db.query(
      'credits',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'archived ASC, title ASC',
    );
  }

  Future<int> addCredit({
    required String title,
    required double initialAmount,
    required double remainingAmount,
    required double incomePercent,
    double? monthlyPayment,
    int? paymentDay,
    int? vehicleId,
    String? note,
  }) async {
    if (incomePercent < 0 || incomePercent > 100) {
      throw ArgumentError('Процент кредита должен быть от 0 до 100.');
    }
    final db = await database;
    return db.insert('credits', {
      'title': title.trim(),
      'initial_amount': initialAmount,
      'remaining_amount': remainingAmount,
      'income_percent': incomePercent,
      'monthly_payment': monthlyPayment,
      'payment_day': paymentDay,
      'vehicle_id': vehicleId,
      'note': note?.trim(),
      'archived': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateCredit({
    required int id,
    required String title,
    required double initialAmount,
    required double remainingAmount,
    required double incomePercent,
    double? monthlyPayment,
    int? paymentDay,
    int? vehicleId,
    String? note,
    bool archived = false,
  }) async {
    final db = await database;
    await db.update(
      'credits',
      {
        'title': title.trim(),
        'initial_amount': initialAmount,
        'remaining_amount': remainingAmount,
        'income_percent': incomePercent,
        'monthly_payment': monthlyPayment,
        'payment_day': paymentDay,
        'vehicle_id': vehicleId,
        'note': note?.trim(),
        'archived': archived ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCredit(int id) async {
    final db = await database;
    await db.transaction((transaction) async {
      await transaction.delete(
        'credit_payments',
        where: 'credit_id = ?',
        whereArgs: [id],
      );
      await transaction.delete(
        'credits',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> addCreditPayment({
    required int creditId,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Сумма платежа должна быть больше нуля.');
    }
    final db = await database;
    return db.transaction((transaction) async {
      final rows = await transaction.query(
        'credits',
        columns: ['remaining_amount'],
        where: 'id = ?',
        whereArgs: [creditId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Кредит не найден.');
      final remaining =
          (rows.first['remaining_amount'] as num).toDouble();
      final payment = amount > remaining ? remaining : amount;
      final id = await transaction.insert('credit_payments', {
        'credit_id': creditId,
        'amount': payment,
        'paid_at': DateTime.now().toIso8601String(),
        'note': note?.trim(),
      });
      await transaction.update(
        'credits',
        {
          'remaining_amount': (remaining - payment).clamp(0, double.infinity),
        },
        where: 'id = ?',
        whereArgs: [creditId],
      );
      return id;
    });
  }

  Future<List<Map<String, Object?>>> getCreditPayments(int creditId) async {
    final db = await database;
    return db.query(
      'credit_payments',
      where: 'credit_id = ?',
      whereArgs: [creditId],
      orderBy: 'paid_at DESC, id DESC',
    );
  }

  Future<Map<String, Object?>?> getDailyLog(String date) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    final result = await db.query(
      'daily_logs',
      where: 'vehicle_id = ? AND date = ?',
      whereArgs: [vehicleId, date],
      limit: 1,
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, Object?>>> getDailyLogsBetween(
    String from,
    String to,
  ) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.query(
      'daily_logs',
      where: 'vehicle_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [vehicleId, from, to],
      orderBy: 'date ASC',
    );
  }

  Future<int> saveEndMileage({
    required String date,
    required int startMileage,
    required int endMileage,
  }) async {
    if (endMileage < startMileage) {
      throw ArgumentError(
        'Конечный пробег не может быть меньше начального.',
      );
    }

    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.insert(
      'daily_logs',
      {
        'vehicle_id': vehicleId,
        'date': date,
        'start_mileage': startMileage,
        'end_mileage': endMileage,
        'completed_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> getLastMileage() async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    final result = await db.query(
      'daily_logs',
      columns: ['end_mileage'],
      where: 'vehicle_id = ? AND end_mileage IS NOT NULL',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return (result.first['end_mileage'] as num?)?.toInt();
  }

  Future<int> addTrip({
    required String date,
    String? time,
    required String title,
    required String type,
    required double price,
    bool completed = false,
    bool ignoreConflict = false,
  }) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.insert(
      'trips',
      {
        'vehicle_id': vehicleId,
        'date': date,
        'time': time,
        'title': title,
        'type': type,
        'price': price,
        'completed': completed ? 1 : 0,
      },
      conflictAlgorithm: ignoreConflict
          ? ConflictAlgorithm.ignore
          : ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, Object?>>> getTripsByDate(String date) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.query(
      'trips',
      where: 'vehicle_id = ? AND date = ?',
      whereArgs: [vehicleId, date],
      orderBy: 'time ASC',
    );
  }

  Future<List<Map<String, Object?>>> getTripsBetween(
    String from,
    String to,
  ) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.query(
      'trips',
      where: 'vehicle_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [vehicleId, from, to],
      orderBy: 'date ASC, time ASC',
    );
  }

  Future<void> setTripCompleted(int tripId, bool completed) async {
    final db = await database;
    await db.update(
      'trips',
      {'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  Future<void> updateTripPrice(int tripId, double price) async {
    if (price <= 0) {
      throw ArgumentError('Стоимость рейса должна быть больше нуля.');
    }
    final db = await database;
    await db.update(
      'trips',
      {'price': price},
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  Future<void> deleteTrip(int tripId) async {
    final db = await database;
    await db.delete('trips', where: 'id = ?', whereArgs: [tripId]);
  }

  Future<int> addOrder({
    required String title,
    required String date,
    required String time,
    required String type,
    double? hours,
    double? kilometers,
    required double rate,
    required double amount,
    int reminderHours = 12,
    String? note,
  }) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.insert('orders', {
      'vehicle_id': vehicleId,
      'title': title,
      'date': date,
      'time': time,
      'type': type,
      'hours': hours,
      'kilometers': kilometers,
      'rate': rate,
      'amount': amount,
      'status': 'planned',
      'paid': 0,
      'reminder_hours': reminderHours,
      'note': note,
    });
  }

  Future<void> updateOrder({
    required int orderId,
    required String title,
    required String date,
    required String time,
    required String type,
    double? hours,
    double? kilometers,
    required double rate,
    required double amount,
    int reminderHours = 12,
    String? note,
  }) async {
    final db = await database;
    await db.update(
      'orders',
      {
        'title': title,
        'date': date,
        'time': time,
        'type': type,
        'hours': hours,
        'kilometers': kilometers,
        'rate': rate,
        'amount': amount,
        'reminder_hours': reminderHours,
        'note': note,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<List<Map<String, Object?>>> getOrdersByDate(String date) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT o.*,
        COALESCE((
          SELECT SUM(p.amount)
          FROM order_payments p
          WHERE p.order_id = o.id
        ), 0) AS paid_amount
      FROM orders o
      WHERE o.vehicle_id = ? AND o.date = ?
      ORDER BY o.time ASC
      ''',
      [await getActiveVehicleId(), date],
    );
  }

  Future<List<Map<String, Object?>>> getOrdersBetween(
    String from,
    String to,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT o.*,
        COALESCE((
          SELECT SUM(p.amount)
          FROM order_payments p
          WHERE p.order_id = o.id
        ), 0) AS paid_amount
      FROM orders o
      WHERE o.vehicle_id = ? AND o.date BETWEEN ? AND ?
      ORDER BY o.date ASC, o.time ASC
      ''',
      [await getActiveVehicleId(), from, to],
    );
  }

  Future<int> addOrderPayment({
    required int orderId,
    required double amount,
    required double vehiclePercent,
    required double personalPercent,
    required Map<String, double> creditPercents,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Сумма оплаты должна быть больше нуля.');
    }

    final totalPercent = vehiclePercent +
        personalPercent +
        creditPercents.values.fold<double>(0, (sum, value) => sum + value);
    if ((totalPercent - 100).abs() > 0.01) {
      throw ArgumentError(
        'Сумма процентов распределения должна быть равна 100%.',
      );
    }

    final db = await database;
    return db.transaction((transaction) async {
      final orders = await transaction.query(
        'orders',
        columns: ['amount', 'status'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (orders.isEmpty) {
        throw StateError('Заказ не найден.');
      }
      if (orders.first['status'] != 'completed') {
        throw StateError('Оплату можно добавить только выполненному заказу.');
      }

      final total = (orders.first['amount'] as num).toDouble();
      final paidRows = await transaction.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS total '
        'FROM order_payments WHERE order_id = ?',
        [orderId],
      );
      final paid = (paidRows.first['total'] as num?)?.toDouble() ?? 0;
      final remaining = total - paid;
      if (amount > remaining + 0.001) {
        throw ArgumentError(
          'Оплата больше остатка (${remaining.toStringAsFixed(0)} ₽).',
        );
      }

      final id = await transaction.insert('order_payments', {
        'order_id': orderId,
        'amount': amount,
        'paid_at': DateTime.now().toIso8601String(),
        'note': note,
        'vehicle_percent': vehiclePercent,
        'personal_percent': personalPercent,
        'credit_distribution': jsonEncode(creditPercents),
      });

      await transaction.update(
        'orders',
        {'paid': amount >= remaining - 0.001 ? 1 : 0},
        where: 'id = ?',
        whereArgs: [orderId],
      );
      return id;
    });
  }

  Future<List<Map<String, Object?>>> getOrderPayments(int orderId) async {
    final db = await database;
    return db.query(
      'order_payments',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'paid_at DESC, id DESC',
    );
  }

  Future<List<Map<String, Object?>>> getCompletedOrderPayments() async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.rawQuery(
      '''
      SELECT p.*
      FROM order_payments p
      INNER JOIN orders o ON o.id = p.order_id
      WHERE o.vehicle_id = ? AND o.status = 'completed'
      ORDER BY p.paid_at ASC, p.id ASC
      ''',
      [vehicleId],
    );
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    const allowed = {'planned', 'completed', 'cancelled'};
    if (!allowed.contains(status)) {
      throw ArgumentError('Неизвестный статус заказа: $status');
    }
    final db = await database;
    await db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> deleteOrder(int orderId) async {
    final db = await database;
    await db.transaction((transaction) async {
      await transaction.delete(
        'order_payments',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      await transaction.delete('orders', where: 'id = ?', whereArgs: [orderId]);
    });
  }

  Future<int> addFuelLog({
    required String date,
    String? time,
    required double liters,
    required double pricePerLiter,
    int? mileage,
    String? note,
  }) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.insert('fuel_logs', {
      'vehicle_id': vehicleId,
      'date': date,
      'time': time,
      'liters': liters,
      'price_per_liter': pricePerLiter,
      'total': liters * pricePerLiter,
      'mileage': mileage,
      'note': note,
    });
  }

  Future<List<Map<String, Object?>>> getFuelLogsByDate(String date) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.query(
      'fuel_logs',
      where: 'vehicle_id = ? AND date = ?',
      whereArgs: [vehicleId, date],
      orderBy: 'time ASC',
    );
  }

  Future<List<Map<String, Object?>>> getFuelLogsBetween(
    String from,
    String to,
  ) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.query(
      'fuel_logs',
      where: 'vehicle_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [vehicleId, from, to],
      orderBy: 'date ASC, time ASC',
    );
  }

  Future<void> deleteFuelLog(int id) async {
    final db = await database;
    await db.delete('fuel_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addExpense({
    required String date,
    String? time,
    required String category,
    String? description,
    required double amount,
  }) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.insert('expenses', {
      'vehicle_id': vehicleId,
      'date': date,
      'time': time,
      'category': category,
      'description': description,
      'amount': amount,
    });
  }

  Future<List<Map<String, Object?>>> getExpensesByDate(String date) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.query(
      'expenses',
      where: 'vehicle_id = ? AND date = ?',
      whereArgs: [vehicleId, date],
      orderBy: 'time ASC',
    );
  }

  Future<List<Map<String, Object?>>> getExpensesBetween(
    String from,
    String to,
  ) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.query(
      'expenses',
      where: 'vehicle_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [vehicleId, from, to],
      orderBy: 'date ASC, time ASC',
    );
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }


  // --------------------
  // ТО И ОБСЛУЖИВАНИЕ
  // --------------------

  Future<int> addMaintenanceItem({
    required String title,
    required String kind,
    int? intervalValue,
    int? lastValue,
    int? nextValue,
    String? note,
  }) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.insert('maintenance_items', {
      'vehicle_id': vehicleId,
      'title': title,
      'kind': kind,
      'interval_value': intervalValue,
      'last_value': lastValue,
      'next_value': nextValue,
      'note': note,
      'completed': 0,
    });
  }

  Future<List<Map<String, Object?>>> getMaintenanceItems() async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.query(
      'maintenance_items',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'completed ASC, next_value ASC, title ASC',
    );
  }

  Future<void> updateMaintenanceItem({
    required int id,
    required String title,
    required String kind,
    int? intervalValue,
    int? lastValue,
    int? nextValue,
    String? note,
    bool completed = false,
  }) async {
    final db = await database;
    await db.update(
      'maintenance_items',
      {
        'title': title,
        'kind': kind,
        'interval_value': intervalValue,
        'last_value': lastValue,
        'next_value': nextValue,
        'note': note,
        'completed': completed ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteMaintenanceItem(int id) async {
    final db = await database;
    await db.delete(
      'maintenance_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --------------------
  // ВЫПЛАТЫ ЗА РЕЙСЫ
  // --------------------

  Future<void> saveTripPayout({
    required String month,
    required double grossAmount,
    String? note,
  }) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    await db.insert(
      'trip_payouts',
      {
        'vehicle_id': vehicleId,
        'month': month,
        'gross_amount': grossAmount,
        'received_at': DateTime.now().toIso8601String(),
        'note': note,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> getTripPayout(String month) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    final rows = await db.query(
      'trip_payouts',
      where: 'vehicle_id = ? AND month = ?',
      whereArgs: [vehicleId, month],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getTripPayouts() async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    return db.query(
      'trip_payouts',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'month DESC',
    );
  }

  Future<void> deleteTripPayout(String month) async {
    final db = await database;
    final vehicleId = await getActiveVehicleId();
    await db.delete(
      'trip_payouts',
      where: 'vehicle_id = ? AND month = ?',
      whereArgs: [vehicleId, month],
    );
  }

  Future<String> getDatabaseFilePath() async {
    if (kIsWeb) {
      // В веб-версии SQLite хранится внутри IndexedDB и не имеет
      // обычного пути в файловой системе.
      return 'bus_control_pro.db';
    }
    final databasePath = await getDatabasesPath();
    return join(databasePath, 'bus_control_pro.db');
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return result.isEmpty ? null : result.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setSettings(Map<String, String> values) async {
    final db = await database;

    await db.transaction((transaction) async {
      final batch = transaction.batch();

      for (final entry in values.entries) {
        batch.insert(
          'settings',
          {
            'key': entry.key,
            'value': entry.value,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;

    await db.delete(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }




  static const List<String> _syncTables = <String>[
    'vehicles',
    'settings',
    'daily_logs',
    'trips',
    'orders',
    'order_payments',
    'fuel_logs',
    'expenses',
    'maintenance_items',
    'trip_payouts',
    'credits',
    'credit_payments',
  ];

  /// Создаёт переносимый снимок всей локальной рабочей базы.
  /// Служебные ключи синхронизации не включаются в снимок,
  /// чтобы они не вызывали бесконечную повторную загрузку.
  Future<Map<String, dynamic>> exportCloudSnapshot() async {
    final db = await database;
    final tables = <String, dynamic>{};

    for (final table in _syncTables) {
      if (table == 'settings') {
        tables[table] = await db.query(
          table,
          where: "key NOT LIKE 'cloud_sync_%'",
          orderBy: 'key ASC',
        );
      } else {
        tables[table] = await db.query(table, orderBy: 'id ASC');
      }
    }

    return <String, dynamic>{
      'format': 1,
      'database_version': 9,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };
  }

  /// Полностью заменяет локальные пользовательские данные снимком из облака.
  /// Выполняется одной транзакцией, поэтому неполное восстановление невозможно.
  Future<void> importCloudSnapshot(Map<String, dynamic> snapshot) async {
    final rawTables = snapshot['tables'];
    if (rawTables is! Map) {
      throw const FormatException('Некорректный формат облачного снимка.');
    }

    final db = await database;
    await db.transaction((transaction) async {
      await transaction.execute('PRAGMA foreign_keys = OFF');

      // Сначала дочерние таблицы, затем родительские.
      for (final table in <String>[
        'order_payments',
        'credit_payments',
        'daily_logs',
        'trips',
        'orders',
        'fuel_logs',
        'expenses',
        'maintenance_items',
        'trip_payouts',
        'credits',
        'vehicles',
        'settings',
      ]) {
        await transaction.delete(table);
      }

      // Родительские таблицы должны быть восстановлены раньше дочерних.
      for (final table in _syncTables) {
        final rows = rawTables[table];
        if (rows is! List) continue;

        for (final rawRow in rows) {
          if (rawRow is! Map) continue;
          await transaction.insert(
            table,
            Map<String, Object?>.from(rawRow),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      await _insertDefaultSettings(transaction);
      await _ensureDefaultVehicle(transaction);
      await transaction.execute('PRAGMA foreign_keys = ON');
    });
  }

  /// Полностью удаляет пользовательские данные и возвращает
  /// настройки к значениям по умолчанию.
  ///
  /// Это необратимая операция.
  Future<void> resetAllData() async {
    final db = await database;

    await db.transaction((transaction) async {
      await transaction.delete('daily_logs');
      await transaction.delete('trips');
      await transaction.delete('order_payments');
      await transaction.delete('orders');
      await transaction.delete('fuel_logs');
      await transaction.delete('expenses');
      await transaction.delete('maintenance_items');
      await transaction.delete('trip_payouts');
      await transaction.delete('credit_payments');
      await transaction.delete('credits');
      await transaction.delete('vehicles');
      await transaction.delete('settings');

      // Сбрасываем счётчики AUTOINCREMENT, чтобы новая база
      // начиналась с чистых идентификаторов.
      try {
        await transaction.delete(
          'sqlite_sequence',
          where:
              "name IN ('daily_logs', 'trips', 'orders', 'order_payments', 'fuel_logs', 'expenses', 'maintenance_items', 'trip_payouts', 'credit_payments', 'credits', 'vehicles')",
        );
      } catch (_) {
        // sqlite_sequence может отсутствовать в новой пустой базе.
      }

      await _insertDefaultSettings(transaction);
      await _ensureDefaultVehicle(transaction);
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}