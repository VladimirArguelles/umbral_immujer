import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Metric card used in the Student Attendance summary row.
class StudentAttendanceMetricCard extends StatelessWidget {
  const StudentAttendanceMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.dynamicTextMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Attendance record card showing present/absent state and linked justification.
class StudentAttendanceHistoryCard extends StatelessWidget {
  const StudentAttendanceHistoryCard({
    super.key,
    required this.record,
    required this.justification,
    required this.onJustifyDate,
    required this.onViewProof,
  });

  final AttendanceRecord record;
  final JustificativoAsistencia? justification;
  final ValueChanged<String> onJustifyDate;
  final ValueChanged<String> onViewProof;

  @override
  Widget build(BuildContext context) {
    final isAusente = record.estado.toLowerCase() == 'ausente';
    final statusColor =
        isAusente ? AppTheme.errorRed : AppTheme.successGreen;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.1),
              child: Icon(
                isAusente ? Icons.cancel : Icons.check_circle,
                color: statusColor,
              ),
            ),
            title: Text(
              'Fecha: ${record.fecha}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: justification != null
                ? Text(
                    'Justificativo: ${justification!.estado.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: justificationStatusColor(justification!.estado),
                    ),
                  )
                : null,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                record.estado,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ),
          if (isAusente && justification == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onJustifyDate(record.fecha),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Subir justificativo para esta falta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          if (justification != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.dynamicBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Motivo: ${justification!.motivo}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.dynamicTextMuted,
                        ),
                      ),
                    ),
                    if (justification!.comprobanteUrl != null)
                      IconButton(
                        icon: const Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                        tooltip: 'Ver soporte',
                        onPressed: () =>
                            onViewProof(justification!.comprobanteUrl!),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Card listing a submitted absence justification and reviewer comments.
class StudentJustificationCard extends StatelessWidget {
  const StudentJustificationCard({
    super.key,
    required this.justification,
    required this.onViewProof,
  });

  final JustificativoAsistencia justification;
  final ValueChanged<String> onViewProof;

  @override
  Widget build(BuildContext context) {
    final badgeColor = justificationStatusColor(justification.estado);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  size: 18,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Falta del ${justification.fecha}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    justification.estado.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(justification.motivo, style: const TextStyle(fontSize: 13)),
            if (justification.comentariosRevision != null &&
                justification.comentariosRevision!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Nota de Coordinación: ${justification.comentariosRevision}',
                  style: TextStyle(fontSize: 12, color: badgeColor),
                ),
              ),
            ],
            if (justification.comprobanteUrl != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onViewProof(justification.comprobanteUrl!),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Ver Récipe / Soporte'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color justificationStatusColor(String estado) {
  switch (estado.toLowerCase()) {
    case 'aprobado':
      return AppTheme.successGreen;
    case 'rechazado':
      return AppTheme.errorRed;
    default:
      return AppTheme.warningOrange;
  }
}
