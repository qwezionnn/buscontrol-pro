import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../screens/home/home_screen.dart';
import 'auth_screen.dart';
import 'reset_password_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthChangeEvent? _lastEvent;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state != null) {
          _lastEvent = state.event;
        }

        if (_lastEvent == AuthChangeEvent.passwordRecovery) {
          return ResetPasswordScreen(
            onFinished: () {
              if (!mounted) return;
              setState(() {
                _lastEvent = AuthChangeEvent.signedIn;
              });
            },
          );
        }

        final session = state?.session ?? AuthService.instance.currentSession;

        if (session == null) {
          return const AuthScreen();
        }

        return const _CloudReadyHome();
      },
    );
  }
}


class _CloudReadyHome extends StatefulWidget {
  const _CloudReadyHome();

  @override
  State<_CloudReadyHome> createState() => _CloudReadyHomeState();
}

class _CloudReadyHomeState extends State<_CloudReadyHome> {
  late final Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = CloudSyncService.instance.start();
  }

  @override
  void dispose() {
    CloudSyncService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 18),
                    Text('Синхронизация данных...'),
                  ],
                ),
              ),
            ),
          );
        }

        // При отсутствии сети локальная база всё равно остаётся доступной.
        return const HomeScreen();
      },
    );
  }
}
