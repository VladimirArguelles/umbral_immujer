import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Displays an uploaded payment receipt image inside a centered modal dialog.
void showTeacherPaymentProofDialog(
  BuildContext context,
  String url, {
  String title = 'Comprobante de Pago',
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Text(title, style: const TextStyle(fontSize: 16)),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stack) => const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No se pudo cargar la imagen del capture'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shows confirmed student payments for a survey and allows teacher verification.
void showTeacherSurveyPaymentsAuditDialog({
  required BuildContext context,
  required TeacherSurvey survey,
  required TeacherRepository teacherRepository,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => _SurveyPaymentsAuditDialog(
      survey: survey,
      teacherRepository: teacherRepository,
    ),
  );
}

class _SurveyPaymentsAuditDialog extends StatefulWidget {
  const _SurveyPaymentsAuditDialog({
    required this.survey,
    required this.teacherRepository,
  });

  final TeacherSurvey survey;
  final TeacherRepository teacherRepository;

  @override
  State<_SurveyPaymentsAuditDialog> createState() =>
      _SurveyPaymentsAuditDialogState();
}

class _SurveyPaymentsAuditDialogState
    extends State<_SurveyPaymentsAuditDialog> {
  late Future<List<PaymentAuditItem>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _paymentsFuture =
        widget.teacherRepository.getSurveyPayments(widget.survey.id);
  }

  Future<void> _approvePayment(PaymentAuditItem item) async {
    await widget.teacherRepository.updatePaymentStatus(
      responseId: item.respuestaId,
      status: 'verificado',
    );
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: FutureBuilder<List<PaymentAuditItem>>(
          future: _paymentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final items = snapshot.data ?? [];
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auditoría de Pagos • ${widget.survey.cursoNombre}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${items.length} alumnos confirmaron asistencia',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (items.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Aún no hay alumnos confirmados en esta encuesta.',
                          style: TextStyle(color: AppTheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _AuditRowTile(
                          item: items[i],
                          onViewProof: () => showTeacherPaymentProofDialog(
                            context,
                            items[i].comprobanteUrl!,
                          ),
                          onApprove: () => _approvePayment(items[i]),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuditRowTile extends StatelessWidget {
  const _AuditRowTile({
    required this.item,
    required this.onViewProof,
    required this.onApprove,
  });

  final PaymentAuditItem item;
  final VoidCallback onViewProof;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final isVerificado = item.estadoPago == 'verificado';
    final badgeColor = isVerificado ? AppTheme.successGreen : AppTheme.errorRed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.nombreCompleto,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.estadoPago.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 11.5,
                color: AppTheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(text: 'Cédula: ${item.cedula} • Cuota: Bs. '),
                TextSpan(
                  text: item.monto.toStringAsFixed(2),
                  style: const TextStyle(color: AppTheme.successGreen),
                ),
              ],
            ),
          ),
          if (item.comprobanteUrl != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_rounded, size: 14),
                  label: const Text(
                    'Ver Comprobante',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onViewProof,
                ),
                const SizedBox(width: 8),
                if (!isVerificado)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onApprove,
                    child: const Text('Aprobar', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
