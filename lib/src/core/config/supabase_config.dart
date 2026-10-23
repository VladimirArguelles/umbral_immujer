import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static SupabaseClient get client => Supabase.instance.client;

  // Valores predeterminados de desarrollo (tomados de .env)
  static const String _defaultUrl = 'https://kkgacvhbcxgoxjpnkxmw.supabase.co';
  static const String _defaultKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtrZ2FjdmhiY3hnb3hqcG5reG13Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2MDIxNjMsImV4cCI6MjEwODE3ODE2M30.Fj_VaXjO7sdlLB7BfJI-4R6iK9uLFi_oRmxUWKr2g4c';

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static String get url => _envUrl.isNotEmpty ? _envUrl : _defaultUrl;
  static String get key => _envKey.isNotEmpty ? _envKey : _defaultKey;

  static Future<void> initialize() async {
    final resolvedUrl = url;
    final resolvedKey = key;

    if (resolvedUrl.isEmpty || resolvedKey.isEmpty) {
      throw StateError(
        'Define SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY con --dart-define o en el archivo .env.',
      );
    }

    // ignore: deprecated_member_use
    await Supabase.initialize(
      url: resolvedUrl,
      // ignore: deprecated_member_use
      anonKey: resolvedKey,
    );
  }
}
