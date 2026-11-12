import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_receipt_dialogs.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// View displaying student supply-contribution payment history and upload actions.
class StudentPaymentsHistoryView extends StatelessWidget {
  const StudentPaymentsHistoryView({
    super.key,
    required this.future,
    required this.isUploading,
    required this.onRefresh,
    required this.onUploadReceipt,
  });

  final Future<List<StudentPaymentRecord>> future;
  final bool isUploading;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onUploadReceipt;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudentPaymentRecord>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CoursesSkeleton();
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
                  Text('Error cargando historial de pagos: ${snapshot.error}'),
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

        final pagos = snapshot.data ?? [];
        if (pagos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AppTheme.dynamicTextMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no tienes pagos de insumos registrados.',
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

        final verificados = pagos.where((p) => p.isVerificado).length;
        final pendientes = pagos.where((p) => p.isPendiente).length;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PaymentStatChip(
                      label: 'Total Pagos',
                      value: '${pagos.length}',
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaymentStatChip(
                      label: 'Verificados',
                      value: '$verificados',
                      color: AppTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaymentStatChip(
                      label: 'Pendientes',
                      value: '$pendientes',
                      color: AppTheme.warningOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...pagos.map(
                (pago) => _PaymentRecordCard(
                  pago: pago,
                  isUploading: isUploading,
                  onUploadReceipt: () => onUploadReceipt(pago.encuestaId),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaymentStatChip extends StatelessWidget {
  const _PaymentStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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

class _PaymentRecordCard extends StatelessWidget {
  const _PaymentRecordCard({
    required this.pago,
    required this.isUploading,
    required this.onUploadReceipt,
  });

  final StudentPaymentRecord pago;
  final bool isUploading;
  final VoidCallback onUploadReceipt;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = pago.isVerificado
        ? AppTheme.successGreen
        : pago.isRechazado
            ? AppTheme.errorRed
            : AppTheme.warningOrange;
    final hasReceipt =
        pago.comprobanteUrl != null && pago.comprobanteUrl!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pago.cursoNombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
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
                    pago.estadoPago.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Clase: ${pago.fechaClase}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.dynamicTextMuted,
                  ),
                ),
                Text(
                  Formatters.currency(pago.montoCancelado),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            if (pago.comprobanteSubidoAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Comprobante cargado el: ${Formatters.dateTime(pago.comprobanteSubidoAt!)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.dynamicTextMuted,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasReceipt)
                  TextButton.icon(
                    onPressed: () => showStudentReceiptModal(
                      context,
                      url: pago.comprobanteUrl!,
                      title: pago.cursoNombre,
                      subtitle: 'Clase: ${pago.fechaClase}',
                      statusLabel: pago.estadoPago,
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Ver Comprobante'),
                  ),
                if (!pago.isVerificado)
                  OutlinedButton.icon(
                    onPressed: isUploading ? null : onUploadReceipt,
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(
                      hasReceipt ? 'Actualizar Capture' : 'Subir Capture',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
