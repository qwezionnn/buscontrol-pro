import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'database/database_helper.dart';
import 'services/notification_service.dart';
import 'models/order.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp],
    );
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  if (!SupabaseConfig.isConfigured) {
    throw StateError('Supabase configuration is missing.');
  }

  await Supabase.initialize(
    url: 'https://szrnzrnvvkpnlfecskpo.supabase.co',
    publishableKey:
    'sb_publishable_NS5zYLyxKIrNXtpM2-aQzQ_i-zwJUOe',
  );

  await DatabaseHelper.instance.database;
  await NotificationService.instance.initialize();

  // If the app is opened while an order is already inside its Live Activity
  // countdown window, restore/start the countdown immediately.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    final db = await DatabaseHelper.instance.database;
    final vehicleId = await DatabaseHelper.instance.getActiveVehicleId();
    final rows = await db.query(
      'orders',
      where: 'vehicle_id = ? AND status = ?',
      whereArgs: [vehicleId, 'planned'],
    );
    for (final row in rows) {
      await NotificationService.instance.startLiveActivityIfEligible(Order.fromMap(row));
    }
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    await NotificationService.instance.startNearestCalendarNoteLiveActivityIfEligible();
  }

  runApp(const BusControlApp());
}
