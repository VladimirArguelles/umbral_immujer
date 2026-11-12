import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_receipt_dialogs.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// View listing past or closed surveys and the student's recorded participation.
class StudentSurveysHistoryView extends StatelessWidget {
  const StudentSurveysHistoryView({
    super.key,
    required this.future,
    required this.onRefresh,
  });

  final Future<List<StudentSurvey>> future;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudentSurvey>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SurveysSkeleton();
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(height: 12),
                  Text('Error al cargar historial: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: onRefresh,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final historial = snapshot.data ?? [];
        if (historial.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 64,
                    color: AppTheme.dynamicTextMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no hay encuestas cerradas en tu historial.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.dynamicTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: historial.length,
            itemBuilder: (context, index) =>
                _HistorySurveyCard(survey: historial[index]),
          ),
        );
      },
    );
  }
}

class _HistorySurveyCard extends StatelessWidget {
  const _HistorySurveyCard({required this.survey});

  final StudentSurvey survey;

  @override
  Widget build(BuildContext context) {
    final bool attended = survey.asistira == true;
    final bool hasReceipt =
        survey.comprobanteUrl != null && survey.comprobanteUrl!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                    color: AppTheme.dynamicTextMuted.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'FINALIZADA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.dynamicTextMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Cerrada el: ${Formatters.dateTime(survey.fechaLimite)}',
              style: TextStyle(fontSize: 12, color: AppTheme.dynamicTextMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.dynamicBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insumos: ${Formatters.currency(survey.costoTotalInsumos)}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      Text(
                        'Confirmados: ${survey.totalConfirmados}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.dynamicTextMuted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    Formatters.currency(survey.cuotaACancelar),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  attended ? Icons.check_circle : Icons.info_outline,
                  size: 16,
                  color: attended
                      ? AppTheme.successGreen
                      : AppTheme.dynamicTextMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    attended
                        ? 'Asististe • Aporte: ${Formatters.currency(survey.cuotaACancelar)} (${survey.estadoPago?.toUpperCase() ?? "SIN PAGO"})'
                        : 'No participaste en esta encuesta',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.dynamicTextMuted,
                    ),
                  ),
                ),
                if (hasReceipt)
                  TextButton.icon(
                    onPressed: () => showStudentReceiptModal(
                      context,
                      url: survey.comprobanteUrl!,
                      title: survey.cursoNombre,
                      subtitle: 'Clase: ${survey.fechaClase}',
                      statusLabel: survey.estadoPago,
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Ver Capture'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
