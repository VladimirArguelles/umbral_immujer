import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Servicio centralizado para resolución de URLs firmadas temporales (Time-limited Signed URLs)
/// Garantiza la privacidad y cumplimiento de acceso seguro a comprobantes y justificativos
/// sin exponer buckets de Supabase al público general.
class StorageUrlService {
  StorageUrlService._();

  static SupabaseClient get _supabase => SupabaseConfig.client;

  /// Resuelve una URL firmada segura temporal (por defecto 2 horas / 7200s)
  /// a partir de una ruta interna o de una URL existente.
  static Future<String> getSignedUrl(
    String rawPathOrUrl, {
    int expiresInSeconds = 7200,
  }) async {
    final trimmed = rawPathOrUrl.trim();
    if (trimmed.isEmpty) return '';

    // Si ya contiene token firmado no expirado, retornar directamente
    if (trimmed.contains('token=')) return trimmed;

    try {
      String bucket = 'comprobantes';
      String path = trimmed;

      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final uri = Uri.parse(trimmed);
        final segments = uri.pathSegments;

        final compIdx = segments.indexOf('comprobantes');
        final justIdx = segments.indexOf('justificativos');

        if (compIdx != -1 && compIdx < segments.length - 1) {
          bucket = 'comprobantes';
          path = segments.sublist(compIdx + 1).join('/');
        } else if (justIdx != -1 && justIdx < segments.length - 1) {
          bucket = 'justificativos';
          path = segments.sublist(justIdx + 1).join('/');
        }
      } else if (trimmed.startsWith('comprobantes/')) {
        bucket = 'comprobantes';
        path = trimmed.substring('comprobantes/'.length);
      } else if (trimmed.startsWith('justificativos/')) {
        bucket = 'justificativos';
        path = trimmed.substring('justificativos/'.length);
      }

      if (path.isEmpty) return trimmed;

      // Invocar createSignedUrl en el cliente Supabase Storage
      final signed = await _supabase.storage
          .from(bucket)
          .createSignedUrl(path, expiresInSeconds);

      return signed;
    } catch (e) {
      debugPrint('[StorageUrlService] Aviso: No se pudo firmar URL ($e), usando fallback.');
      return trimmed;
    }
  }
}
