import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/core/utils/schedule_parser.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Compact KPI summary card for the Coordinator overview tab.
class CoordinatorMetricCard extends StatelessWidget {
  const CoordinatorMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: color.withValues(alpha: 0.08),
        splashColor: color.withValues(alpha: 0.15),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: onTap != null
                  ? color.withValues(alpha: 0.35)
                  : AppTheme.dynamicBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.dynamicTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: color),
                      if (onTap != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.dynamicTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onTap != null)
                    Text(
                      'Ver más',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: color,
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

/// Course monitoring card with schedule status, absence alerts, and roster trigger.
class CoordinatorCourseCard extends StatelessWidget {
  const CoordinatorCourseCard({
    super.key,
    required this.course,
    required this.onOpenRoster,
  });

  final CourseDashboardItem course;
  final VoidCallback onOpenRoster;

  @override
  Widget build(BuildContext context) {
    final isActiveNow = ScheduleParser.isCourseActiveNow(course.horario);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: course.ausenciasHoy > 0
              ? AppTheme.errorRed.withValues(alpha: 0.5)
              : AppTheme.dynamicBorder,
          width: course.ausenciasHoy > 0 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ScheduleStatusBadge(isActiveNow: isActiveNow),
            const SizedBox(height: 8),
            Text(
              course.nombre,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.dynamicText,
              ),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
            ),
            if (course.horario != null && course.horario!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: AppTheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      course.horario!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.dynamicTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.person_pin,
                  size: 16,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Docente: ${course.profesorNombre ?? "Sin asignar"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (course.ausenciasHoy > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${course.ausenciasHoy} alumno(s) ausente(s) registrados hoy',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (course.porcentajeAsistencia / 100).clamp(
                        0.0,
                        1.0,
                      ),
                      backgroundColor: AppTheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        course.porcentajeAsistencia >= 80
                            ? AppTheme.successGreen
                            : AppTheme.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${course.porcentajeAsistencia.toStringAsFixed(0)}% Asistencia',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.menu_book_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Plantilla Alumnos y Temas'),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: AppTheme.primary),
                ),
                onPressed: onOpenRoster,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleStatusBadge extends StatelessWidget {
  const _ScheduleStatusBadge({required this.isActiveNow});

  final bool isActiveNow;

  @override
  Widget build(BuildContext context) {
    final color = isActiveNow ? AppTheme.successGreen : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActiveNow
            ? AppTheme.successGreen.withValues(alpha: 0.2)
            : AppTheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActiveNow ? Icons.sensors_rounded : Icons.calendar_month_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isActiveNow ? 'EN CURSO HOY' : 'PROGRAMADO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
