import 'dart:io' show File, Directory;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  String? _lastDownloadedApkPath;
  static bool _hasPromptedThisSession = false;

  /// Restablece la bandera de verificación de actualización para nueva sesión (ej. tras logout).
  static void resetSessionCheck() {
    _hasPromptedThisSession = false;
  }

  /// Verifica si hay una actualización disponible y muestra el diálogo modal únicamente
  /// si no se ha consultado previamente en esta sesión de usuario en el Dashboard principal.
  Future<void> checkAndShowUpdateModal(BuildContext context, {bool force = false}) async {
    if (!force && _hasPromptedThisSession) {
      return;
    }
    _hasPromptedThisSession = true;

    try {
      final info = await checkForUpdate();
      if (info.hasUpdate && context.mounted) {
        AppUpdateDialog.show(context, info);
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error al verificar actualización en dashboard: $e');
    }
  }

  bool get isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get hasDownloadedApk =>
      _lastDownloadedApkPath != null && File(_lastDownloadedApkPath!).existsSync();

  Future<OpenResult> openDownloadedApk() async {
    if (hasDownloadedApk) {
      return await OpenFilex.open(
        _lastDownloadedApkPath!,
        type: 'application/vnd.android.package-archive',
      );
    }
    return OpenResult(type: ResultType.fileNotFound, message: 'Archivo APK no encontrado');
  }

  /// Extrae los dígitos semánticos principales (major, minor, patch) ignorando prefijos
  /// 'v' y sufijos de compilación (+X). Normaliza tanto 'v0.1.2' como '0.1+2' a lista [0, 1, 2].
  static List<int> parseSemver(String raw) {
    var clean = raw.trim();
    if (clean.toLowerCase().startsWith('v')) {
      clean = clean.substring(1).trim();
    }
    // Descartar metadatos de compilación (+X)
    if (clean.contains('+')) {
      clean = clean.split('+').first.trim();
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
    return nums;
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
          isMandatory = valor == true || valor.toString().replaceAll('"', '').trim() == 'true';
        }
      }
      debugPrint('[AppUpdateService] Versión local semver: $localSemverClean | Versión remota: $latestVer | APK: $apkUrl');
    } catch (e) {
      debugPrint('[AppUpdateService] Consulta a configuracion_general omitida o sin red: $e');
    }

    final remoteSemverClean = formatSemver(latestVer);
    final hasUpdate = _isVersionGreater(latestVer, localSemverClean);

    return UpdateInfo(
      hasUpdate: hasUpdate,
      currentVersion: localSemverClean,
      latestVersion: remoteSemverClean,
      apkUrl: apkUrl.isNotEmpty ? apkUrl : defaultReleaseUrl,
      releaseNotes: notes,
      isMandatory: isMandatory,
    );
  }

  /// Compara dos strings semánticos de versión (ej. '0.2.0' vs '0.1.0').
  /// Devuelve true ÚNICAMENTE si remote es estrictamente superior a current.
  bool _isVersionGreater(String remote, String current) {
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
      onProgress(0.05, 'Preparando almacenamiento...');
      Directory? baseDir;
      try {
        final extCache = await getExternalCacheDirectories();
        if (extCache != null && extCache.isNotEmpty) {
          baseDir = extCache.first;
        }
      } catch (_) {}
      try {
        baseDir ??= await getExternalStorageDirectory();
      } catch (_) {}
      baseDir ??= await getTemporaryDirectory();

      final filePath = '${baseDir.path}/umbral_latest_update.apk';
      _lastDownloadedApkPath = filePath;

      // Limpiar archivo previo si existía y asegurar directorio
      final targetFile = File(filePath);
      if (!targetFile.parent.existsSync()) {
        try {
          targetFile.parent.createSync(recursive: true);
        } catch (_) {}
      }
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

      final downloadedFile = File(filePath);
      if (!await downloadedFile.exists() || await downloadedFile.length() == 0) {
        throw Exception('El archivo APK descargado no se pudo guardar correctamente en el dispositivo.');
      }

      onProgress(1.0, 'Descarga completa. Lanzando instalador nativo de Android...');

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('[AppUpdateService] Resultado de instalación APK: ${result.type} - ${result.message}');

      if (result.type != ResultType.done) {
        if (result.type == ResultType.permissionDenied) {
          throw Exception(
            'El sistema Android denegó el permiso para instalar aplicaciones desconocidas. '
            'Por favor autoriza a UMBRAL en Ajustes > Instalar aplicaciones desconocidas.',
          );
        } else if (result.type == ResultType.noAppToOpen) {
          throw Exception('No se encontró el instalador de paquetes de Android.');
        } else {
          throw Exception('No se pudo ejecutar el instalador (${result.message}).');
        }
      }
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
