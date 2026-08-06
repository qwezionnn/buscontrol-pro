class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://szrnzrnvvkpnlfecskpo.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_NS5zYLyxKIrNXtpM2-aQzQ_i-zwJUOe',
  );

  static bool get isConfigured =>
      url.startsWith('https://') && publishableKey.isNotEmpty;
}
