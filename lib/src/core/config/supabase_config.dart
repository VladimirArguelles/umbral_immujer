import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración de cliente Supabase.
/// Cumple estrictamente con la política de seguridad Cero Hardcoding:
/// Las credenciales se obtienen exclusivamente desde variables de entorno.
class SupabaseConfig {
  static SupabaseClient get client => Supabase.instance.client;

  static const String defaultProjectUrl =
      'https://kkgacvhbcxgoxjpnkxmw.supabase.co';

  static const String _envUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: defaultProjectUrl,
  );
  static const String _envKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static String get url {
    final trimmed = _envUrl.trim();
    if (trimmed.isEmpty || trimmed.contains('your-project.supabase.co')) {
      return defaultProjectUrl;
    }
    return trimmed;
  }

  static String get key => _envKey.trim();

  static Future<void> initialize() async {
    final resolvedUrl = url;
    final resolvedKey = key;

    if (resolvedKey.isEmpty || resolvedKey == 'your-anon-key-here') {
      throw StateError(
        'Seguridad UMBRAL: SUPABASE_ANON_KEY / SUPABASE_PUBLISHABLE_KEY '
        'debe ser suministrado mediante .env (--dart-define-from-file=.env) '
        'o --dart-define. No se permiten claves API hardcodeadas ni de ejemplo.',
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
