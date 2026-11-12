import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/superadmin/domain/super_admin_metrics.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_theme_tokens.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Displays the 4 Super Admin management module cards for desktop and mobile.
class SuperAdminModulesSection extends StatelessWidget {
  const SuperAdminModulesSection({
    super.key,
    required this.metrics,
    required this.isDesktop,
  });

  final SuperAdminMetrics metrics;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final cards = _buildModuleCards(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SuperAdminSectionLabel('MÓDULOS DE GESTIÓN'),
        SizedBox(height: isDesktop ? 14 : 12),
        if (isDesktop) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: cards[3]),
              const SizedBox(width: 16),
              const Spacer(),
            ],
          ),
        ] else
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            cards[i],
          ],
      ],
    );
  }

  List<Widget> _buildModuleCards(BuildContext context) {
    final formattedTeachers = formatSuperAdminMetric(metrics.totalTeachers);
    return [
      SuperAdminModuleCard(
        icon: Symbols.school,
        iconColor: AppTheme.primary,
        title: 'Módulo Alumnos',
        badgeText: '${formatSuperAdminMetric(metrics.totalStudents)} alumnos',
        badgeBg: AppTheme.secondaryContainer,
        badgeTextColor: AppTheme.onSecondaryContainer,
        subtitle: 'Matrícula y seguimiento de asistencias.',
        bottomLeftWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.groups, size: 16, color: SuperAdminTokens.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${formatSuperAdminMetric(metrics.totalStudents)} alumnos',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SuperAdminTokens.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        isPrimaryAction: true,
        onEnter: () => context.go('/student'),
      ),
      SuperAdminModuleCard(
        icon: Symbols.badge,
        iconColor: AppTheme.secondary,
        title: 'Módulo Profesores',
        badgeText: '$formattedTeachers docentes',
        badgeBg: AppTheme.secondaryContainer,
        badgeTextColor: AppTheme.onSecondaryContainer,
        subtitle: 'Plantel docente y programación de sesiones.',
        bottomLeftWidget: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: SuperAdminTokens.mintBright,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: SuperAdminTokens.mintBright.withValues(alpha: 0.45),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$formattedTeachers docentes registrados',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: SuperAdminTokens.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        isPrimaryAction: false,
        onEnter: () => context.go('/teacher'),
      ),
      SuperAdminModuleCard(
        icon: Symbols.military_tech,
        iconColor: AppTheme.tertiary,
        title: 'Módulo Coordinadores',
        badgeText:
            '${formatSuperAdminMetric(metrics.totalCoordinators)} coordinadores',
        badgeBg: AppTheme.tertiaryContainer,
        badgeTextColor: AppTheme.onTertiaryContainer,
        subtitle: 'Supervisión institucional y reportes.',
        bottomLeftWidget: Row(
          children: [
            const Icon(
              Symbols.verified_user,
              size: 14,
              color: SuperAdminTokens.mintBright,
            ),
            const SizedBox(width: 6),
            Text(
              'Gestión institucional',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: SuperAdminTokens.textMuted,
              ),
            ),
          ],
        ),
        isPrimaryAction: false,
        onEnter: () => context.go('/coordinator'),
      ),
      SuperAdminModuleCard(
        icon: Symbols.how_to_reg,
        iconColor: AppTheme.successGreen,
        title: 'Módulo Inscripciones',
        badgeText: 'Cupos en vivo',
        badgeBg: AppTheme.successGreen.withValues(alpha: 0.16),
        badgeTextColor: AppTheme.successGreen,
        subtitle: 'Registro de aspirantes, validación de cédula y cuotas.',
        bottomLeftWidget: Row(
          children: [
            const Icon(Symbols.analytics, size: 14, color: AppTheme.successGreen),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Formulario y control de cupos',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: SuperAdminTokens.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        isPrimaryAction: true,
        onEnter: () => context.go('/inscripciones'),
      ),
    ];
  }
}

/// Reusable module navigation card for the Super Admin dashboard.
class SuperAdminModuleCard extends StatelessWidget {
  const SuperAdminModuleCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.badgeText,
    required this.badgeBg,
    required this.badgeTextColor,
    required this.subtitle,
    required this.bottomLeftWidget,
    required this.isPrimaryAction,
    required this.onEnter,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String badgeText;
  final Color badgeBg;
  final Color badgeTextColor;
  final String subtitle;
  final Widget bottomLeftWidget;
  final bool isPrimaryAction;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEnter,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SuperAdminTokens.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: SuperAdminTokens.border.withValues(alpha: 0.8),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: SuperAdminTokens.cardInner,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SuperAdminTokens.border),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: SuperAdminTokens.textMain,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.secondary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                badgeText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: badgeTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: SuperAdminTokens.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: bottomLeftWidget,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onEnter,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: isPrimaryAction
                            ? const LinearGradient(
                                colors: [
                                  SuperAdminTokens.accent,
                                  AppTheme.primary,
                                ],
                              )
                            : null,
                        color: isPrimaryAction
                            ? null
                            : SuperAdminTokens.cardInner,
                        borderRadius: BorderRadius.circular(12),
                        border: isPrimaryAction
                            ? null
                            : Border.all(color: SuperAdminTokens.border),
                        boxShadow: isPrimaryAction
                            ? const [
                                BoxShadow(
                                  color: SuperAdminTokens.accentGlow,
                                  blurRadius: 12,
                                  offset: Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isPrimaryAction ? 'ENTRAR' : 'SELECCIONAR',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isPrimaryAction
                                  ? AppTheme.onPrimaryContainer
                                  : SuperAdminTokens.textMain,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward,
                            size: 13,
                            color: isPrimaryAction
                                ? AppTheme.onPrimaryContainer
                                : SuperAdminTokens.textMuted,
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
    );
  }
}
