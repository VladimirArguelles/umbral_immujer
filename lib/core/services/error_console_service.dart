import 'dart:async';
import 'package:flutter/foundation.dart';

/// Modelo de datos que representa una entrada en la consola de diagnóstico de errores.
class LogItem {
  final DateTime timestamp;
  final String origen;
  final String mensaje;
  final String causa;

  const LogItem({
    required this.timestamp,
    required this.origen,
    required this.mensaje,
    required this.causa,
  });
}

/// Servicio Singleton que administra los registros de errores en memoria para depuración en vivo.
/// Mantiene un búfer circular de máximo 50 elementos para optimizar el uso de memoria.
class ErrorConsoleService extends ChangeNotifier {
  ErrorConsoleService._internal();

  /// Instancia única accesible globalmente.
  static final ErrorConsoleService instance = ErrorConsoleService._internal();

  /// Límite máximo de logs conservados en memoria.
  static const int maxLogs = 50;

  final List<LogItem> _logs = [];

  /// Lista inmutable de registros ordenados del más reciente al más antiguo.
  List<LogItem> get logs => List.unmodifiable(_logs);

  /// Registra un nuevo error capturado en el búfer en memoria.
  void registrarError({
    required String origen,
    required dynamic error,
    dynamic causa,
  }) {
    final item = LogItem(
      timestamp: DateTime.now(),
      origen: origen,
      mensaje: error?.toString() ?? 'Error desconocido',
      causa: causa?.toString() ?? '',
    );

    _logs.insert(0, item);
    if (_logs.length > maxLogs) {
      _logs.removeRange(maxLogs, _logs.length);
    }
    notifyListeners();
  }

  /// Elimina todos los registros de error almacenados en memoria.
  void limpiarLogs() {
    _logs.clear();
    notifyListeners();
  }
}

/// Envoltorio global para ejecutar de forma segura funciones asíncronas con captura de errores.
/// Si la acción arroja una excepción, la envía automáticamente a [ErrorConsoleService].
Future<void> ejecutarConConsola(
  String origen,
  Future<void> Function() accion,
) async {
  try {
    await accion();
  } catch (e, stack) {
    ErrorConsoleService.instance.registrarError(
      origen: origen,
      error: e,
      causa: stack,
    );
  }
}
