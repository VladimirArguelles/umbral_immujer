import 'dart:io' show Directory, File, FileMode, IOSink;

import 'package:crypto/crypto.dart';
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
import '../../../../core/services/update_service.dart';
import '../../../../core/widgets/glassmorphic_update_dialog.dart';

/// Información de la versión de la app y actualización disponible.
class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final int? currentBuildNumber;
  final int? latestBuildNumber;
  final String apkUrl;
  final String? apkSha256;
  final String releaseNotes;
  final bool isMandatory;

  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    this.currentBuildNumber,
    this.latestBuildNumber,
    required this.apkUrl,
    this.apkSha256,
    required this.releaseNotes,
    this.isMandatory = false,
  });

  String get currentDisplayVersion => currentBuildNumber != null
      ? '$currentVersion+$currentBuildNumber'
      : currentVersion;

  String get latestDisplayVersion => latestBuildNumber != null
      ? '$latestVersion+$latestBuildNumber'
      : latestVersion;
}

/// Servicio que gestiona la detección de nuevas versiones y actualización In-App del APK.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String defaultReleaseUrl =
      'https://github.com/VladimirArguelles/umbral_immujer/releases/latest';

  static bool _hasCheckedUpdate = false;
  static bool _isUpdateDialogDismissed = false;
  static bool _isCheckingThisSession = false;

  bool get hasCheckedUpdate => _hasCheckedUpdate;
  bool get isUpdateDialogDismissed => _isUpdateDialogDismissed;

  /// Marca que el usuario pospuso o cerró el diálogo de actualización en esta sesión.
  void markUpdateDialogDismissed() {
    _isUpdateDialogDismissed = true;
  }

  /// Restablece las banderas de verificación de actualización para nueva sesión (ej. tras logout).
  static void resetSessionCheck() {
    _hasCheckedUpdate = false;
    _isUpdateDialogDismissed = false;
    _isCheckingThisSession = false;
  }

  /// Verifica si hay una actualización disponible y muestra el diálogo modal.
  /// Prioridad 1: Supabase configuracion_general (fuente de verdad oficial del backend).
  /// Prioridad 2: Fallback a GitHub Releases si Supabase está offline o no detecta release.
  Future<bool> checkAndShowUpdateModal(
    BuildContext context, {
    bool force = false,
  }) async {
    if (!force && (_hasCheckedUpdate || _isUpdateDialogDismissed)) {
      return false;
    }
    if (_isCheckingThisSession) {
      return false;
    }

    if (!context.mounted) return false;
    if (!force && !_isActiveRootDashboard(context)) return false;

    if (!force) {
      _hasCheckedUpdate = true;
    }
    _isCheckingThisSession = true;

    try {
      // 1. Verificación primaria en Supabase `configuracion_general`
      final info = await checkForUpdate();
      if (!context.mounted) return false;
      if (!force && _isUpdateDialogDismissed) return false;

      if (info.hasUpdate) {
        if (!context.mounted) return true;
        await AppUpdateDialog.show(context, info);
        return true;
      }

      // 2. Fallback secundario a GitHub Releases si Supabase no reportó versión superior
      try {
        final releaseInfo = await UpdateService.instance.checkForUpdate();
        if (releaseInfo.hasUpdate && context.mounted && (force || !_isUpdateDialogDismissed)) {
          await GlassmorphicUpdateDialog.show(context, releaseInfo);
          return true;
        }
      } catch (e) {
        debugPrint('[AppUpdateService] Fallback de GitHub Releases omitido: $e');
      }
    } catch (e) {
      debugPrint(
        '[AppUpdateService] Error al verificar actualización: $e',
      );
    } finally {
      _isCheckingThisSession = false;
    }
    return false;
  }

  bool _isActiveRootDashboard(BuildContext context) {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }

    try {
      final rawLocation = GoRouterState.of(context).matchedLocation.trim();
      final location = (rawLocation.length > 1 && rawLocation.endsWith('/'))
          ? rawLocation.substring(0, rawLocation.length - 1)
          : rawLocation;

      const rootDashboards = {
        '/',
        '/login',
        '/student',
        '/teacher',
        '/coordinator',
        '/superadmin',
        '/inscripciones',
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
    if (kIsWeb) {
      throw UnsupportedError(
        'No se pueden descargar archivos APK en entorno Web.',
      );
    }

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
    final basePath = (baseDir.path.endsWith('/') || baseDir.path.endsWith('\\'))
        ? baseDir.path.substring(0, baseDir.path.length - 1)
        : baseDir.path;
    return '$basePath/umbral_update_$safeVersion.apk';
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

  /// Extrae el número de compilación entero (`buildNumber` / `versionCode`).
  /// Prioriza [explicitBuildNumber] (ej. `PackageInfo.buildNumber` o la clave
  /// `app_build_number` de Supabase) y, si no está disponible, busca el sufijo
  /// `+<numero>` en [rawVersion] (ej. `'0.1.3+4'` -> `4`, `'0.1+3'` -> `3`).
  static int? parseBuildNumber(
    String rawVersion, {
    dynamic explicitBuildNumber,
  }) {
    if (explicitBuildNumber != null) {
      if (explicitBuildNumber is int) {
        return explicitBuildNumber > 0 ? explicitBuildNumber : null;
      }
      if (explicitBuildNumber is num) {
        final intVal = explicitBuildNumber.toInt();
        return intVal > 0 ? intVal : null;
      }
      final cleanedExplicit = explicitBuildNumber
          .toString()
          .replaceAll('"', '')
          .replaceAll("'", '')
          .trim();
      final parsedExplicit = int.tryParse(cleanedExplicit);
      if (parsedExplicit != null && parsedExplicit > 0) {
        return parsedExplicit;
      }
    }

    final cleanVersion =
        rawVersion.trim().replaceAll('"', '').replaceAll("'", '');
    if (!cleanVersion.contains('+')) return null;

    final buildSegment = cleanVersion.split('+').last.trim();
    final digits = RegExp(r'\d+').firstMatch(buildSegment)?.group(0);
    if (digits == null) return null;
    final parsed = int.tryParse(digits);
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  /// Verifica si existe una versión superior a la actualmente instalada.
  Future<UpdateInfo> checkForUpdate({SupabaseClient? client}) async {
    String currentVerRaw = '0.1.0';
    String currentBuildRaw = '';
    try {
      final info = await PackageInfo.fromPlatform();
      currentVerRaw = info.version;
      currentBuildRaw = info.buildNumber;
    } catch (e) {
      debugPrint('[AppUpdateService] No se pudo obtener PackageInfo: $e');
    }

    final localSemverClean = formatSemver(currentVerRaw);
    final localBuildNumber = parseBuildNumber(
      currentVerRaw,
      explicitBuildNumber: currentBuildRaw,
    );
    String latestVerRaw = localSemverClean;
    int? remoteBuildNumber;
    String apkUrl = defaultReleaseUrl;
    String? remoteSha256;
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
            'app_build_number',
            'app_apk_url',
            'app_apk_sha256',
            'app_update_notes',
            'app_update_mandatory',
          ]);

      for (final item in response) {
        final clave = item['clave']?.toString();
        final valor = item['valor'];
        if (clave == 'app_version_latest' && valor != null) {
          latestVerRaw = valor.toString().replaceAll('"', '').trim();
        } else if (clave == 'app_build_number' && valor != null) {
          remoteBuildNumber = parseBuildNumber(
            '',
            explicitBuildNumber: valor,
          );
        } else if (clave == 'app_apk_url' && valor != null) {
          apkUrl = valor.toString().replaceAll('"', '').trim();
        } else if (clave == 'app_apk_sha256' && valor != null) {
          remoteSha256 = valor.toString().replaceAll('"', '').trim();
        } else if (clave == 'app_update_notes' && valor != null) {
          notes = valor.toString().replaceAll('"', '').trim();
        } else if (clave == 'app_update_mandatory' && valor != null) {
          isMandatory =
              valor == true ||
              valor.toString().replaceAll('"', '').trim().toLowerCase() ==
                  'true';
        }
      }
      remoteBuildNumber ??= parseBuildNumber(latestVerRaw);
      debugPrint(
        '[AppUpdateService] Local: $localSemverClean (build: $localBuildNumber) | Remota: $latestVerRaw (build: $remoteBuildNumber) | APK: $apkUrl',
      );
    } catch (e) {
      debugPrint(
        '[AppUpdateService] Consulta a configuracion_general omitida o sin red: $e',
      );
    }

    final remoteSemverClean = formatSemver(latestVerRaw);
    final hasUpdate = isUpdateAvailable(
      remoteVersion: latestVerRaw,
      currentVersion: currentVerRaw,
      remoteBuildNumber: remoteBuildNumber,
      currentBuildNumber: localBuildNumber,
    );

    return UpdateInfo(
      hasUpdate: hasUpdate,
      currentVersion: localSemverClean,
      latestVersion: remoteSemverClean,
      currentBuildNumber: localBuildNumber,
      latestBuildNumber: remoteBuildNumber,
      apkUrl: apkUrl.isNotEmpty ? apkUrl : defaultReleaseUrl,
      apkSha256: remoteSha256,
      releaseNotes: notes,
      isMandatory: isMandatory,
    );
  }

  /// Evalúa si existe una actualización disponible evitando falsos positivos.
  ///
  /// 1. Si se dispone tanto del `build_number` remoto como del local (> 0),
  ///    compara numéricamente sus enteros (`remoteBuildNumber > currentBuildNumber`).
  /// 2. Si el servidor no especifica `build_number`, normaliza ambos strings
  ///    eliminando prefijos `'v'` y sufijos `'+'`/`'-'`, y compara Semver (`major.minor.patch`).
  static bool isUpdateAvailable({
    required String remoteVersion,
    required String currentVersion,
    int? remoteBuildNumber,
    int? currentBuildNumber,
  }) {
    final resolvedRemoteBuild =
        remoteBuildNumber ?? parseBuildNumber(remoteVersion);
    final resolvedCurrentBuild =
        currentBuildNumber ?? parseBuildNumber(currentVersion);

    if (resolvedRemoteBuild != null &&
        resolvedCurrentBuild != null &&
        resolvedRemoteBuild > 0 &&
        resolvedCurrentBuild > 0) {
      return resolvedRemoteBuild > resolvedCurrentBuild;
    }

    return isVersionGreater(remoteVersion, currentVersion);
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

  /// Sanitiza cualquier mensaje de error técnico para presentar información limpia al usuario.
  static String sanitizeErrorMessage(dynamic error) {
    final str = error.toString();
    if (str.contains('HttpConnection closed') ||
        str.contains('Connection closed') ||
        str.contains('SocketException') ||
        str.contains('connection abort') ||
        str.contains('Broken pipe') ||
        str.contains('Connection reset') ||
        str.contains('HandshakeException') ||
        str.contains('connectionTimeout') ||
        str.contains('receiveTimeout')) {
      return 'La descarga se interrumpió por inestabilidad en la conexión de red. Puedes reintentar la descarga o usar el enlace directo al navegador.';
    }
    if (str.contains('404')) {
      return 'El paquete de actualización no se encuentra disponible temporalmente en el servidor.';
    }
    if (str.contains('Fallo de integridad criptográfica')) {
      return 'La verificación de seguridad SHA-256 del paquete no coincidió. Se canceló la instalación por seguridad.';
    }
    if (str.contains('permissionDenied')) {
      return 'Android denegó el permiso para instalar aplicaciones desconocidas. Autoriza a UMBRAL en Ajustes de Android.';
    }
    var clean = str
        .replaceAll('Exception: ', '')
        .replaceAll('StateError: ', '')
        .trim();
    clean = clean.replaceAll(RegExp(r'https?://[^\s,\)]+'), '[servidor]');
    return clean.isNotEmpty
        ? clean
        : 'Error de conexión al descargar la actualización.';
  }

  /// Descarga el APK con Dio de forma reanudable (HTTP Range) con reintentos automáticos
  /// al almacenamiento local y ejecuta inmediatamente la instalación nativa.
  Future<void> downloadAndInstallApk({
    required String apkUrl,
    required String latestVersion,
    String? expectedSha256,
    required void Function(double progress, String statusText) onProgress,
  }) async {
    if (kIsWeb || !isAndroidPlatform) {
      onProgress(1.0, 'Abriendo enlace en navegador externo...');
      await launchDownload(apkUrl);
      return;
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(seconds: 45),
        followRedirects: true,
        maxRedirects: 10,
        headers: {
          'User-Agent': 'UmbralImmujer/1.0 (Android; OTA)',
          'Accept':
              'application/vnd.android.package-archive, application/octet-stream, */*',
        },
      ),
    );

    String? temporaryPath;
    bool installLaunched = false;

    try {
      onProgress(0.05, 'Preparando almacenamiento...');
      final filePath = await getUpdateApkPath(latestVersion);
      temporaryPath = '$filePath.part';

      final targetFile = File(filePath);
      await targetFile.parent.create(recursive: true);

      // Limpiar versiones anteriores huérfanas de umbral_update_*.apk
      await _cleanupOldApks(targetFile.parent, filePath);

      final temporaryFile = File(temporaryPath);

      // Determinar URLs candidatas: Primaria + Fallback automático si aplica
      final List<String> candidateUrls = [apkUrl];
      const fallbackGitHub =
          'https://github.com/VladimirArguelles/umbral_immujer/releases/download/latest/app-release.apk';
      const fallbackSupabase =
          'https://kkgacvhbcxgoxjpnkxmw.supabase.co/storage/v1/object/public/app-updates/app-release.apk';

      if (apkUrl.contains('github.com') ||
          apkUrl.contains('githubusercontent.com')) {
        if (!candidateUrls.contains(fallbackSupabase)) {
          candidateUrls.add(fallbackSupabase);
        }
      } else {
        if (!candidateUrls.contains(fallbackGitHub)) {
          candidateUrls.add(fallbackGitHub);
        }
      }

      bool downloadSuccess = false;
      dynamic lastDownloadError;

      for (int urlIdx = 0; urlIdx < candidateUrls.length && !downloadSuccess; urlIdx++) {
        final currentUrl = candidateUrls[urlIdx];
        const int maxRetriesPerUrl = 5;

        for (int attempt = 1; attempt <= maxRetriesPerUrl; attempt++) {
          IOSink? sink;
          try {
            int existingBytes = await temporaryFile.exists()
                ? await temporaryFile.length()
                : 0;

            final Map<String, String> requestHeaders = {
              'User-Agent': 'UmbralImmujer/1.0 (Android; OTA)',
              'Accept':
                  'application/vnd.android.package-archive, application/octet-stream, */*',
            };

            if (existingBytes > 0) {
              requestHeaders['Range'] = 'bytes=$existingBytes-';
            }

            final response = await dio.get<ResponseBody>(
              currentUrl,
              options: Options(
                responseType: ResponseType.stream,
                headers: requestHeaders,
                validateStatus: (status) =>
                    status != null && (status >= 200 && status < 300),
              ),
            );

            final statusCode = response.statusCode ?? 200;
            final contentType =
                response.headers.value('content-type')?.toLowerCase() ?? '';
            if (contentType.contains('text/html')) {
              throw StateError(
                'El servidor entregó una página HTML en lugar del APK ($contentType).',
              );
            }

            int totalBytes = 0;
            if (statusCode == 206) {
              final contentRange = response.headers.value('content-range');
              if (contentRange != null && contentRange.contains('/')) {
                totalBytes =
                    int.tryParse(contentRange.split('/').last.trim()) ?? 0;
              }
              if (totalBytes <= 0) {
                final chunkLen = int.tryParse(
                        response.headers.value('content-length') ?? '0') ??
                    0;
                totalBytes = existingBytes + chunkLen;
              }
              sink = temporaryFile.openWrite(mode: FileMode.append);
            } else {
              existingBytes = 0;
              totalBytes = int.tryParse(
                      response.headers.value('content-length') ?? '0') ??
                  0;
              sink = temporaryFile.openWrite(mode: FileMode.write);
            }

            int receivedBytes = existingBytes;
            final stream = response.data?.stream;
            if (stream == null) {
              throw StateError('El servidor no entregó un flujo de datos.');
            }

            await for (final chunk in stream) {
              sink.add(chunk);
              receivedBytes += chunk.length;
              if (totalBytes > 0) {
                final progress =
                    (receivedBytes / totalBytes).clamp(0.05, 0.95);
                final mbReceived =
                    (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
                final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
                onProgress(
                  progress,
                  'Descargando: $mbReceived MB / $mbTotal MB (${(progress * 100).toInt()}%)',
                );
              } else {
                final mbReceived =
                    (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
                onProgress(0.5, 'Descargando: $mbReceived MB...');
              }
            }

            await sink.flush();
            await sink.close();
            sink = null;

            final finalLength = await temporaryFile.length();
            if (totalBytes > 0 && finalLength < totalBytes) {
              throw StateError(
                'Descarga incompleta: $finalLength de $totalBytes bytes.',
              );
            }

            downloadSuccess = true;
            break;
          } catch (e) {
            try {
              await sink?.flush();
              await sink?.close();
            } catch (_) {}
            sink = null;
            lastDownloadError = e;

            debugPrint(
              '[AppUpdateService] Intento $attempt/$maxRetriesPerUrl falló con URL ($currentUrl): $e',
            );

            if (attempt < maxRetriesPerUrl) {
              final backoffSec = attempt * 2;
              final savedMb = await temporaryFile.exists()
                  ? (await temporaryFile.length() / (1024 * 1024))
                      .toStringAsFixed(1)
                  : '0.0';
              onProgress(
                0.5,
                'Conexión inestable ($savedMb MB guardados). Reanudando en ${backoffSec}s (intento $attempt de $maxRetriesPerUrl)...',
              );
              await Future.delayed(Duration(seconds: backoffSec));
            }
          }
        }
      }

      if (!downloadSuccess) {
        throw Exception(sanitizeErrorMessage(lastDownloadError));
      }

      if (!await temporaryFile.exists()) {
        throw StateError(
          'El archivo APK descargado no se guardó en el dispositivo.',
        );
      }
      final fileLength = await temporaryFile.length();
      if (fileLength < 5 * 1024 * 1024) {
        throw StateError(
          'El archivo descargado está incompleto ($fileLength bytes).',
        );
      }

      final fileHandle = await temporaryFile.open(mode: FileMode.read);
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
        if (await temporaryFile.exists()) await temporaryFile.delete();
        throw StateError(
          'La descarga no es un APK/ZIP válido. Verifica que app_apk_url apunte al archivo APK.',
        );
      }

      // Verificación de integridad criptográfica SHA-256
      if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
        onProgress(0.96, 'Verificando firma de integridad SHA-256...');
        final digest = await sha256.bind(temporaryFile.openRead()).first;
        final actualHash = digest.toString().toLowerCase();
        final cleanExpected = expectedSha256.trim().toLowerCase();

        if (actualHash != cleanExpected) {
          if (await temporaryFile.exists()) await temporaryFile.delete();
          throw StateError(
            'Fallo de integridad criptográfica: El hash SHA-256 del APK ($actualHash) no coincide con el registrado en el servidor ($cleanExpected). La instalación ha sido cancelada por seguridad.',
          );
        }
        debugPrint(
          '[AppUpdateService] Verificación SHA-256 completada con éxito: $actualHash',
        );
      }

      if (await targetFile.exists()) await targetFile.delete();
      try {
        await temporaryFile.rename(filePath);
      } catch (renameErr) {
        debugPrint(
          '[AppUpdateService] rename atómico no soportado ($renameErr), usando copy + delete...',
        );
        await temporaryFile.copy(filePath);
        await temporaryFile.delete();
      }

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
      installLaunched = true;

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
    } catch (e) {
      debugPrint(
        '[AppUpdateService] Error durante la descarga/instalación: $e',
      );
      rethrow;
    } finally {
      dio.close(force: true);
      if (installLaunched && temporaryPath != null) {
        final temporaryFile = File(temporaryPath);
        if (await temporaryFile.exists()) {
          try {
            await temporaryFile.delete();
          } catch (_) {}
        }
      }
    }
  }

  /// Limpia archivos APK temporales o versiones previas que ya no se necesitan.
  Future<void> _cleanupOldApks(Directory dir, String currentTargetFilePath) async {
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : entity.path;
          if (fileName.startsWith('umbral_update_') &&
              entity.path != currentTargetFilePath) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] No se pudieron limpiar APKs antiguos: $e');
    }
  }

  /// Dispara la descarga del APK abriendo el enlace en el navegador o instalador del sistema.
  Future<bool> launchDownload(String url) async {
    var cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final uri = Uri.tryParse(cleanUrl);
    if (uri == null) return false;

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[AppUpdateService] Error al lanzar URL de descarga: $e');
      return false;
    }
  }
}
