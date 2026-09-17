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
import 'services/home_widget_service.dart';

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

  // Apply Home Screen widget actions before building the first frame. This is
  // especially important after a cold launch, when the widget may have toggled
  // morning/evening while BusControl PRO was not open.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    await HomeWidgetService.instance.applyPendingTripActions();
  }

  await NotificationService.instance.initialize();
  await NotificationService.instance.refreshEndMileageReminderSchedule();
  await NotificationService.instance.refreshMaintenanceReminders();

  // Restore/register the nearest upcoming iOS Live Activities after an update
  // or reinstall. Newly saved orders and calendar notes register immediately.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    await NotificationService.instance.refreshUpcomingLiveActivities();
  }

  runApp(const BusControlApp());
}
