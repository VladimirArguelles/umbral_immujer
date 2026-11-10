import 'dart:io' show Directory, File, FileMode, FileSystemException, Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_update_dialog.dart';

/// Información de la versión de la app y actualización disponible.
class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String apkUrl;
  final String releaseNotes;
  final bool isMandatory;

  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.apkUrl,
    required this.releaseNotes,
    this.isMandatory = false,
  });
}

/// Servicio que gestiona la detección de nuevas versiones y actualización In-App del APK.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String defaultReleaseUrl =
      'https://github.com/VladimirArguelles/umbral_immujer/releases/latest';

  static bool _hasPromptedThisSession = false;
  static bool _isCheckingThisSession = false;

  /// Restablece la bandera de verificación de actualización para nueva sesión (ej. tras logout).
  static void resetSessionCheck() {
    _hasPromptedThisSession = false;
    _isCheckingThisSession = false;
  }

  /// Verifica si hay una actualización disponible y muestra el diálogo modal únicamente
  /// si el usuario se encuentra en la pantalla principal de inicio (Dashboard inicial tras el login),
  /// evitando que aparezca al navegar entre otros módulos inferiores o secundarios.
  Future<void> checkAndShowUpdateModal(
    BuildContext context, {
    bool force = false,
  }) async {
    if ((!force && _hasPromptedThisSession) || _isCheckingThisSession) {
      return;
    }

    if (!context.mounted || !_isActiveRootDashboard(context)) return;

    _isCheckingThisSession = true;
    try {
      final info = await checkForUpdate();
      if (!context.mounted || !_isActiveRootDashboard(context)) return;

      _hasPromptedThisSession = true;
      if (info.hasUpdate) {
        await AppUpdateDialog.show(context, info);
      }
    } catch (e) {
      debugPrint(
        '[AppUpdateService] Error al verificar actualización en dashboard: $e',
      );
    } finally {
      _isCheckingThisSession = false;
    }
  }

  bool _isActiveRootDashboard(BuildContext context) {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }

    try {
      final location = GoRouterState.of(context).matchedLocation;
      const rootDashboards = {
        '/',
        '/student',
        '/teacher',
        '/coordinator',
        '/superadmin',
      };
      if (rootDashboards.contains(location)) return true;

      debugPrint(
        '[AppUpdateService] Modal omitido: la ruta actual ($location) no es la raíz de inicio.',
      );
    } catch (error) {
      debugPrint(
        '[AppUpdateService] Modal omitido: no se pudo verificar la ruta activa ($error).',
      );
    }
    return false;
  }

  bool get isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<String> getUpdateApkPath(String version) async {
    final Directory baseDir;
    if (isAndroidPlatform) {
      // getExternalStorageDirectory() mapea a context.getExternalFilesDir(null).
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw StateError(
          'Android no proporcionó un directorio externo para guardar el APK.',
        );
      }
      baseDir = externalDir;
    } else {
      baseDir = await getApplicationSupportDirectory();
    }
    final safeVersion = formatSemver(version).replaceAll('.', '_');
    return '${baseDir.path}${Platform.pathSeparator}umbral_update_$safeVersion.apk';
  }

  /// Extrae y normaliza exclusivamente la versión semántica (major, minor, patch),
  /// descartando prefijos 'v', sufijos de compilación (+3) y metadatos pre-release.
  /// Ejemplo: '0.1.2+3' o 'v0.1.2' se normalizan a [0, 1, 2].
  static List<int> parseSemver(String raw) {
    var clean = raw.trim().replaceAll('"', '').replaceAll("'", '');
    if (clean.toLowerCase().startsWith('v')) {
      clean = clean.substring(1).trim();
    }
    // Descartar metadatos de compilación (+X)
    if (clean.contains('+')) {
      clean = clean.split('+').first.trim();
    }
    // Descartar pre-releases (-beta, -rc, etc.)
    if (clean.contains('-')) {
      clean = clean.split('-').first.trim();
    }

    final parts = clean.split('.');
    final List<int> nums = [];
    for (final part in parts) {
      final digits = RegExp(r'\d+').firstMatch(part)?.group(0);
      nums.add(digits != null ? (int.tryParse(digits) ?? 0) : 0);
    }
    while (nums.length < 3) {
      nums.add(0);
    }
    return nums.sublist(0, 3);
  }

  /// Formatea la versión en notación semántica canónica (ej. '0.1.2').
  static String formatSemver(String raw) {
    final parts = parseSemver(raw);
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  /// Verifica si existe una versión superior a la actualmente instalada.
  Future<UpdateInfo> checkForUpdate({SupabaseClient? client}) async {
    String currentVer = '0.1.0';
    try {
      final info = await PackageInfo.fromPlatform();
      currentVer = info.version;
    } catch (e) {
      debugPrint('[AppUpdateService] No se pudo obtener PackageInfo: $e');
    }

    final localSemverClean = formatSemver(currentVer);
    String latestVer = localSemverClean;
    String apkUrl = defaultReleaseUrl;
    String notes =
        'Mejoras de rendimiento, corrección de interfaz y nuevas funcionalidades.';
    bool isMandatory = false;

    try {
      final supabase = client ?? Supabase.instance.client;
      final response = await supabase
          .from('configuracion_general')
          .select('clave, valor')
          .inFilter('clave', [
            'app_version_latest',
            'app_apk_url',
            'app_update_notes',
            'app_update_mandatory',
          ]);

      for (final item in (response as List)) {
        final clave = item['clave'] as String;
        final valor = item['valor'];
        if (clave == 'app_version_latest' && valor != null) {
          latestVer = valor.toString().replaceAll('"', '').trim();
        } else if (clave == 'app_apk_url' && valor != null) {
          apkUrl = valor.toString().replaceAll('"', '').trim();
        } else if (clave == 'app_update_notes' && valor != null) {
          notes = valor.toString().replaceAll('"', '').trim();
        } else if (clave == 'app_update_mandatory' && valor != null) {
          isMandatory =
              valor == true ||
              valor.toString().replaceAll('"', '').trim() == 'true';
        }
      }
      debugPrint(
        '[AppUpdateService] Versión local semver: $localSemverClean | Versión remota: $latestVer | APK: $apkUrl',
      );
    } catch (e) {
      debugPrint(
        '[AppUpdateService] Consulta a configuracion_general omitida o sin red: $e',
      );
    }

    final remoteSemverClean = formatSemver(latestVer);
    final hasUpdate = isVersionGreater(remoteSemverClean, localSemverClean);

    return UpdateInfo(
      hasUpdate: hasUpdate,
      currentVersion: localSemverClean,
      latestVersion: remoteSemverClean,
      apkUrl: apkUrl.isNotEmpty ? apkUrl : defaultReleaseUrl,
      releaseNotes: notes,
      isMandatory: isMandatory,
    );
  }

  /// Compara dos strings semánticos de versión (ej. '0.2.0' vs '0.1.0' o '0.1.3' vs '0.1.2+3').
  /// Devuelve true ÚNICAMENTE si remote es estrictamente superior a current en major, minor o patch.
  /// Ignora sufijos de compilación (+3, +2), tags de pre-release y prefijos 'v'.
  static bool isVersionGreater(String remote, String current) {
    try {
      final rParts = parseSemver(remote);
      final cParts = parseSemver(current);

      for (int i = 0; i < 3; i++) {
        if (rParts[i] > cParts[i]) return true;
        if (rParts[i] < cParts[i]) return false;
      }
      return false; // Son exactamente iguales o local es mayor
    } catch (e) {
      debugPrint('[AppUpdateService] Error al comparar semver: $e');
      return false;
    }
  }

  /// Descarga el APK con Dio al almacenamiento temporal y ejecuta inmediatamente la instalación nativa.
  Future<void> downloadAndInstallApk({
    required String apkUrl,
    required String latestVersion,
    required void Function(double progress, String statusText) onProgress,
  }) async {
    if (kIsWeb || !isAndroidPlatform) {
      onProgress(1.0, 'Abriendo enlace en navegador externo...');
      await launchDownload(apkUrl);
      return;
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 40),
        receiveTimeout: const Duration(minutes: 8),
        followRedirects: true,
      ),
    );

    String? temporaryPath;
    try {
      onProgress(0.05, 'Preparando almacenamiento...');
      final filePath = await getUpdateApkPath(latestVersion);
      temporaryPath = '$filePath.part';

      final targetFile = File(filePath);
      await targetFile.parent.create(recursive: true);
      final temporaryFile = File(temporaryPath);
      if (await temporaryFile.exists()) await temporaryFile.delete();

      onProgress(0.1, 'Descargando paquete de actualización...');

      var receivedBytes = 0;
      var expectedBytes = 0;
      final response = await dio.download(
        apkUrl,
        temporaryPath,
        onReceiveProgress: (received, total) {
          receivedBytes = received;
          expectedBytes = total;
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
            final mbTotal = (total / (1024 * 1024)).toStringAsFixed(1);
            onProgress(
              progress,
              'Descargando: $mbReceived MB / $mbTotal MB (${(progress * 100).toInt()}%)',
            );
          } else {
            final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
            onProgress(0.5, 'Descargando: $mbReceived MB...');
          }
        },
      );

      final contentType = response.headers.value('content-type');
      if (contentType != null &&
          contentType.toLowerCase().contains('text/html')) {
        throw StateError(
          'El servidor entregó una página HTML en lugar del APK (Content-Type: $contentType).',
        );
      }

      final downloadedFile = File(temporaryPath);
      if (!await downloadedFile.exists()) {
        throw StateError(
          'El archivo APK descargado no se guardó en el dispositivo.',
        );
      }
      final fileLength = await downloadedFile.length();
      if (fileLength < 1024 * 1024) {
        throw StateError(
          'El archivo descargado parece incompleto: solo contiene $fileLength bytes.',
        );
      }
      if (expectedBytes > 0 && receivedBytes != expectedBytes) {
        throw StateError(
          'La descarga quedó incompleta: se recibieron $receivedBytes de $expectedBytes bytes.',
        );
      }

      final fileHandle = await downloadedFile.open(mode: FileMode.read);
      late final List<int> signature;
      try {
        signature = await fileHandle.read(4);
      } finally {
        await fileHandle.close();
      }
      if (signature.length != 4 ||
          signature[0] != 0x50 ||
          signature[1] != 0x4b ||
          signature[2] != 0x03 ||
          signature[3] != 0x04) {
        throw StateError(
          'La descarga no es un APK/ZIP válido. Verifica que app_apk_url apunte al archivo APK.',
        );
      }

      if (await targetFile.exists()) await targetFile.delete();
      await downloadedFile.rename(filePath);

      onProgress(
        1.0,
        'Descarga completa. Lanzando instalador nativo de Android...',
      );

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint(
        '[AppUpdateService] Resultado de instalación APK: ${result.type} - ${result.message}',
      );

      if (result.type != ResultType.done) {
        if (result.type == ResultType.permissionDenied) {
          throw Exception(
            'El sistema Android denegó el permiso para instalar aplicaciones desconocidas. '
            'Por favor autoriza a UMBRAL en Ajustes > Instalar aplicaciones desconocidas.',
          );
        } else if (result.type == ResultType.noAppToOpen) {
          throw Exception(
            'No se encontró el instalador de paquetes de Android en el dispositivo.',
          );
        } else if (result.type == ResultType.fileNotFound) {
          throw Exception(
            'No se encontró el archivo del paquete APK en la ruta: $filePath',
          );
        } else {
          throw Exception(
            'Fallo en el instalador nativo (${result.type.name}): ${result.message}',
          );
        }
      }
    } on DioException catch (e) {
      final detail = e.response != null
          ? 'Código HTTP ${e.response?.statusCode}: ${e.response?.statusMessage ?? e.message}'
          : (e.message ?? e.error?.toString() ?? 'Error de conexión');
      debugPrint('[AppUpdateService] Error HTTP/Dio al descargar APK: $detail');
      throw Exception(
        'Fallo en la descarga del paquete de actualización ($detail)',
      );
    } catch (e) {
      debugPrint(
        '[AppUpdateService] Error durante la descarga/instalación: $e',
      );
      rethrow;
    } finally {
      if (temporaryPath != null) {
        final temporaryFile = File(temporaryPath);
        if (await temporaryFile.exists()) {
          try {
            await temporaryFile.delete();
          } on FileSystemException catch (error) {
            debugPrint(
              '[AppUpdateService] No se pudo eliminar el archivo temporal de descarga: $error',
            );
          }
        }
      }
      dio.close(force: true);
    }
  }

  /// Dispara la descarga del APK abriendo el enlace en el navegador o instalador del sistema.
  Future<bool> launchDownload(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[AppUpdateService] Error al lanzar URL de descarga: $e');
      return false;
    }
  }
}
