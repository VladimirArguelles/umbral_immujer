import 'dart:io' show Directory, File, FileMode, FileSystemException;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/remote_config_service.dart';
import '../widgets/glassmorphic_update_dialog.dart';

/// Modelo de datos que encapsula el estado de la versión y el release de GitHub.
class GitHubReleaseInfo {
  final bool hasUpdate;
  final String localVersion;
  final int? localBuildNumber;
  final String remoteVersion;
  final int? remoteBuildNumber;
  final String tagName;
  final String releaseTitle;
  final String releaseNotes;
  final String apkDownloadUrl;
  final String apkFileName;
  final int apkFileSize;
  final String htmlUrl;
  final bool isMandatory;
  final String? assetUpdatedAt;
  final String? publishedAt;

  const GitHubReleaseInfo({
    required this.hasUpdate,
    required this.localVersion,
    this.localBuildNumber,
    required this.remoteVersion,
    this.remoteBuildNumber,
    required this.tagName,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.apkFileName,
    this.apkFileSize = 0,
    required this.htmlUrl,
    this.isMandatory = false,
    this.assetUpdatedAt,
    this.publishedAt,
  });

  String get localDisplayVersion => localBuildNumber != null
      ? '$localVersion+$localBuildNumber'
      : localVersion;

  String get remoteDisplayVersion => remoteBuildNumber != null
      ? '$remoteVersion+$remoteBuildNumber'
      : remoteVersion;
}

/// Servicio que gestiona la verificación y actualización In-App / OTA
/// mediante el endpoint público de GitHub Releases.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String defaultOwner = 'VladimirArguelles';
  static const String defaultRepo = 'umbral_immujer';

  static bool _hasCheckedThisSession = false;
  static bool _isDialogDismissed = false;
  static bool _isCheckingNow = false;

  bool get hasCheckedThisSession => _hasCheckedThisSession;
  bool get isDialogDismissed => _isDialogDismissed;

  /// Marca que el usuario pospuso o cerró el diálogo de actualización en esta sesión
  void markDialogDismissed() {
    _isDialogDismissed = true;
  }

  /// Restablece la sesión para nuevas verificaciones (ej. logout o cambio de usuario)
  static void resetSession() {
    _hasCheckedThisSession = false;
    _isDialogDismissed = false;
    _isCheckingNow = false;
  }

  /// Verifica si la plataforma actual es Android nativo
  bool get isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Obtiene la ruta del archivo APK descargado localmente
  Future<String> getApkDestinationPath(String version) async {
    if (kIsWeb) {
      throw UnsupportedError('No se pueden descargar archivos APK en entorno Web.');
    }

    final Directory baseDir;
    if (isAndroidPlatform) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw StateError('Android no proporcionó un directorio de almacenamiento externo.');
      }
      baseDir = externalDir;
    } else {
      baseDir = await getApplicationSupportDirectory();
    }

    final safeVersion = formatSemver(version).replaceAll('.', '_');
    final basePath = (baseDir.path.endsWith('/') || baseDir.path.endsWith('\\'))
        ? baseDir.path.substring(0, baseDir.path.length - 1)
        : baseDir.path;

    return '$basePath/umbral_release_$safeVersion.apk';
  }

  // ===========================================================================
  // PARSING Y COMPARACIÓN DE VERSIONES SEMVER
  // ===========================================================================

  /// Extrae y normaliza la versión semántica principal [major, minor, patch]
  static List<int> parseSemver(String raw) {
    var clean = raw.trim().replaceAll('"', '').replaceAll("'", '');
    if (clean.toLowerCase().startsWith('v')) {
      clean = clean.substring(1).trim();
    }
    if (clean.contains('+')) {
      clean = clean.split('+').first.trim();
    }
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

  static String formatSemver(String raw) {
    final parts = parseSemver(raw);
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  /// Extrae el número de compilación entero (buildNumber / versionCode)
  static int? parseBuildNumber(String rawVersion, {dynamic explicitBuild}) {
    if (explicitBuild != null) {
      if (explicitBuild is int && explicitBuild > 0) return explicitBuild;
      if (explicitBuild is num && explicitBuild > 0) return explicitBuild.toInt();
      final cleaned = explicitBuild.toString().replaceAll('"', '').trim();
      final parsed = int.tryParse(cleaned);
      if (parsed != null && parsed > 0) return parsed;
    }

    final cleanVersion = rawVersion.trim().replaceAll('"', '').trim();
    if (!cleanVersion.contains('+')) return null;

    final buildSegment = cleanVersion.split('+').last.trim();
    final digits = RegExp(r'\d+').firstMatch(buildSegment)?.group(0);
    if (digits == null) return null;
    final parsed = int.tryParse(digits);
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  /// Determina si una versión semántica es estrictamente mayor que otra
  static bool isVersionGreater(String remote, String current) {
    try {
      final rParts = parseSemver(remote);
      final cParts = parseSemver(current);

      for (int i = 0; i < 3; i++) {
        if (rParts[i] > cParts[i]) return true;
        if (rParts[i] < cParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Evalúa si hay una actualización disponible comparando versión y build number
  static bool isUpdateAvailable({
    required String remoteVersion,
    required String currentVersion,
    int? remoteBuildNumber,
    int? currentBuildNumber,
  }) {
    final resRemoteBuild = remoteBuildNumber ?? parseBuildNumber(remoteVersion);
    final resCurrentBuild = currentBuildNumber ?? parseBuildNumber(currentVersion);

    if (resRemoteBuild != null && resCurrentBuild != null && resRemoteBuild > 0 && resCurrentBuild > 0) {
      if (resRemoteBuild > resCurrentBuild) return true;
      if (resRemoteBuild < resCurrentBuild) return false;
    }

    return isVersionGreater(remoteVersion, currentVersion);
  }

  // ===========================================================================
  // CONSULTA HTTP AL ENDPOINT PÚBLICO DE GITHUB RELEASES
  // ===========================================================================

  /// Realiza la consulta HTTP a GitHub Releases y compara con la versión instalada
  Future<GitHubReleaseInfo> checkForUpdate({
    String? owner,
    String? repo,
  }) async {
    // 1. Obtener información de la versión local mediante package_info_plus
    String localVersionRaw = '0.1.0';
    String localBuildRaw = '';
    try {
      final info = await PackageInfo.fromPlatform();
      localVersionRaw = info.version;
      localBuildRaw = info.buildNumber;
    } catch (e) {
      debugPrint('[UpdateService] Advertencia al obtener PackageInfo local: $e');
    }

    final localSemver = formatSemver(localVersionRaw);
    final localBuildNumber = parseBuildNumber(
      localVersionRaw,
      explicitBuild: localBuildRaw,
    );

    // 2. Determinar el repositorio de destino (con fallback a RemoteConfig)
    final resolvedOwner = owner ??
        RemoteConfigService.instance.getRemoteString('github_repo_owner', defaultOwner);
    final resolvedRepo = repo ??
        RemoteConfigService.instance.getRemoteString('github_repo_name', defaultRepo);

    final url = 'https://api.github.com/repos/$resolvedOwner/$resolvedRepo/releases/latest';

    String tagName = '';
    String releaseTitle = '';
    String releaseNotes = '';
    String apkDownloadUrl = '';
    String apkFileName = 'app-release.apk';
    int apkFileSize = 0;
    String htmlUrl = 'https://github.com/$resolvedOwner/$resolvedRepo/releases/latest';
    String remoteVersionRaw = localSemver;
    int? remoteBuildNumber;
    String? assetUpdatedAt;
    String? publishedAt;

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Umbral-Immujer-App',
        },
      ),
    );

    try {
      final response = await dio.get<Map<String, dynamic>>(url);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        tagName = data['tag_name']?.toString() ?? '';
        releaseTitle = data['name']?.toString() ?? tagName;
        releaseNotes = data['body']?.toString() ?? 'Mejoras y correcciones generales.';
        htmlUrl = data['html_url']?.toString() ?? htmlUrl;
        publishedAt = data['published_at']?.toString();

        // Buscar el asset APK dentro de la lista de assets de GitHub
        final assets = data['assets'];
        if (assets is List && assets.isNotEmpty) {
          for (final asset in assets) {
            if (asset is Map) {
              final name = asset['name']?.toString() ?? '';
              if (name.toLowerCase().endsWith('.apk')) {
                apkFileName = name;
                apkDownloadUrl = asset['browser_download_url']?.toString() ?? '';
                final sizeVal = asset['size'];
                if (sizeVal is num) {
                  apkFileSize = sizeVal.toInt();
                }
                assetUpdatedAt = asset['updated_at']?.toString() ?? publishedAt;
                break;
              }
            }
          }
        }

        // Si no se encontró un asset directo, construir la URL canónica esperada
        if (apkDownloadUrl.isEmpty) {
          apkDownloadUrl = 'https://github.com/$resolvedOwner/$resolvedRepo/releases/download/$tagName/app-release.apk';
        }

        // Extraer la versión semántica remota a partir de tagName o releaseTitle
        if (tagName.toLowerCase().startsWith('latest')) {
          // Si el tag es 'latest' o 'latest-build', intentar extraer versión del título o notas
          final titleDigits = RegExp(r'\d+\.\d+(\.\d+)?').firstMatch(releaseTitle)?.group(0);
          final notesDigits = RegExp(r'\d+\.\d+(\.\d+)?').firstMatch(releaseNotes)?.group(0);
          remoteVersionRaw = titleDigits ?? notesDigits ?? localSemver;
          remoteBuildNumber = parseBuildNumber(releaseTitle) ?? parseBuildNumber(releaseNotes);
        } else {
          remoteVersionRaw = formatSemver(tagName);
          remoteBuildNumber = parseBuildNumber(tagName);
        }
      }
    } on DioException catch (dioErr) {
      debugPrint('[UpdateService] Error al consultar GitHub Releases: ${dioErr.message}');
    } catch (e) {
      debugPrint('[UpdateService] Error inesperado en consulta de release: $e');
    } finally {
      dio.close();
    }

    final remoteSemver = formatSemver(remoteVersionRaw);
    final semverUpdate = isUpdateAvailable(
      remoteVersion: remoteSemver,
      currentVersion: localSemver,
      remoteBuildNumber: remoteBuildNumber,
      currentBuildNumber: localBuildNumber,
    );

    // Si la versión SemVer es idéntica pero el release proviene de compilación continua (latest / latest-build)
    bool continuousUpdate = false;
    if (!semverUpdate && assetUpdatedAt != null && assetUpdatedAt.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastApplied = prefs.getString('last_installed_asset_updated_at');
        if (lastApplied != null && lastApplied.isNotEmpty) {
          final remoteTime = DateTime.tryParse(assetUpdatedAt);
          final localTime = DateTime.tryParse(lastApplied);
          if (remoteTime != null && localTime != null && remoteTime.isAfter(localTime)) {
            continuousUpdate = true;
          }
        }
      } catch (e) {
        debugPrint('[UpdateService] Error comparando timestamps de actualización continua: $e');
      }
    }

    final hasUpdate = semverUpdate || continuousUpdate;

    return GitHubReleaseInfo(
      hasUpdate: hasUpdate,
      localVersion: localSemver,
      localBuildNumber: localBuildNumber,
      remoteVersion: remoteSemver,
      remoteBuildNumber: remoteBuildNumber,
      tagName: tagName.isNotEmpty ? tagName : remoteSemver,
      releaseTitle: releaseTitle.isNotEmpty ? releaseTitle : 'Versión v$remoteSemver',
      releaseNotes: releaseNotes.isNotEmpty
          ? releaseNotes
          : 'Actualización oficial UMBRAL con optimizaciones y Server-Driven UI.',
      apkDownloadUrl: apkDownloadUrl.isNotEmpty
          ? apkDownloadUrl
          : 'https://github.com/$resolvedOwner/$resolvedRepo/releases/download/latest/app-release.apk',
      apkFileName: apkFileName,
      apkFileSize: apkFileSize,
      htmlUrl: htmlUrl,
      assetUpdatedAt: assetUpdatedAt,
      publishedAt: publishedAt,
    );
  }

  /// Verifica y muestra el diálogo Glassmorphic de actualización en la pantalla principal
  Future<void> checkAndShowUpdateModal(
    BuildContext context, {
    bool force = false,
  }) async {
    if (!force && (_hasCheckedThisSession || _isDialogDismissed)) {
      return;
    }
    if (_isCheckingNow) {
      return;
    }

    if (!context.mounted) return;
    if (!force && !_isActiveRootDashboard(context)) return;

    if (!force) {
      _hasCheckedThisSession = true;
    }
    _isCheckingNow = true;

    try {
      final releaseInfo = await checkForUpdate();
      if (!context.mounted) return;
      if (!force && _isDialogDismissed) return;

      if (releaseInfo.hasUpdate) {
        if (!context.mounted) return;
        await GlassmorphicUpdateDialog.show(context, releaseInfo);
      }
    } catch (e) {
      debugPrint('[UpdateService] Error en verificación de actualización: $e');
    } finally {
      _isCheckingNow = false;
    }
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
        '/student',
        '/teacher',
        '/coordinator',
        '/superadmin',
      };
      return rootDashboards.contains(location);
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // DESCARGA E INSTALACIÓN NATIVA DEL APK
  // ===========================================================================

  /// Descarga el APK desde GitHub Releases reportando el progreso en tiempo real
  /// y ejecuta inmediatamente el instalador nativo de Android mediante OpenFilex.
  Future<void> downloadAndInstallApk({
    required String apkUrl,
    required String latestVersion,
    required void Function(double progress, String statusText) onProgress,
    String? assetUpdatedAt,
  }) async {
    if (kIsWeb || !isAndroidPlatform) {
      onProgress(1.0, 'Abriendo enlace en navegador externo...');
      await launchExternalUrl(apkUrl);
      return;
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 40),
        receiveTimeout: const Duration(minutes: 10),
        followRedirects: true,
        maxRedirects: 10,
      ),
    );

    String? tempFilePath;
    try {
      onProgress(0.05, 'Preparando almacenamiento...');
      final targetFilePath = await getApkDestinationPath(latestVersion);
      tempFilePath = '$targetFilePath.part';

      final targetFile = File(targetFilePath);
      await targetFile.parent.create(recursive: true);

      // Limpiar versiones huérfanas previas
      await _cleanupOldApks(targetFile.parent, targetFilePath);

      final tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      onProgress(0.1, 'Conectando con GitHub Releases...');

      var receivedBytes = 0;
      var expectedBytes = 0;

      final response = await dio.download(
        apkUrl,
        tempFilePath,
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
      if (contentType != null && contentType.toLowerCase().contains('text/html')) {
        throw StateError(
          'GitHub entregó una página HTML en lugar del archivo APK. Verifica el enlace del release.',
        );
      }

      final downloadedFile = File(tempFilePath);
      if (!await downloadedFile.exists()) {
        throw StateError('El archivo APK descargado no se guardó en el dispositivo.');
      }

      final fileLength = await downloadedFile.length();
      if (fileLength < 1024 * 1024) {
        throw StateError(
          'El paquete de actualización parece incompleto o corrupto ($fileLength bytes).',
        );
      }

      if (expectedBytes > 0 && receivedBytes != expectedBytes) {
        throw StateError(
          'Descarga incompleta: recibidos $receivedBytes de $expectedBytes bytes.',
        );
      }

      // Validar cabecera binaria ZIP/APK (PK.. 0x50 0x4B 0x03 0x04)
      final handle = await downloadedFile.open(mode: FileMode.read);
      late final List<int> magicBytes;
      try {
        magicBytes = await handle.read(4);
      } finally {
        await handle.close();
      }

      if (magicBytes.length != 4 ||
          magicBytes[0] != 0x50 ||
          magicBytes[1] != 0x4B ||
          magicBytes[2] != 0x03 ||
          magicBytes[3] != 0x04) {
        throw StateError('El archivo recibido no es un paquete APK/ZIP de Android válido.');
      }

      // Mover atómicamente el archivo temporal a su destino final
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      try {
        await downloadedFile.rename(targetFilePath);
      } catch (_) {
        await downloadedFile.copy(targetFilePath);
        await downloadedFile.delete();
      }

      onProgress(1.0, 'Descarga completada. Lanzando instalador nativo...');

      // Ejecutar OpenFilex para disparar el PackageInstaller de Android
      final result = await OpenFilex.open(
        targetFilePath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('[UpdateService] Resultado de instalación: ${result.type} (${result.message})');

      if (result.type == ResultType.done) {
        if (assetUpdatedAt != null && assetUpdatedAt.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('last_installed_asset_updated_at', assetUpdatedAt);
          } catch (_) {}
        }
      } else {
        if (result.type == ResultType.permissionDenied) {
          throw Exception(
            'Permiso denegado para instalar aplicaciones desconocidas. Autoriza a UMBRAL en Ajustes de Android.',
          );
        } else if (result.type == ResultType.noAppToOpen) {
          throw Exception('No se encontró el instalador de paquetes de Android en el sistema.');
        } else {
          throw Exception('Fallo al invocar el instalador (${result.type.name}): ${result.message}');
        }
      }
    } on DioException catch (dioException) {
      final detail = dioException.response != null
          ? 'HTTP ${dioException.response?.statusCode}: ${dioException.response?.statusMessage}'
          : (dioException.message ?? 'Fallo de conexión');
      throw Exception('Fallo en la descarga del paquete ($detail)');
    } catch (e) {
      debugPrint('[UpdateService] Error en descarga/instalación: $e');
      rethrow;
    } finally {
      if (tempFilePath != null) {
        final temp = File(tempFilePath);
        if (await temp.exists()) {
          try {
            await temp.delete();
          } on FileSystemException catch (_) {}
        }
      }
      dio.close(force: true);
    }
  }

  Future<void> _cleanupOldApks(Directory dir, String currentTarget) async {
    try {
      if (!await dir.exists()) return;
      await for (final item in dir.list()) {
        if (item is File &&
            item.path.contains('umbral_release_') &&
            item.path != currentTarget) {
          try {
            await item.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<bool> launchExternalUrl(String url) async {
    var clean = url.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    final uri = Uri.tryParse(clean);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[UpdateService] Error al abrir URL externa: $e');
      return false;
    }
  }
}
