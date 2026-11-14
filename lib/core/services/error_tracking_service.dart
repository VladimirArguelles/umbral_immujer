import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:umbral_immujer/core/services/error_console_service.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';

/// Modelo representativo de una excepción técnica registrada en la plataforma.
class SystemExceptionItem {
  final String id;
  final DateTime timestamp;
  final String severity; // 'error', 'warning', 'critical'
  final String module;
  final String errorMessage;
  final String? stackTrace;
  final String? userId;
  final Map<String, dynamic> metadata;

  const SystemExceptionItem({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.module,
    required this.errorMessage,
    this.stackTrace,
    this.userId,
    this.metadata = const {},
  });

  factory SystemExceptionItem.fromMap(Map<String, dynamic> map) {
    return SystemExceptionItem(
      id: map['id']?.toString() ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      severity: map['severity']?.toString().toLowerCase() ?? 'error',
      module: map['module']?.toString() ?? 'general',
      errorMessage: map['error_message']?.toString() ?? 'Error desconocido',
      stackTrace: map['stack_trace']?.toString(),
      userId: map['user_id']?.toString(),
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : {},
    );
  }

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';
  bool get isError => severity == 'error';
}

/// Servicio singleton que centraliza la captura, clasificación y persistencia
/// de excepciones técnicas y fallos de renderizado en Supabase y memoria.
class ErrorTrackingService {
  ErrorTrackingService._();
  static final ErrorTrackingService instance = ErrorTrackingService._();

  bool _isReporting = false;

  /// Registra una excepción capturada manualmente o por interceptores
  Future<void> reportException({
    required dynamic error,
    StackTrace? stackTrace,
    String? module,
    String severity = 'error',
    Map<String, dynamic>? metadata,
  }) async {
    // 1. Registro inmediato en búfer de memoria local para diagnóstico offline
    final resolvedModule = module ?? _inferModule(error, stackTrace);
    final resolvedSeverity = _normalizeSeverity(severity, error);
    final errorString = error?.toString() ?? 'Excepción no especificada';
    final stackString = stackTrace?.toString();

    try {
      ErrorConsoleService.instance.registrarError(
        origen: '[$resolvedSeverity] $resolvedModule',
        error: errorString,
        causa: stackTrace,
      );
    } catch (_) {}

    // 2. Persistencia en Supabase `system_exceptions` con protección anti-bucle
    if (_isReporting) return;
    _isReporting = true;

    try {
      final supabase = SupabaseConfig.client;
      final userId = supabase.auth.currentUser?.id;

      await supabase.from('system_exceptions').insert({
        'severity': resolvedSeverity,
        'module': resolvedModule,
        'error_message': errorString,
        'stack_trace': stackString,
        'user_id': userId,
        'metadata': {
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'reported_at': DateTime.now().toIso8601String(),
          ...?metadata,
        },
      });
    } catch (e) {
      debugPrint('[ErrorTrackingService] Falla al persistir en Supabase: $e');
    } finally {
      _isReporting = false;
    }
  }

  /// Captura y clasifica errores del árbol de widgets (FlutterError.onError)
  void captureWidgetError(FlutterErrorDetails details) {
    final isRenderFlex = details.exceptionAsString().contains('RenderFlex') ||
        details.exceptionAsString().contains('overflowed');

    final severity = isRenderFlex ? 'critical' : 'error';
    final module = isRenderFlex ? 'render_ui' : 'flutter_framework';

    unawaited(
      reportException(
        error: details.exceptionAsString(),
        stackTrace: details.stack,
        module: module,
        severity: severity,
        metadata: {
          'library': details.library ?? 'widgets',
          'context': details.context?.toString(),
        },
      ),
    );
  }

  /// Captura excepciones asíncronas no controladas (PlatformDispatcher.onError)
  bool captureAsyncError(Object error, StackTrace stackTrace) {
    unawaited(
      reportException(
        error: error,
        stackTrace: stackTrace,
        module: _inferModule(error, stackTrace),
        severity: 'error',
      ),
    );
    return true; // Indica al dispatcher que el error fue gestionado
  }

  /// Infiere el módulo del sistema a partir del tipo de error o stack trace
  String _inferModule(dynamic error, StackTrace? stack) {
    final text = '${error.toString().toLowerCase()} ${stack?.toString().toLowerCase() ?? ''}';

    if (text.contains('renderflex') || text.contains('paint') || text.contains('layout')) {
      return 'render_ui';
    }
    if (text.contains('supabase') || text.contains('postgrest') || text.contains('postgresql')) {
      return 'database_supabase';
    }
    if (text.contains('socket') || text.contains('http') || text.contains('dio') || text.contains('network')) {
      return 'network_connectivity';
    }
    if (text.contains('auth') || text.contains('jwt') || text.contains('session')) {
      return 'auth_security';
    }
    if (text.contains('asistencia') || text.contains('bluetooth')) {
      return 'attendance_module';
    }
    if (text.contains('inscrip')) {
      return 'enrollment_module';
    }
    return 'general';
  }

  /// Normaliza la severidad garantizando los valores CHECK de PostgreSQL
  String _normalizeSeverity(String raw, dynamic error) {
    final lower = raw.toLowerCase().trim();
    if (lower == 'critical' || lower == 'warning' || lower == 'error') {
      return lower;
    }

    final errString = error.toString().toLowerCase();
    if (errString.contains('renderflex') || errString.contains('fatal') || errString.contains('panic')) {
      return 'critical';
    }
    if (errString.contains('timeout') || errString.contains('warn') || errString.contains('offline')) {
      return 'warning';
    }
    return 'error';
  }
}
