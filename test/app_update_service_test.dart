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
      final r1 = AppUpdateService.parseSemver('0.1.3');
      final c1 = AppUpdateService.parseSemver('0.1.2+3');
      bool hasUpdate1 = false;
      for (int i = 0; i < 3; i++) {
        if (r1[i] > c1[i]) {
          hasUpdate1 = true;
          break;
        }
        if (r1[i] < c1[i]) break;
      }
      expect(hasUpdate1, isTrue);

      // Una vez actualizada la app a 0.1.3+4 vs Remota 0.1.3 -> NO hay actualización (evita bucle infinito)
      final r2 = AppUpdateService.parseSemver('0.1.3');
      final c2 = AppUpdateService.parseSemver('0.1.3+4');
      bool hasUpdate2 = false;
      for (int i = 0; i < 3; i++) {
        if (r2[i] > c2[i]) {
          hasUpdate2 = true;
          break;
        }
        if (r2[i] < c2[i]) break;
      }
      expect(hasUpdate2, isFalse);

      // Versión local igual a remota -> NO hay actualización
      final r3 = AppUpdateService.parseSemver('0.1.2');
      final c3 = AppUpdateService.parseSemver('0.1.2+3');
      bool hasUpdate3 = false;
      for (int i = 0; i < 3; i++) {
        if (r3[i] > c3[i]) {
          hasUpdate3 = true;
          break;
        }
        if (r3[i] < c3[i]) break;
      }
      expect(hasUpdate3, isFalse);
    });
  });
}
