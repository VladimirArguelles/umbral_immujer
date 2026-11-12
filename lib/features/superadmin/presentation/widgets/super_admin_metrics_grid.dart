import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/superadmin/domain/super_admin_metrics.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_headers.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_theme_tokens.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Responsive 2-column or 4-column grid of Super Admin institutional KPIs.
class SuperAdminMetricsGrid extends StatelessWidget {
  const SuperAdminMetricsGrid({
    super.key,
    required this.metrics,
    required this.onOpenUsers,
    required this.spacing,
    this.onlineUsersFontSize = 12,
    this.forceColumns,
  });

  final SuperAdminMetrics metrics;
  final VoidCallback onOpenUsers;
  final double spacing;
  final double onlineUsersFontSize;
  final int? forceColumns;

  @override
  Widget build(BuildContext context) {
    final mutedStyle = GoogleFonts.plusJakartaSans(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: SuperAdminTokens.textMuted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SuperAdminSectionLabel('MÉTRICAS GENERALES'),
            SuperAdminOnlineUsersBadge(fontSize: onlineUsersFontSize),
          ],
        ),
        SizedBox(height: spacing == 16 ? 14 : 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                forceColumns ?? (constraints.maxWidth >= 1050 ? 4 : 2);
            final cardWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    onTap: onOpenUsers,
                    title: 'Usuarios Registrados',
                    trailing: InkWell(
                      onTap: onOpenUsers,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: SuperAdminTokens.accent.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: SuperAdminTokens.accent.withValues(alpha: 0.65),
                          ),
                        ),
                        child: const Icon(
                          Symbols.edit,
                          size: 15,
                          color: Color(0xFFC084FC),
                        ),
                      ),
                    ),
                    body: Text(
                      formatSuperAdminMetric(metrics.totalUsers),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: SuperAdminTokens.textMain,
                      ),
                    ),
                    footer: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Usuarios autenticados en Supabase',
                            style: mutedStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Symbols.verified_user,
                          size: 15,
                          color: SuperAdminTokens.mintBright,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    title: 'Cursos Activos',
                    trailing: const Icon(
                      Symbols.menu_book,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    body: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatSuperAdminMetric(metrics.totalCourses),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: SuperAdminTokens.textMain,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'talleres',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: SuperAdminTokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                    footer: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: SuperAdminTokens.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Talleres en operación',
                            style: mutedStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    title: 'Asistencia registrada',
                    trailing: const Icon(
                      Symbols.check_circle,
                      size: 16,
                      color: SuperAdminTokens.mintBright,
                    ),
                    body: Text(
                      metrics.attendanceRate == null
                          ? '—'
                          : '${(metrics.attendanceRate! * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: SuperAdminTokens.mintBright,
                      ),
                    ),
                    footer: _AttendanceProgressBar(rate: metrics.attendanceRate),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    title: 'Recaudación',
                    trailing: const Icon(
                      Symbols.wallet,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    body: Text(
                      'No disponible',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: SuperAdminTokens.textMuted,
                      ),
                    ),
                    footer: Text(
                      'Sin agregado contable',
                      style: mutedStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.trailing,
    required this.body,
    required this.footer,
    this.onTap,
  });

  final String title;
  final Widget trailing;
  final Widget body;
  final Widget footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SuperAdminTokens.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 6),
          body,
          const Spacer(),
          footer,
        ],
      ),
    );
    return Container(
      height: 132,
      decoration: BoxDecoration(
        color: SuperAdminTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SuperAdminTokens.border.withValues(alpha: 0.7),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

class _AttendanceProgressBar extends StatelessWidget {
  const _AttendanceProgressBar({required this.rate});

  final double? rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: SuperAdminTokens.border.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: rate?.clamp(0, 1) ?? 0,
        child: Container(
          decoration: BoxDecoration(
            color: SuperAdminTokens.mintBright,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: SuperAdminTokens.mintBright.withValues(alpha: 0.45),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
