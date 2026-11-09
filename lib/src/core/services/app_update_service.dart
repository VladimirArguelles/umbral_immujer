import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  /// Verifica si existe una versión superior a la actualmente instalada.
  Future<UpdateInfo> checkForUpdate({SupabaseClient? client}) async {
    String currentVer = '0.1.0';
    try {
      final info = await PackageInfo.fromPlatform();
      currentVer = info.version;
    } catch (e) {
      debugPrint('[AppUpdateService] No se pudo obtener PackageInfo: $e');
    }

    String latestVer = currentVer;
    String apkUrl = defaultReleaseUrl;
    String notes = 'Mejoras continuas, corrección de errores y nuevas funcionalidades.';
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

    final hasUpdate = _isVersionGreater(latestVer, currentVer);

    return UpdateInfo(
      hasUpdate: hasUpdate,
      currentVersion: currentVer,
      latestVersion: latestVer,
      apkUrl: apkUrl.isNotEmpty ? apkUrl : defaultReleaseUrl,
      releaseNotes: notes,
      isMandatory: isMandatory,
    );
  }

  /// Compara dos strings semánticos de versión (ej. '0.2.0' vs '0.1.0').
  bool _isVersionGreater(String remote, String current) {
    try {
      final rParts = remote.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final cParts = current.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error al comparar semver: $e');
    }
    return false;
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
