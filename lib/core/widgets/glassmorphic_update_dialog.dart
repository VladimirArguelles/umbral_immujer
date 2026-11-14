import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../config/remote_config_service.dart';
import '../services/update_service.dart';

/// Diálogo modal interactivo con estética Glassmorphic para notificar,
/// descargar con barra de progreso e instalar actualizaciones de GitHub Releases.
class GlassmorphicUpdateDialog extends StatefulWidget {
  final GitHubReleaseInfo releaseInfo;

  const GlassmorphicUpdateDialog({
    super.key,
    required this.releaseInfo,
  });

  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context,
    GitHubReleaseInfo releaseInfo,
  ) async {
    if (_isShowing || !context.mounted) return;
    if (!releaseInfo.isMandatory && UpdateService.instance.isDialogDismissed) {
      return;
    }

    _isShowing = true;
    try {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: !releaseInfo.isMandatory,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        builder: (_) => GlassmorphicUpdateDialog(releaseInfo: releaseInfo),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<GlassmorphicUpdateDialog> createState() => _GlassmorphicUpdateDialogState();
}

class _GlassmorphicUpdateDialogState extends State<GlassmorphicUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusText = 'Iniciando descarga desde GitHub...';
    });

    try {
      await UpdateService.instance.downloadAndInstallApk(
        apkUrl: widget.releaseInfo.apkDownloadUrl,
        latestVersion: widget.releaseInfo.remoteVersion,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _statusText = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = 'Instalador nativo ejecutado.';
        });
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      if (mounted) {
        String msg = 'No se pudo completar la instalación.';
        if (e is DioException) {
          if (e.response?.statusCode == 404) {
            msg = 'El archivo APK no está disponible en GitHub Releases (HTTP 404).';
          } else if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            msg = 'Tiempo agotado al conectar con GitHub. Verifica tu conexión a internet.';
          } else {
            msg = 'Error de red al descargar el paquete (${e.response?.statusCode ?? e.message}).';
          }
        } else {
          msg = e.toString().replaceAll('Exception: ', '').trim();
          if (msg.isEmpty) {
            msg = 'Error durante la instalación: $e';
          }
        }

        setState(() {
          _isDownloading = false;
          _errorMessage = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blur = RemoteConfigService.instance.glassmorphismBlur;
    final primaryColor = RemoteConfigService.instance.dynamicPrimary;
    final accentColor = RemoteConfigService.instance.dynamicAccent;

    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return PopScope(
      canPop: !widget.releaseInfo.isMandatory && !_isDownloading,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !widget.releaseInfo.isMandatory) {
          UpdateService.instance.markDialogDismissed();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF131722).withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header con Icono Glassmorphic
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withValues(alpha: 0.25),
                                accentColor.withValues(alpha: 0.15),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Symbols.cloud_download,
                            color: primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Actualización In-App',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: accentColor.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      'Nueva: v${widget.releaseInfo.remoteDisplayVersion}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Instalada: v${widget.releaseInfo.localDisplayVersion}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: subtitleColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Título del Release
                    Text(
                      widget.releaseInfo.releaseTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Novedades / Release Notes
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0B0E17).withValues(alpha: 0.6)
                            : const Color(0xFFF1F5F9).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2E384D)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          widget.releaseInfo.releaseNotes,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            height: 1.45,
                            color: subtitleColor,
                          ),
                        ),
                      ),
                    ),

                    // Progreso de Descarga
                    if (_isDownloading) ...[
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Descargando paquete...',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              Text(
                                '${(_progress * 100).toInt()}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progress > 0 ? _progress : null,
                              minHeight: 8,
                              backgroundColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _statusText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Mensaje de Error
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Symbols.error,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: const Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Botones de Acción
                    Row(
                      children: [
                        if (!widget.releaseInfo.isMandatory && !_isDownloading)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                UpdateService.instance.markDialogDismissed();
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                side: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                'Más tarde',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: subtitleColor,
                                ),
                              ),
                            ),
                          ),
                        if (!widget.releaseInfo.isMandatory && !_isDownloading)
                          const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isDownloading
                                ? null
                                : () => _startDownloadAndInstall(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isDownloading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Symbols.install_mobile, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Actualizar Ahora',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
