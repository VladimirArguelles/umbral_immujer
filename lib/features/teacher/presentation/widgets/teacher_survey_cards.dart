import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';

/// Card displaying an active supply survey with budget, BCV rate, and manage controls.
class TeacherActiveSurveyCard extends StatelessWidget {
  const TeacherActiveSurveyCard({
    super.key,
    required this.survey,
    required this.onManage,
    required this.onDelete,
  });

  final TeacherSurvey survey;
  final VoidCallback onManage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fechaClaseDate = DateTime.tryParse(survey.fechaClase);
    final fechaClaseStr =
        fechaClaseDate != null ? Formatters.date(fechaClaseDate) : survey.fechaClase;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: survey.hasExpired
              ? AppTheme.dynamicBorder
              : AppTheme.mintNeon.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.mintNeon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppTheme.mintNeon,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'APORTE PARA COMPRA DE INSUMOS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mintNeon,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      survey.cursoNombre,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (survey.hasExpired
                          ? AppTheme.errorRed
                          : AppTheme.successGreen)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  survey.hasExpired ? 'Vencida' : 'Activa',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: survey.hasExpired
                        ? AppTheme.errorRed
                        : AppTheme.successGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 14,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Práctica: $fechaClaseStr',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Icon(
                Icons.timer_outlined,
                size: 14,
                color: AppTheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Límite: ${Formatters.dateTime(survey.fechaLimite)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Monto del aporte individual a cancelar:',
            style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            survey.totalConfirmados > 0
                ? 'Bs. ${(survey.montoIndividualCalculado * (survey.tasaBcvUsada ?? 1.0)).toStringAsFixed(2)} Bs.'
                : 'Pendiente de cálculo',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.mintNeon,
            ),
          ),
          if (survey.totalConfirmados > 0)
            Text(
              '~ \$${survey.montoIndividualCalculado.toStringAsFixed(2)} USD por alumno',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.successGreen,
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 14,
                color: AppTheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Presupuesto: \$${survey.costoTotalInsumos.toStringAsFixed(2)} USD',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${survey.totalConfirmados} confirmados',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (survey.tasaBcvUsada != null && survey.tasaBcvUsada! > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.currency_exchange,
                  size: 13,
                  color: AppTheme.mintNeon,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Tasa BCV (Fecha Valor): Bs. ${survey.tasaBcvUsada!.toStringAsFixed(2)} / USD',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.mintNeon,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text(
                    'Gestionar Encuesta',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    foregroundColor: AppTheme.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onManage,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.errorRed,
                    size: 22,
                  ),
                  tooltip: 'Eliminar Encuesta',
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card displaying an archived/closed survey in the teacher's history view.
class TeacherHistorySurveyCard extends StatelessWidget {
  const TeacherHistorySurveyCard({
    super.key,
    required this.survey,
    required this.onViewPayments,
  });

  final TeacherSurvey survey;
  final VoidCallback onViewPayments;

  @override
  Widget build(BuildContext context) {
    final fechaClaseDate = DateTime.tryParse(survey.fechaClase);
    final fechaClaseStr =
        fechaClaseDate != null ? Formatters.date(fechaClaseDate) : survey.fechaClase;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  survey.cursoNombre,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.dynamicText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.dynamicSurfaceHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  survey.estado.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dynamicTextMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Práctica: $fechaClaseStr • Presupuesto: \$${survey.costoTotalInsumos.toStringAsFixed(2)} USD',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text:
                      'Confirmados: ${survey.totalConfirmados} alumnos • Cuota final: \$',
                ),
                TextSpan(
                  text: survey.montoIndividualCalculado.toStringAsFixed(2),
                  style: const TextStyle(color: AppTheme.successGreen),
                ),
                const TextSpan(text: ' USD'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long_rounded, size: 16),
            label: const Text(
              'Ver Pagos y Comprobantes',
              style: TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onViewPayments,
          ),
        ],
      ),
    );
  }
}
