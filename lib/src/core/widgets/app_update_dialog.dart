import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

/// Diálogo modal interactivo para notificar, descargar e instalar actualizaciones In-App.
class AppUpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
  });

  static Future<void> show(BuildContext context, UpdateInfo updateInfo) {
    return showDialog(
      context: context,
      barrierDismissible: !updateInfo.isMandatory,
      builder: (_) => AppUpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusText = 'Iniciando descarga...';
    });

    try {
      await AppUpdateService.instance.downloadAndInstallApk(
        apkUrl: widget.updateInfo.apkUrl,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _statusText = status;
            });
          }
        },
      );

      if (mounted && !widget.updateInfo.isMandatory) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        String msg = 'No se pudo completar la descarga automática.';
        if (e is DioException) {
          if (e.response?.statusCode == 404) {
            msg = 'El archivo de actualización no se encuentra disponible temporalmente en el servidor.';
          } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
            msg = 'Tiempo de conexión agotado. Revisa tu conexión a internet.';
          } else {
            msg = 'Error de red al descargar el paquete (${e.response?.statusCode ?? 'sin conexión'}).';
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
    final cardBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return PopScope(
      canPop: !widget.updateInfo.isMandatory && !_isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: cardBg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado con Icono
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Symbols.system_update_alt,
                        color: AppTheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actualización Disponible',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v${widget.updateInfo.latestVersion}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              Text(
                                'Actual: v${widget.updateInfo.currentVersion}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Contenido: Novedades
                Text(
                  'Novedades de la versión:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 130),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131722) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.updateInfo.releaseNotes,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        height: 1.4,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                ),

                // Barra de Progreso durante Descarga
                if (_isDownloading) ...[
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _statusText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: subtitleColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(_progress * 100).toInt()}%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          backgroundColor: isDark ? const Color(0xFF2B2D38) : const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ],

                // Mensaje de Error si la descarga falla
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.errorRed,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: AppTheme.primary,
                          ),
                          onPressed: () => AppUpdateService.instance.launchDownload(widget.updateInfo.apkUrl),
                          icon: const Icon(Symbols.open_in_browser, size: 16),
                          label: const Text(
                            'Descargar directamente desde el navegador',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Botón Principal de Actualización
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                  ),
                  onPressed: _isDownloading ? null : _startUpdate,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Symbols.download, size: 20),
                  label: Text(
                    _isDownloading
                        ? 'Descargando...'
                        : _errorMessage != null
                            ? 'Reintentar Actualización'
                            : 'Actualizar Ahora (APK)',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),

                // Botón Opcional para posponer si no es obligatoria
                if (!widget.updateInfo.isMandatory && !_isDownloading) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Recordarme más tarde',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
