import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../config/remote_config_service.dart';

/// Widget reactivo de texto conectado en tiempo real a Supabase Remote Config.
/// Si el valor en remoto cambia, este widget se reconstruye automáticamente
/// sin requerir nueva compilación ni reinicio de la aplicación.
class RemoteConfigText extends StatelessWidget {
  final String configKey;
  final String fallback;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const RemoteConfigText({
    super.key,
    required this.configKey,
    required this.fallback,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RemoteConfigService.instance,
      builder: (context, _) {
        final text = RemoteConfigService.instance.getRemoteString(
          configKey,
          fallback,
        );
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

/// Contenedor Glassmorphic reactivo a los parámetros de Server-Driven UI.
/// Ajusta su desenfoque (blur), opacidad de fondo y borde luminoso
/// automáticamente según la configuración activa en Supabase.
class RemoteGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? customBorderColor;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const RemoteGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20,
    this.customBorderColor,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RemoteConfigService.instance,
      builder: (context, _) {
        final blur = RemoteConfigService.instance.glassmorphismBlur;
        final opacity = RemoteConfigService.instance.glassmorphismOpacity;
        final borderOpacity = RemoteConfigService.instance.glassmorphismBorderOpacity;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final baseColor = isDark
            ? const Color(0xFF131722)
            : const Color(0xFFF8FAFC);
        final fillColor = baseColor.withValues(alpha: opacity.clamp(0.1, 0.95));

        final defaultBorderColor = isDark
            ? Colors.white.withValues(alpha: borderOpacity.clamp(0.05, 0.5))
            : Colors.black.withValues(alpha: (borderOpacity * 0.7).clamp(0.05, 0.3));

        final resolvedBorderColor = customBorderColor ?? defaultBorderColor;

        Widget content = Container(
          width: width,
          height: height,
          margin: margin,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: resolvedBorderColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );

        if (onTap != null) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: content,
          );
        }

        return content;
      },
    );
  }
}

/// Banner institucional reactivo Server-Driven UI.
/// Muestra avisos globales de mantenimiento o anuncios del sistema
/// gobernados en tiempo real desde `app_remote_config`.
class RemoteConfigBanner extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const RemoteConfigBanner({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RemoteConfigService.instance,
      builder: (context, _) {
        final maintenanceText = RemoteConfigService.instance.maintenanceBannerText.trim();
        final isAnnouncementActive = RemoteConfigService.instance.isAnnouncementBannerActive;
        final announcementText = RemoteConfigService.instance.announcementBannerText.trim();
        final bannerType = RemoteConfigService.instance.announcementBannerType;

        // Si hay banner de mantenimiento prioritario
        final hasMaintenance = maintenanceText.isNotEmpty;
        final hasAnnouncement = isAnnouncementActive && announcementText.isNotEmpty;

        if (!hasMaintenance && !hasAnnouncement) {
          return const SizedBox.shrink();
        }

        final bool isMaintenance = hasMaintenance;
        final String displayText = isMaintenance ? maintenanceText : announcementText;

        Color bannerColor;
        IconData bannerIcon;
        String bannerTitle;

        if (isMaintenance) {
          bannerColor = const Color(0xFFF59E0B); // Amber warning
          bannerIcon = Symbols.engineering;
          bannerTitle = 'Aviso de Mantenimiento';
        } else {
          switch (bannerType.toLowerCase()) {
            case 'warning':
              bannerColor = const Color(0xFFF59E0B);
              bannerIcon = Symbols.warning;
              bannerTitle = 'Aviso Importante';
              break;
            case 'success':
              bannerColor = const Color(0xFF10B981);
              bannerIcon = Symbols.check_circle;
              bannerTitle = 'Información';
              break;
            case 'error':
              bannerColor = const Color(0xFFEF4444);
              bannerIcon = Symbols.error;
              bannerTitle = 'Alerta del Sistema';
              break;
            case 'info':
            default:
              bannerColor = RemoteConfigService.instance.dynamicAccent;
              bannerIcon = Symbols.campaign;
              bannerTitle = 'Comunicado Institucional';
              break;
          }
        }

        return Padding(
          padding: margin,
          child: RemoteGlassCard(
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            customBorderColor: bannerColor.withValues(alpha: 0.4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bannerColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(bannerIcon, color: bannerColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bannerTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: bannerColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
