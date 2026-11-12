import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Displays the action sheet for an active survey (edit, payments audit, close, delete).
void showTeacherSurveyActionsSheet({
  required BuildContext context,
  required TeacherSurvey survey,
  required VoidCallback onEdit,
  required VoidCallback onAuditPayments,
  required VoidCallback onClose,
  required VoidCallback onDelete,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.9,
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gestión de Encuesta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      survey.cursoNombre,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ActionTile(
            icon: Icons.edit_note_rounded,
            iconColor: AppTheme.mintNeon,
            borderColor: AppTheme.outlineVariant,
            title: 'Modificar Presupuesto y Fechas',
            subtitle:
                'Ajusta el monto en USD, fecha de práctica o fecha límite con recálculo automático.',
            onTap: () {
              Navigator.pop(ctx);
              onEdit();
            },
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.receipt_long_rounded,
            iconColor: AppTheme.primary,
            borderColor: AppTheme.outlineVariant,
            title: 'Auditoría de Pagos y Confirmaciones',
            subtitle:
                '${survey.totalConfirmados} alumnos confirmados. Revisa y aprueba comprobantes.',
            onTap: () {
              Navigator.pop(ctx);
              onAuditPayments();
            },
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.lock_clock_rounded,
            iconColor: AppTheme.errorRed,
            borderColor: AppTheme.errorRed.withValues(alpha: 0.4),
            titleColor: AppTheme.errorRed,
            title: 'Finalizar Encuesta (Mover al Historial)',
            subtitle:
                'Cierra la encuesta para no recibir más respuestas de alumnos.',
            onTap: () {
              Navigator.pop(ctx);
              onClose();
            },
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.delete_forever_rounded,
            iconColor: AppTheme.errorRed,
            borderColor: AppTheme.errorRed.withValues(alpha: 0.6),
            titleColor: AppTheme.errorRed,
            title: 'Eliminar Encuesta',
            subtitle:
                'Borra permanentemente la encuesta y los registros vinculados.',
            onTap: () {
              Navigator.pop(ctx);
              onDelete();
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final Color? titleColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      tileColor: AppTheme.surfaceBright,
      leading: Icon(icon, color: iconColor, size: 26),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13.5,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11.5, color: AppTheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: titleColor),
      onTap: onTap,
    );
  }
}

/// Confirms closing a survey and moves it to history.
void confirmCloseTeacherSurvey({
  required BuildContext context,
  required TeacherSurvey survey,
  required TeacherRepository teacherRepository,
  required VoidCallback onCompleted,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('¿Finalizar Encuesta?'),
      content: Text(
        'La encuesta para "${survey.cursoNombre}" pasará al Historial de Encuestas y los alumnos ya no podrán registrar ni cambiar respuestas.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Volver'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
          onPressed: () async {
            Navigator.pop(ctx);
            try {
              await teacherRepository.updateSurveyStatus(
                surveyId: survey.id,
                status: 'cerrada',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Encuesta finalizada y movida al historial.'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
              onCompleted();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
            }
          },
          child: const Text('Finalizar'),
        ),
      ],
    ),
  );
}

/// Confirms permanently deleting a survey and its linked responses.
void confirmDeleteTeacherSurvey({
  required BuildContext context,
  required TeacherSurvey survey,
  required TeacherRepository teacherRepository,
  required VoidCallback onCompleted,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(
            Icons.delete_forever_rounded,
            color: AppTheme.errorRed,
            size: 24,
          ),
          SizedBox(width: 8),
          Text(
            '¿Eliminar Encuesta?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: Text(
        '¿Estás seguro de que deseas eliminar permanentemente la encuesta para "${survey.cursoNombre}"? Se borrarán también las respuestas de los alumnos asociados.',
        style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorRed,
            foregroundColor: AppTheme.pureWhite,
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            try {
              await teacherRepository.deleteSurvey(survey.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Encuesta eliminada correctamente.'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
              onCompleted();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar: $e'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
            }
          },
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}
