import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../platform/file_download.dart';

class BackupService extends ChangeNotifier {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const _format = 'buscontrol-json';
  static const _formatVersion = 1;

  static const _tables = <String>[
    'vehicles',
    'credits',
    'orders',
    'daily_logs',
    'trips',
    'fuel_logs',
    'expenses',
    'maintenance_items',
    'trip_payouts',
    'order_payments',
    'credit_payments',
    'settings',
  ];

  static const _deleteOrder = <String>[
    'order_payments',
    'credit_payments',
    'daily_logs',
    'trips',
    'fuel_logs',
    'expenses',
    'maintenance_items',
    'trip_payouts',
    'orders',
    'credits',
    'settings',
    'vehicles',
  ];

  static const _insertOrder = <String>[
    'vehicles',
    'credits',
    'orders',
    'daily_logs',
    'trips',
    'fuel_logs',
    'expenses',
    'maintenance_items',
    'trip_payouts',
    'order_payments',
    'credit_payments',
    'settings',
  ];

  final DatabaseHelper _database = DatabaseHelper.instance;

  Future<void> shareBackup() async {
    final db = await _database.database;
    final tables = <String, List<Map<String, Object?>>>{};

    for (final table in _tables) {
      tables[table] = await db.query(table);
    }

    final now = DateTime.now();
    final payload = <String, Object?>{
      'format': _format,
      'formatVersion': _formatVersion,
      'app': 'BusControl PRO',
      'createdAt': now.toIso8601String(),
      'tables': tables,
    };

    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
    );
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}';

    final fileName = 'buscontrol_$stamp.buscontrol';

    if (kIsWeb) {
      await downloadBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/json',
      );
      return;
    }

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'application/json',
          name: fileName,
        ),
      ],
      subject: 'Резервная копия BusControl PRO',
      text: 'Резервная копия данных BusControl PRO.',
    );
  }

  Future<bool> restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['buscontrol', 'json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return false;
    }

    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      throw StateError(
        'Не удалось прочитать выбранный файл. '
        'Выберите копию ещё раз.',
      );
    }

    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != _format ||
        decoded['formatVersion'] != _formatVersion) {
      throw const FormatException(
        'Выбранный файл не является резервной копией BusControl PRO.',
      );
    }

    final rawTables = decoded['tables'];
    if (rawTables is! Map<String, dynamic>) {
      throw const FormatException(
        'Резервная копия повреждена: отсутствуют таблицы.',
      );
    }

    final db = await _database.database;

    await db.transaction((transaction) async {
      for (final table in _deleteOrder) {
        await transaction.delete(table);
      }

      for (final table in _insertOrder) {
        final rawRows = rawTables[table];
        if (rawRows == null) {
          continue;
        }
        if (rawRows is! List) {
          throw FormatException(
            'Резервная копия повреждена: неверная таблица $table.',
          );
        }

        for (final rawRow in rawRows) {
          if (rawRow is! Map) {
            throw FormatException(
              'Резервная копия повреждена: неверная запись в $table.',
            );
          }
          final row = rawRow.map<String, Object?>(
            (key, value) => MapEntry(key.toString(), value),
          );
          await transaction.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    notifyListeners();
    return true;
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
