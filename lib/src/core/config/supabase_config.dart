import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración de cliente Supabase.
/// Cumple estrictamente con la política de seguridad Cero Hardcoding:
/// Las credenciales se obtienen exclusivamente desde variables de entorno.
class SupabaseConfig {
  static SupabaseClient get client => Supabase.instance.client;

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static String get url => _envUrl;
  static String get key => _envKey;

  static Future<void> initialize() async {
    final resolvedUrl = url.trim();
    final resolvedKey = key.trim();

    if (resolvedUrl.isEmpty || resolvedKey.isEmpty) {
      throw StateError(
        'Seguridad UMBRAL: SUPABASE_URL y SUPABASE_ANON_KEY / SUPABASE_PUBLISHABLE_KEY '
        'deben ser suministrados exclusivamente mediante el archivo .env usando '
        '--dart-define-from-file=.env o mediante --dart-define. '
        'No se permiten credenciales hardcodeadas en el código fuente.',
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
