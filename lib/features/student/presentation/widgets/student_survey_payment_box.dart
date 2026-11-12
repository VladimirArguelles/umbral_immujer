import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_receipt_dialogs.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Conditional Pago Móvil details and receipt upload section inside an active survey card.
class StudentSurveyPaymentBox extends StatelessWidget {
  const StudentSurveyPaymentBox({
    super.key,
    required this.survey,
    required this.isUploading,
    required this.onUploadPressed,
  });

  final StudentSurvey survey;
  final bool isUploading;
  final VoidCallback onUploadPressed;

  @override
  Widget build(BuildContext context) {
    if (survey.asistira == false) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.dynamicBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: AppTheme.dynamicTextMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Indicaste que no podrás asistir a esta clase, por lo que no corresponde aporte de insumos.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.dynamicTextMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (survey.asistira == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warningOrange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.warningOrange.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.touch_app_rounded, size: 18, color: AppTheme.warningOrange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirma primero tu asistencia arriba para ver los datos de Pago Móvil y adjuntar tu comprobante.',
                style: TextStyle(fontSize: 12, color: AppTheme.warningOrange),
              ),
            ),
          ],
        ),
      );
    }

    final hasReceipt =
        survey.comprobanteUrl != null && survey.comprobanteUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((survey.pagoMovilBanco ?? '').isNotEmpty ||
            (survey.pagoMovilTelefono ?? '').isNotEmpty ||
            (survey.pagoMovilCedula ?? '').isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.dynamicBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.dynamicBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DATOS DE PAGO MÓVIL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                if ((survey.pagoMovilBanco ?? '').isNotEmpty)
                  Text(
                    'Banco: ${survey.pagoMovilBanco}',
                    style: const TextStyle(fontSize: 13),
                  ),
                if ((survey.pagoMovilTelefono ?? '').isNotEmpty)
                  Text(
                    'Teléfono: ${survey.pagoMovilTelefono}',
                    style: const TextStyle(fontSize: 13),
                  ),
                if ((survey.pagoMovilCedula ?? '').isNotEmpty)
                  Text(
                    'Cédula / RIF: ${survey.pagoMovilCedula}',
                    style: const TextStyle(fontSize: 13),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!hasReceipt)
          ElevatedButton.icon(
            onPressed: isUploading ? null : onUploadPressed,
            icon: isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(
              isUploading ? 'SUBIENDO CAPTURE...' : 'SUBIR CAPTURE DE PAGO',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
        else
          _AttachedReceiptBox(
            survey: survey,
            isUploading: isUploading,
            onUploadPressed: onUploadPressed,
          ),
      ],
    );
  }
}

class _AttachedReceiptBox extends StatelessWidget {
  const _AttachedReceiptBox({
    required this.survey,
    required this.isUploading,
    required this.onUploadPressed,
  });

  final StudentSurvey survey;
  final bool isUploading;
  final VoidCallback onUploadPressed;

  @override
  Widget build(BuildContext context) {
    final estado = (survey.estadoPago ?? 'pendiente').toLowerCase();
    final Color badgeColor = estado == 'verificado'
        ? AppTheme.successGreen
        : estado == 'rechazado'
            ? AppTheme.errorRed
            : AppTheme.warningOrange;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              survey.comprobanteUrl!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.receipt_long,
                size: 36,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capture Adjunto',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.dynamicText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Estado: ${estado.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showStudentReceiptModal(
              context,
              url: survey.comprobanteUrl!,
              title: survey.cursoNombre,
              subtitle: 'Clase: ${survey.fechaClase}',
              statusLabel: survey.estadoPago,
            ),
            child: const Text('Ver'),
          ),
          TextButton(
            onPressed: isUploading ? null : onUploadPressed,
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }
}
