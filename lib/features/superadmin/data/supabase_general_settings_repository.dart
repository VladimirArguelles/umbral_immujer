import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/features/superadmin/domain/general_settings_repository.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';

/// Supabase-backed implementation of [GeneralSettingsRepository].
class SupabaseGeneralSettingsRepository implements GeneralSettingsRepository {
  SupabaseGeneralSettingsRepository({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> fetchSettings() async {
    final response = await _client
        .from('configuracion_general')
        .select('clave, valor, descripcion');

    final result = <String, dynamic>{};
    for (final item in response as List) {
      final clave = item['clave'] as String;
      result[clave] = item['valor'];
    }
    return result;
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> updates) async {
    final now = DateTime.now().toIso8601String();
    final rows = updates.entries
        .map(
          (entry) => {
            'clave': entry.key,
            'valor': entry.value,
            'actualizado_en': now,
          },
        )
        .toList();

    await _client
        .from('configuracion_general')
        .upsert(rows, onConflict: 'clave');
  }
}
