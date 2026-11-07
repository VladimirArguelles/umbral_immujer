import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';

/// Servicio centralizado de registro y notificación de errores del sistema.
/// Almacena las incidencias técnicas en la tabla `notificaciones` con destino al Super Admin,
/// detallando el módulo, la ubicación del error, las causas probables y la acción de soporte.
class SystemErrorNotificationService {
  static final SupabaseClient _supabase = SupabaseConfig.client;

  /// Registra una falla del sistema y la notifica al Super Admin.
  static Future<void> reportarError({
    required String modulo,
    required String titulo,
    required dynamic error,
    StackTrace? stackTrace,
    String? dondeEstaElProblema,
    String? causasProbables,
    String? solucionSugerida,
    Map<String, dynamic>? contextoExtra,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      final errorStr = error?.toString() ?? 'Error desconocido';

      final ubicacion = dondeEstaElProblema ?? 'Módulo: $modulo';
      final analisisCausas = [
        if (causasProbables != null && causasProbables.trim().isNotEmpty)
          '🔍 CAUSAS PROBABLES:\n$causasProbables',
        if (solucionSugerida != null && solucionSugerida.trim().isNotEmpty)
          '🛠️ SOLUCIÓN / REVISIÓN SUGERIDA:\n$solucionSugerida',
      ].join('\n\n');

      final Map<String, dynamic> datos = {
        'modulo': modulo,
        'donde_esta_el_problema': ubicacion,
        'que_debe_revisar': analisisCausas.isNotEmpty
            ? analisisCausas
            : 'Verificar la consola del navegador, logs de Supabase o permisos del dispositivo.',
        'error_detallado': errorStr,
        'usuario_id': user?.id,
        'usuario_email': user?.email ?? 'Sesión no autenticada',
        'plataforma': kIsWeb ? 'Web (${defaultTargetPlatform.name})' : defaultTargetPlatform.name,
        'timestamp': DateTime.now().toIso8601String(),
        if (stackTrace != null)
          'stack_trace': stackTrace.toString().split('\n').take(6).join('\n'),
        ...?contextoExtra,
      };

      await _supabase.from('notificaciones').insert({
        'usuario_origen_id': user?.id,
        'rol_destino': 'super_admin',
        'titulo': titulo,
        'mensaje': errorStr,
        'tipo': 'error_sistema',
        'leido': false,
        'datos': datos,
      });

      debugPrint('[SystemErrorNotificationService] Incidencia reportada a Super Admin: $titulo');
    } catch (e) {
      // Garantizar que fallos en el logger nunca tumben la aplicación
      debugPrint('[SystemErrorNotificationService] No se pudo enviar el reporte: $e');
    }
  }
}
