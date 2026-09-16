import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';
import '../models/trip.dart';
import '../repositories/trip_repository.dart';

/// Bridge between the iOS WidgetKit extension and the Flutter application.
///
/// The widget cannot safely open the sqflite database directly because it runs
/// in another process. It stores small pending actions in the shared App Group;
/// the Flutter app applies them to the real database on the next launch/resume.
class HomeWidgetService {
  HomeWidgetService._();

  static final HomeWidgetService instance = HomeWidgetService._();

  static const MethodChannel _channel = MethodChannel('buscontrol/widget');

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<bool> applyPendingTripActions() async {
    if (!_isSupported) return false;

    Map<Object?, Object?> pending;
    try {
      pending = await _channel.invokeMethod<Map<Object?, Object?>>(
            'consumePendingTripActions',
          ) ??
          const <Object?, Object?>{};
    } on PlatformException {
      return false;
    }

    final morning = pending['morning'] as bool?;
    final evening = pending['evening'] as bool?;
    if (morning == null && evening == null) {
      await updateTodaySnapshot();
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await TripRepository.instance.ensureStandardTrips(today);

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'trips',
      where: 'vehicle_id = ? AND date = ?',
      whereArgs: [
        await DatabaseHelper.instance.getActiveVehicleId(),
        _dateKey(today),
      ],
    );

    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      if (id == null) continue;
      final type = row['type']?.toString();
      if (type == TripType.morning.name && morning != null) {
        await TripRepository.instance.setCompleted(
          tripId: id,
          completed: morning,
        );
      } else if (type == TripType.evening.name && evening != null) {
        await TripRepository.instance.setCompleted(
          tripId: id,
          completed: evening,
        );
      }
    }

    await updateTodaySnapshot();
    return true;
  }

  Future<void> updateTodaySnapshot() async {
    if (!_isSupported) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await TripRepository.instance.ensureStandardTrips(today);

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'trips',
      where: 'vehicle_id = ? AND date = ?',
      whereArgs: [
        await DatabaseHelper.instance.getActiveVehicleId(),
        _dateKey(today),
      ],
    );

    var morningDone = false;
    var eveningDone = false;
    for (final row in rows) {
      final type = row['type']?.toString();
      final completed = row['completed'] == 1;
      if (type == TripType.morning.name) morningDone = completed;
      if (type == TripType.evening.name) eveningDone = completed;
    }

    try {
      await _channel.invokeMethod<void>('updateSnapshot', {
        'date': _dateKey(today),
        'morningDone': morningDone,
        'eveningDone': eveningDone,
      });
    } on PlatformException {
      // The app remains fully functional if WidgetKit/App Groups are unavailable.
    }
  }

  Future<String?> consumeQuickAction() async {
    if (!_isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('consumeQuickAction');
    } on PlatformException {
      return null;
    }
  }
}
