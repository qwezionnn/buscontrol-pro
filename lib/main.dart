import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'database/database_helper.dart';

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

  runApp(const BusControlApp());
}
