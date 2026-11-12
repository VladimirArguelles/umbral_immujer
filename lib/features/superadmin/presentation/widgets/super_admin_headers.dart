import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_notifications_modal.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_theme_tokens.dart';
import 'package:umbral_immujer/src/core/services/online_user_presence_service.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Live indicator showing how many authenticated users are currently online.
class SuperAdminOnlineUsersBadge extends StatelessWidget {
  const SuperAdminOnlineUsersBadge({super.key, this.fontSize = 12});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      stream: OnlineUserPresenceService.instance.onlineUserCountStream,
      initialData: OnlineUserPresenceService.instance.onlineUserCount,
      builder: (context, snapshot) {
        final count = snapshot.data;
        final text = count == null
            ? 'Usuarios en línea: —'
            : count == 1
            ? '1 usuario en línea'
            : '$count usuarios en línea';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFFACC15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66FACC15),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFACC15),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shared status pill used in both desktop and mobile Super Admin headers.
class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.isLoading,
    required this.hasError,
    required this.readyLabel,
    required this.letterSpacing,
    required this.spreadRadius,
  });

  final bool isLoading;
  final bool hasError;
  final String readyLabel;
  final double letterSpacing;
  final double spreadRadius;

  @override
  Widget build(BuildContext context) {
    final statusColor = isLoading
        ? AppTheme.secondary
        : !hasError
        ? SuperAdminTokens.mintBright
        : AppTheme.errorRed;

    final statusText = isLoading
        ? 'CARGANDO MÉTRICAS'
        : !hasError
        ? readyLabel
        : 'MÉTRICAS NO DISPONIBLES';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.45),
                blurRadius: 8,
                spreadRadius: spreadRadius,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            statusText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: statusColor,
              letterSpacing: letterSpacing,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Header displayed on desktop viewports (>= 1024px).
class SuperAdminDesktopHeader extends StatelessWidget {
  const SuperAdminDesktopHeader({
    super.key,
    required this.isLoadingMetrics,
    required this.hasMetricsError,
    required this.onRefreshMetrics,
    required this.onOpenQuickAdd,
    required this.onOpenSettings,
  });

  final bool isLoadingMetrics;
  final bool hasMetricsError;
  final VoidCallback onRefreshMetrics;
  final VoidCallback onOpenQuickAdd;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusIndicator(
                isLoading: isLoadingMetrics,
                hasError: hasMetricsError,
                readyLabel: 'SISTEMA OPERATIVO Y SINCRONIZADO',
                letterSpacing: 1.0,
                spreadRadius: 2,
              ),
              const SizedBox(height: 8),
              Text(
                'Centro de Control Super Admin',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: SuperAdminTokens.textMain,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: SuperAdminTokens.textMuted,
                      ),
                      children: const [
                        TextSpan(text: 'Sede Central '),
                        TextSpan(
                          text: '• ',
                          style: TextStyle(color: SuperAdminTokens.textDim),
                        ),
                        TextSpan(text: 'Telemetría global en vivo'),
                      ],
                    ),
                  ),
                  const Text(
                    '•',
                    style: TextStyle(color: SuperAdminTokens.textDim),
                  ),
                  const SuperAdminOnlineUsersBadge(fontSize: 12),
                ],
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenQuickAdd,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SuperAdminTokens.accent, AppTheme.primary],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: SuperAdminTokens.accentGlow,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Añadir registro',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onRefreshMetrics,
          tooltip: 'Actualizar métricas',
          icon: isLoadingMetrics
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SuperAdminTokens.mintBright,
                  ),
                )
              : const Icon(Symbols.refresh, color: SuperAdminTokens.textMuted),
        ),
        const SizedBox(width: 4),
        const SuperAdminNotificationBellButton(),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onOpenSettings,
          tooltip: 'Ajustes rápidos',
          icon: const Icon(Symbols.tune, color: SuperAdminTokens.textMuted),
        ),
      ],
    );
  }
}

/// Header card displayed on mobile and tablet viewports (< 1024px).
class SuperAdminMobileHeader extends StatelessWidget {
  const SuperAdminMobileHeader({
    super.key,
    required this.isLoadingMetrics,
    required this.hasMetricsError,
    required this.onOpenQuickAdd,
  });

  final bool isLoadingMetrics;
  final bool hasMetricsError;
  final VoidCallback onOpenQuickAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SuperAdminTokens.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: SuperAdminTokens.border.withValues(alpha: 0.7),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusIndicator(
                  isLoading: isLoadingMetrics,
                  hasError: hasMetricsError,
                  readyLabel: 'RESUMEN DISPONIBLE',
                  letterSpacing: 0.8,
                  spreadRadius: 1,
                ),
                const SizedBox(height: 6),
                Text(
                  'Centro de Control Super Admin',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SuperAdminTokens.textMain,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: SuperAdminTokens.textMuted,
                    ),
                    children: const [
                      TextSpan(text: 'Administración institucional '),
                      TextSpan(
                        text: '• ',
                        style: TextStyle(color: SuperAdminTokens.textDim),
                      ),
                      TextSpan(text: 'Resumen general'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SuperAdminNotificationBellButton(),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpenQuickAdd,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [SuperAdminTokens.accent, AppTheme.primary],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: SuperAdminTokens.accentGlow,
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_circle_outline,
                      color: AppTheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
