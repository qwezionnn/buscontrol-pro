import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': displayName.trim(),
      },
    );
  }

  Future<void> sendPasswordReset({
    required String email,
    required String redirectTo,
  }) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }

  Future<UserResponse> updatePassword(String password) {
    return _client.auth.updateUser(
      UserAttributes(password: password),
    );
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Сессия пользователя не найдена.');
    }

    final name = displayName.trim();

    await _client.auth.updateUser(
      UserAttributes(data: {'display_name': name}),
    );

    await _client
        .from('profiles')
        .update({
          'display_name': name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', user.id);
  }

  Future<Map<String, dynamic>?> loadProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  Future<void> signOut() => _client.auth.signOut();
}
