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

    test('parseBuildNumber extrae correctamente build_number entero de texto o sufijo +', () {
      expect(AppUpdateService.parseBuildNumber('0.1.3+4'), equals(4));
      expect(AppUpdateService.parseBuildNumber('0.1+3'), equals(3));
      expect(
        AppUpdateService.parseBuildNumber('0.1.3', explicitBuildNumber: '4'),
        equals(4),
      );
      expect(
        AppUpdateService.parseBuildNumber('0.1.3', explicitBuildNumber: 5),
        equals(5),
      );
      expect(AppUpdateService.parseBuildNumber('v0.1.3'), isNull);
    });

    test('isUpdateAvailable compara numéricamente build_number y evita falsos positivos v0.1.3 vs v0.1+3', () {
      // Mismo buildNumber (3 == 3) aunque el texto difiera ('v0.1.3' vs '0.1+3') -> NO hay actualización
      expect(
        AppUpdateService.isUpdateAvailable(
          remoteVersion: 'v0.1.3',
          currentVersion: '0.1+3',
          remoteBuildNumber: 3,
          currentBuildNumber: 3,
        ),
        isFalse,
      );

      // Build igual en formato +4 -> NO hay actualización
      expect(
        AppUpdateService.isUpdateAvailable(
          remoteVersion: '0.1.3+4',
          currentVersion: '0.1.3',
          currentBuildNumber: 4,
        ),
        isFalse,
      );

      // Build remoto estrictamente mayor (5 > 4) -> SÍ hay actualización
      expect(
        AppUpdateService.isUpdateAvailable(
          remoteVersion: '0.1.3',
          currentVersion: '0.1.3',
          remoteBuildNumber: 5,
          currentBuildNumber: 4,
        ),
        isTrue,
      );

      expect(
        AppUpdateService.isUpdateAvailable(
          remoteVersion: '0.1.3+5',
          currentVersion: '0.1.3+4',
        ),
        isTrue,
      );

      // Build remoto menor (4 < 5) -> NO hay actualización
      expect(
        AppUpdateService.isUpdateAvailable(
          remoteVersion: '0.1.3',
          currentVersion: '0.1.4',
          remoteBuildNumber: 4,
          currentBuildNumber: 5,
        ),
        isFalse,
      );

      // Sin build_number remoto: fallback a semver canónico
      expect(
        AppUpdateService.isUpdateAvailable(
          remoteVersion: 'v0.1.3',
          currentVersion: '0.1.3',
          currentBuildNumber: 4,
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isUpdateAvailable(
          remoteVersion: 'v0.1.4',
          currentVersion: '0.1.3',
          currentBuildNumber: 4,
        ),
        isTrue,
      );
    });

    test('Control de sesión: markUpdateDialogDismissed y resetSessionCheck', () {
      AppUpdateService.resetSessionCheck();
      expect(AppUpdateService.instance.hasCheckedUpdate, isFalse);
      expect(AppUpdateService.instance.isUpdateDialogDismissed, isFalse);

      AppUpdateService.instance.markUpdateDialogDismissed();
      expect(AppUpdateService.instance.isUpdateDialogDismissed, isTrue);

      AppUpdateService.resetSessionCheck();
      expect(AppUpdateService.instance.isUpdateDialogDismissed, isFalse);
    });
  });
}
