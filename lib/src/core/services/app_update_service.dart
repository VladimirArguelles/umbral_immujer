import 'dart:io' show File;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  bool get isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Verifica si existe una versión superior a la actualmente instalada.
  Future<UpdateInfo> checkForUpdate({SupabaseClient? client}) async {
    String currentVer = '0.1.0';
    String buildNumber = '';
    try {
      final info = await PackageInfo.fromPlatform();
      currentVer = info.version;
      buildNumber = info.buildNumber;
    } catch (e) {
      debugPrint('[AppUpdateService] No se pudo obtener PackageInfo: $e');
    }

    final localVersionFull =
        buildNumber.isNotEmpty ? '$currentVer+$buildNumber' : currentVer;

    String latestVer = localVersionFull;
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
          latestVer = valor.toString().trim();
        } else if (clave == 'app_apk_url' && valor != null) {
          apkUrl = valor.toString().trim();
        } else if (clave == 'app_update_notes' && valor != null) {
          notes = valor.toString().trim();
        } else if (clave == 'app_update_mandatory' && valor != null) {
          isMandatory = valor == true || valor.toString() == 'true';
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Consulta a configuracion_general omitida o sin red: $e');
    }

    final hasUpdate = _isVersionGreater(latestVer, localVersionFull);

    return UpdateInfo(
      hasUpdate: hasUpdate,
      currentVersion: localVersionFull,
      latestVersion: latestVer,
      apkUrl: apkUrl.isNotEmpty ? apkUrl : defaultReleaseUrl,
      releaseNotes: notes,
      isMandatory: isMandatory,
    );
  }

  /// Compara dos strings semánticos de versión (ej. '0.2.0' vs '0.1.0' o con build '0.1.1+3' vs '0.1.1+2').
  bool _isVersionGreater(String remote, String current) {
    try {
      final remoteClean = remote.trim();
      final currentClean = current.trim();
      if (remoteClean.isEmpty || remoteClean == currentClean) return false;

      final rSplit = remoteClean.split('+');
      final cSplit = currentClean.split('+');

      final rParts = rSplit.first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final cParts = cSplit.first.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }

      // Si los dígitos mayores.menores.parche coinciden, comparar número de compilación
      if (rSplit.length > 1 && cSplit.length > 1) {
        final rBuild = int.tryParse(rSplit[1]) ?? 0;
        final cBuild = int.tryParse(cSplit[1]) ?? 0;
        if (rBuild > cBuild) return true;
      } else if (rSplit.length > 1 && cSplit.length == 1) {
        final rBuild = int.tryParse(rSplit[1]) ?? 0;
        if (rBuild > 0) return true;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error al comparar semver: $e');
    }
    return false;
  }

  /// Descarga el APK con Dio al almacenamiento temporal y ejecuta la instalación nativa.
  Future<void> downloadAndInstallApk({
    required String apkUrl,
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

    try {
      onProgress(0.05, 'Preparando directorio temporal...');
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/umbral_latest_update.apk';

      // Limpiar archivo previo si existía
      final targetFile = File(filePath);
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }

      onProgress(0.1, 'Descargando paquete de actualización...');

      await dio.download(
        apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
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

      onProgress(1.0, 'Descarga completa. Iniciando instalador de paquete...');

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('[AppUpdateService] Resultado de instalación APK: ${result.type} - ${result.message}');
    } catch (e) {
      debugPrint('[AppUpdateService] Error durante la descarga/instalación: $e');
      rethrow;
    }
  }

  /// Dispara la descarga del APK abriendo el enlace en el navegador o instalador del sistema.
  Future<bool> launchDownload(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Error al lanzar URL de descarga: $e');
      return false;
    }
  }
}
