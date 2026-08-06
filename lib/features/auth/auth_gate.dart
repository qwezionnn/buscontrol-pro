import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/auth_service.dart';
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

        return const HomeScreen();
      },
    );
  }
}
