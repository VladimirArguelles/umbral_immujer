import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_survey_payment_box.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';

/// Card presenting an active supply-contribution survey and attendance confirmation controls.
class StudentActiveSurveyCard extends StatelessWidget {
  const StudentActiveSurveyCard({
    super.key,
    required this.survey,
    required this.isResponding,
    required this.isUploading,
    required this.onRespond,
    required this.onUploadReceipt,
  });

  final StudentSurvey survey;
  final bool isResponding;
  final bool isUploading;
  final ValueChanged<bool> onRespond;
  final VoidCallback onUploadReceipt;

  @override
  Widget build(BuildContext context) {
    final bool isClosed = survey.estaVencida || survey.estadoEncuesta != 'activa';
    final statusColor = isClosed ? AppTheme.errorRed : AppTheme.successGreen;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.poll_rounded,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        survey.cursoNombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (survey.profesorNombre != null &&
                          survey.profesorNombre!.isNotEmpty)
                        Text(
                          'Prof. ${survey.profesorNombre}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.dynamicTextMuted,
                          ),
                        ),
                      Text(
                        'Clase: ${survey.fechaClase}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.dynamicTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isClosed ? 'CERRADA' : 'ACTIVA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: AppTheme.warningOrange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Límite de Confirmación: ${Formatters.dateTime(survey.fechaLimite)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.dynamicTextMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ConfirmationSection(
              survey: survey,
              isClosed: isClosed,
              isResponding: isResponding,
              onRespond: onRespond,
            ),
            const SizedBox(height: 14),
            _ContributionBreakdownCard(survey: survey),
            const SizedBox(height: 14),
            StudentSurveyPaymentBox(
              survey: survey,
              isUploading: isUploading,
              onUploadPressed: onUploadReceipt,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationSection extends StatelessWidget {
  const _ConfirmationSection({
    required this.survey,
    required this.isClosed,
    required this.isResponding,
    required this.onRespond,
  });

  final StudentSurvey survey;
  final bool isClosed;
  final bool isResponding;
  final ValueChanged<bool> onRespond;

  @override
  Widget build(BuildContext context) {
    final bool? asistira = survey.asistira;
    if (asistira == null) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (isClosed || isResponding)
                  ? null
                  : () => onRespond(true),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Sí, asistiré'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (isClosed || isResponding)
                  ? null
                  : () => onRespond(false),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('No podré'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      );
    }

    final confirmColor = asistira ? AppTheme.successGreen : AppTheme.errorRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: confirmColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: confirmColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            asistira ? Icons.check_circle : Icons.cancel,
            color: confirmColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              asistira
                  ? 'Confirmaste que SÍ asistirás'
                  : 'Indicaste que NO podrás asistir',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: confirmColor,
              ),
            ),
          ),
          if (!isClosed)
            TextButton.icon(
              onPressed: isResponding ? null : () => onRespond(!asistira),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Cambiar'),
            ),
        ],
      ),
    );
  }
}

class _ContributionBreakdownCard extends StatelessWidget {
  const _ContributionBreakdownCard({required this.survey});

  final StudentSurvey survey;

  @override
  Widget build(BuildContext context) {
    final bool hasAmount = survey.cuotaACancelar > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dynamicBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'APORTE PARA COMPRA DE INSUMOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tu cuota estimada:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              Text(
                hasAmount
                    ? Formatters.currency(survey.cuotaACancelar)
                    : 'Por calcular',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Costo total insumos: ${Formatters.currency(survey.costoTotalInsumos)} • Confirmadas: ${survey.totalConfirmados}',
            style: TextStyle(fontSize: 12, color: AppTheme.dynamicTextMuted),
          ),
          if (survey.tasaBcvUsada != null && survey.tasaBcvUsada! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Tasa BCV aplicada: Bs. ${survey.tasaBcvUsada!.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: AppTheme.dynamicTextMuted),
            ),
          ],
        ],
      ),
    );
  }
}
