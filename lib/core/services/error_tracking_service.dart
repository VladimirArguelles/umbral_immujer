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
  DateTime? _lastNotifTime;
  String? _lastNotifSignature;

  /// Proveedor desacoplado de la ruta activa del navegador
  static String Function()? currentRouteProvider;

  /// Obtiene la ruta actual de la interfaz o '/' por defecto
  static String getCurrentRoute() {
    if (currentRouteProvider != null) {
      try {
        final route = currentRouteProvider!();
        if (route.isNotEmpty) return route;
      } catch (_) {}
    }
    return '/';
  }

  /// Extrae con precisión el archivo del proyecto y número de línea causante del fallo
  static String extractSourceLocation(StackTrace? stackTrace, [FlutterErrorDetails? details]) {
    if (stackTrace != null) {
      final lines = stackTrace.toString().split('\n');
      for (final line in lines) {
        if (line.contains('package:umbral_immujer/')) {
          final match = RegExp(r'package:umbral_immujer/([^\s\)]+)').firstMatch(line);
          if (match != null) {
            return 'lib/${match.group(1)}';
          }
        }
      }
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('#0') || trimmed.startsWith('#1')) {
          final match = RegExp(r'([a-zA-Z0-9_\/]+\.dart:\d+(?::\d+)?)').firstMatch(trimmed);
          if (match != null) {
            return match.group(1)!;
          }
        }
      }
    }
    if (details?.context != null) {
      return details!.context.toString();
    }
    return 'código_fuente';
  }

  /// Registra una excepción capturada manualmente o por interceptores
  Future<void> reportException({
    required dynamic error,
    StackTrace? stackTrace,
    String? module,
    String severity = 'error',
    Map<String, dynamic>? metadata,
  }) async {
    final currentRoute = metadata?['screen_route']?.toString() ?? getCurrentRoute();
    final sourceLoc = metadata?['source_location']?.toString() ?? extractSourceLocation(stackTrace);
    final fullRoute = module ?? metadata?['full_route']?.toString() ?? '$currentRoute • $sourceLoc';
    final resolvedSeverity = _normalizeSeverity(severity, error);
    final errorString = error?.toString() ?? 'Excepción no especificada';
    final stackString = stackTrace?.toString();

    // 1. Registro inmediato en búfer de memoria local para diagnóstico offline
    try {
      ErrorConsoleService.instance.registrarError(
        origen: '[$resolvedSeverity] $fullRoute',
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

      // El campo 'module' de la tabla system_exceptions es VARCHAR(100)
      final safeModule = fullRoute.length > 95 ? fullRoute.substring(0, 95) : fullRoute;

      await supabase.from('system_exceptions').insert({
        'severity': resolvedSeverity,
        'module': safeModule,
        'error_message': errorString,
        'stack_trace': stackString,
        'user_id': userId,
        'metadata': {
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'reported_at': DateTime.now().toIso8601String(),
          'full_route': fullRoute,
          'screen_route': currentRoute,
          'source_location': sourceLoc,
          ...?metadata,
        },
      });

      // 3. Crear notificación técnica específica e inmediata para el Super Admin
      final isRenderFlex = errorString.contains('RenderFlex') ||
          errorString.contains('overflowed') ||
          (metadata?['is_render_error'] == true);

      final signature = '$currentRoute:$sourceLoc:$errorString';
      final now = DateTime.now();
      final canNotify = _lastNotifTime == null ||
          now.difference(_lastNotifTime!).inSeconds >= 3 ||
          _lastNotifSignature != signature;

      if (canNotify) {
        _lastNotifTime = now;
        _lastNotifSignature = signature;

        final notifTitle = isRenderFlex
            ? 'Fallo Renderizado: $currentRoute'
            : 'Error Técnico: $currentRoute';

        final notifMessage = isRenderFlex
            ? 'Desbordamiento o fallo visual detectado en $sourceLoc'
            : (errorString.length > 250 ? '${errorString.substring(0, 250)}...' : errorString);

        await supabase.from('notificaciones').insert({
          'usuario_origen_id': userId,
          'rol_destino': 'super_admin',
          'titulo': notifTitle,
          'mensaje': notifMessage,
          'tipo': 'incidencia_operacion',
          'datos': {
            'modulo': fullRoute,
            'ruta_completa': fullRoute,
            'pantalla': currentRoute,
            'ubicacion_codigo': sourceLoc,
            'donde_esta_el_problema': 'Falla en $currentRoute • Código: $sourceLoc',
            'que_debe_revisar': '$errorString\nUbicación: $sourceLoc\nPantalla: $currentRoute',
            'severidad': resolvedSeverity,
          },
          'leido': false,
        });
      }
    } catch (e) {
      debugPrint('[ErrorTrackingService] Falla al persistir en Supabase o notificar: $e');
    } finally {
      _isReporting = false;
    }
  }

  /// Captura y clasifica errores del árbol de widgets (FlutterError.onError)
  void captureWidgetError(FlutterErrorDetails details) {
    final errStr = details.exceptionAsString();
    final isRenderFlex = errStr.contains('RenderFlex') ||
        errStr.contains('overflowed') ||
        errStr.contains('paint') ||
        errStr.contains('layout');

    final severity = isRenderFlex ? 'critical' : 'error';
    final currentRoute = getCurrentRoute();
    final sourceLoc = extractSourceLocation(details.stack, details);
    final contextDesc = details.context?.toString() ??
        (isRenderFlex ? 'Fallo RenderFlex / Desbordamiento UI' : 'Error en Widget Tree');

    final fullRoute = '$currentRoute • $sourceLoc ($contextDesc)';

    unawaited(
      reportException(
        error: details.exceptionAsString(),
        stackTrace: details.stack,
        module: fullRoute,
        severity: severity,
        metadata: {
          'library': details.library ?? 'widgets',
          'context': details.context?.toString(),
          'full_route': fullRoute,
          'screen_route': currentRoute,
          'source_location': sourceLoc,
          'is_render_error': isRenderFlex,
        },
      ),
    );
  }

  /// Captura excepciones asíncronas no controladas (PlatformDispatcher.onError)
  bool captureAsyncError(Object error, StackTrace stackTrace) {
    final currentRoute = getCurrentRoute();
    final sourceLoc = extractSourceLocation(stackTrace);
    final fullRoute = '$currentRoute • $sourceLoc';

    unawaited(
      reportException(
        error: error,
        stackTrace: stackTrace,
        module: fullRoute,
        severity: 'error',
        metadata: {
          'full_route': fullRoute,
          'screen_route': currentRoute,
          'source_location': sourceLoc,
        },
      ),
    );
    return true; // Indica al dispatcher que el error fue gestionado
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
