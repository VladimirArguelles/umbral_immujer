import 'package:flutter_test/flutter_test.dart';
import 'package:umbral_immujer/core/services/error_console_service.dart';

void main() {
  group('ErrorConsoleService Unit Tests', () {
    setUp(() {
      ErrorConsoleService.instance.limpiarLogs();
    });

    test('registrarError añade log correctamente al inicio del búfer', () {
      final service = ErrorConsoleService.instance;
      expect(service.logs.isEmpty, isTrue);

      service.registrarError(
        origen: 'TestModule',
        error: 'Excepción simulada',
        causa: 'StackTrace simulado',
      );

      expect(service.logs.length, equals(1));
      final item = service.logs.first;
      expect(item.origen, equals('TestModule'));
      expect(item.mensaje, equals('Excepción simulada'));
      expect(item.causa, equals('StackTrace simulado'));
      expect(item.timestamp, isNotNull);
    });

    test('limitar logs a un máximo estricto de 50 elementos', () {
      final service = ErrorConsoleService.instance;

      for (int i = 0; i < 65; i++) {
        service.registrarError(
          origen: 'LoopModule',
          error: 'Error $i',
          causa: 'Causa $i',
        );
      }

      expect(service.logs.length, equals(ErrorConsoleService.maxLogs));
      expect(service.logs.first.mensaje, equals('Error 64'));
      expect(service.logs.last.mensaje, equals('Error 15'));
    });

    test('limpiarLogs vacía el búfer de logs en memoria', () {
      final service = ErrorConsoleService.instance;
      service.registrarError(origen: 'Mod', error: 'Err');
      expect(service.logs.isNotEmpty, isTrue);

      service.limpiarLogs();
      expect(service.logs.isEmpty, isTrue);
    });

    test('ejecutarConConsola captura y registra excepciones asíncronas automáticamente', () async {
      final service = ErrorConsoleService.instance;

      await ejecutarConConsola('AsyncTest', () async {
        throw Exception('Fallo asíncrono controlado');
      });

      expect(service.logs.length, equals(1));
      expect(service.logs.first.origen, equals('AsyncTest'));
      expect(service.logs.first.mensaje, contains('Fallo asíncrono controlado'));
      expect(service.logs.first.causa, isNotEmpty);
    });
  });
}
