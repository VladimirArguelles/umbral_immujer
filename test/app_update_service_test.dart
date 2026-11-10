import 'package:flutter_test/flutter_test.dart';
import 'package:umbral_immujer/src/core/services/app_update_service.dart';

void main() {
  group('AppUpdateService Semver Normalization Tests', () {
    test('parseSemver maneja correctamente versiones con build numbers y prefijos', () {
      expect(AppUpdateService.parseSemver('0.1.2+3'), equals([0, 1, 2]));
      expect(AppUpdateService.parseSemver('v0.1.2+3'), equals([0, 1, 2]));
      expect(AppUpdateService.parseSemver('v0.1.2'), equals([0, 1, 2]));
      expect(AppUpdateService.parseSemver('0.1.2'), equals([0, 1, 2]));
      expect(AppUpdateService.parseSemver('"0.1.2"'), equals([0, 1, 2]));
      expect(AppUpdateService.parseSemver('0.1.3+10'), equals([0, 1, 3]));
      expect(AppUpdateService.parseSemver('1.0.0'), equals([1, 0, 0]));
      expect(AppUpdateService.parseSemver('0.1'), equals([0, 1, 0]));
    });

    test('formatSemver produce cadena canónica major.minor.patch', () {
      expect(AppUpdateService.formatSemver('0.1.2+3'), equals('0.1.2'));
      expect(AppUpdateService.formatSemver('v0.1.2'), equals('0.1.2'));
      expect(AppUpdateService.formatSemver('0.1.3+99'), equals('0.1.3'));
    });

    test('Identifica cuando una versión remota es estrictamente superior y evita bucles', () {
      // Remota 0.1.3 vs Local 0.1.2+3 -> Actualización detectada
      expect(AppUpdateService.isVersionGreater('0.1.3', '0.1.2+3'), isTrue);
      expect(AppUpdateService.isVersionGreater('v0.1.3', '0.1.2'), isTrue);
      expect(AppUpdateService.isVersionGreater('0.2.0', '0.1.9+5'), isTrue);
      expect(AppUpdateService.isVersionGreater('1.0.0', '0.9.9'), isTrue);

      // Una vez actualizada la app a 0.1.3+4 vs Remota 0.1.3 -> NO hay actualización (evita bucle infinito)
      expect(AppUpdateService.isVersionGreater('0.1.3', '0.1.3+4'), isFalse);
      expect(AppUpdateService.isVersionGreater('0.1.3', '0.1.3'), isFalse);
      expect(AppUpdateService.isVersionGreater('0.1.2', '0.1.2+3'), isFalse);
      expect(AppUpdateService.isVersionGreater('0.1.2', '0.1.3'), isFalse);
    });
  });
}
