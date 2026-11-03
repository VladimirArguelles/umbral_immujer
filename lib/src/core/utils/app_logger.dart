import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Servicio centralizado de logging para UMBRAL IMMUJER.
/// Proporciona trazabilidad estructurada de eventos, advertencias y errores
/// sin exponer datos sensibles ni degradar el rendimiento en producción.
class AppLogger {
  AppLogger._();

  /// Registra información de flujo normal
  static void info(String message, {String tag = 'INFO', dynamic data}) {
    final formatted = '[$tag] $message${data != null ? ' | Data: $data' : ''}';
    if (kDebugMode) {
      developer.log(formatted, name: 'UMBRAL', level: 800);
    }
  }

  /// Registra advertencias de seguridad o validaciones
  static void warning(
    String message, {
    String tag = 'WARN',
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final formatted = '[$tag] $message';
    developer.log(
      formatted,
      name: 'UMBRAL',
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Registra errores críticos del sistema con stack trace
  static void error(
    String message, {
    String tag = 'ERROR',
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final formatted = '[$tag] $message';
    developer.log(
      formatted,
      name: 'UMBRAL',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
    if (kDebugMode && error != null) {
      debugPrint('🚨 ERROR UMBRAL [$tag]: $message\nDetalle: $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  /// Registra trazas de depuración (solo activo en entorno de desarrollo)
  static void debug(String message, {String tag = 'DEBUG', dynamic data}) {
    if (kDebugMode) {
      developer.log(
        '[$tag] $message${data != null ? ' | Data: $data' : ''}',
        name: 'UMBRAL',
        level: 500,
      );
    }
  }
}
