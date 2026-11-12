import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';

/// Opens the bottom sheet for reviewing pending teacher approval requests.
Future<void> showCoordinatorNotificationsSheet(
  BuildContext context, {
  required CoordinatorRepository repository,
  required List<SolicitudNotificacionItem> requests,
  required VoidCallback onReload,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Centro de Notificaciones y Aprobaciones',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      Text(
                        '${requests.length} gestiones docentes pendientes de revisión',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            if (requests.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No hay notificaciones ni gestiones pendientes.',
                    style: TextStyle(color: AppTheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _ApprovalRequestCard(
                    item: requests[index],
                    onReject: () => _handleReject(
                      parentContext: context,
                      sheetContext: sheetCtx,
                      repository: repository,
                      item: requests[index],
                      onReload: onReload,
                    ),
                    onApprove: () async {
                      await repository.approveApprovalRequest(
                        requests[index].id,
                        observacion: 'Aprobado por Coordinación',
                      );
                      if (!sheetCtx.mounted) return;
                      Navigator.of(sheetCtx).pop();
                      onReload();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Solicitud aprobada y aplicada con éxito.',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _handleReject({
  required BuildContext parentContext,
  required BuildContext sheetContext,
  required CoordinatorRepository repository,
  required SolicitudNotificacionItem item,
  required VoidCallback onReload,
}) async {
  final obsCtrl = TextEditingController();
  final confirmar = await showDialog<bool>(
    context: parentContext,
    builder: (dCtx) => AlertDialog(
      title: const Text('Rechazar Solicitud'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Indique la razón u observación del rechazo:'),
          const SizedBox(height: 8),
          TextField(
            controller: obsCtrl,
            decoration: const InputDecoration(
              hintText: 'Motivo del rechazo',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dCtx).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dCtx).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
          child: const Text('Rechazar'),
        ),
      ],
    ),
  );
  final reason = obsCtrl.text.trim();
  obsCtrl.dispose();

  if (confirmar == true) {
    await repository.rejectApprovalRequest(item.id, observacion: reason);
    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
    onReload();
    if (!parentContext.mounted) return;
    ScaffoldMessenger.of(parentContext).showSnackBar(
      const SnackBar(content: Text('Solicitud rechazada.')),
    );
  }
}

class _ApprovalRequestCard extends StatelessWidget {
  const _ApprovalRequestCard({
    required this.item,
    required this.onReject,
    required this.onApprove,
  });

  final SolicitudNotificacionItem item;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.tipoLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                Formatters.date(item.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Profesor: ${item.profesorNombre}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            'Curso: ${item.cursoNombre}',
            style: const TextStyle(fontSize: 12, color: AppTheme.primary),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.datosNuevos.entries.map((e) => '${e.key}: ${e.value}').join('\n')}${item.motivo != null ? '\nMotivo: ${item.motivo}' : ''}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.errorRed,
                ),
                label: const Text(
                  'Rechazar',
                  style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorRed),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                onPressed: onReject,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Aprobar', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: AppTheme.pureWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                ),
                onPressed: onApprove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
