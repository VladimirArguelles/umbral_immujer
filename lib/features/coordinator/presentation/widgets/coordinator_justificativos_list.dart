import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// List of student absence justification requests with approval controls.
class CoordinatorJustificativosList extends StatelessWidget {
  const CoordinatorJustificativosList({
    super.key,
    required this.justificativosFuture,
    required this.repository,
    required this.onReload,
  });

  final Future<List<JustificativoRevisionItem>> justificativosFuture;
  final CoordinatorRepository repository;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JustificativoRevisionItem>>(
      future: justificativosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No hay justificativos de alumnos pendientes de revisión.',
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final j in list)
              _JustificativoCard(
                item: j,
                onReject: () async {
                  await repository.updateJustificativoEstado(j.id, 'rechazado');
                  onReload();
                },
                onApprove: () async {
                  await repository.updateJustificativoEstado(j.id, 'aprobado');
                  onReload();
                },
              ),
          ],
        );
      },
    );
  }
}

class _JustificativoCard extends StatelessWidget {
  const _JustificativoCard({
    required this.item,
    required this.onReject,
    required this.onApprove,
  });

  final JustificativoRevisionItem item;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    var badgeColor = AppTheme.primaryContainer;
    if (item.estado == 'aprobado') {
      badgeColor = AppTheme.successGreen.withValues(alpha: 0.2);
    } else if (item.estado == 'rechazado') {
      badgeColor = AppTheme.errorRed.withValues(alpha: 0.2);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.alumnoNombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.estado.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'C.I: ${item.cedula} • Curso: ${item.cursoNombre}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Fecha de inasistencia: ${item.fecha}',
              style: const TextStyle(fontSize: 12, color: AppTheme.secondary),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Motivo: ${item.motivo}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (item.comprobanteUrl != null &&
                item.comprobanteUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text(
                  'Ver Comprobante Adjunto',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: () =>
                    _showAttachmentDialog(context, item.comprobanteUrl!),
              ),
            ],
            if (item.estado == 'pendiente') ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.errorRed),
                    ),
                    onPressed: onReject,
                    child: const Text(
                      'Rechazar',
                      style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: AppTheme.pureWhite,
                    ),
                    onPressed: onApprove,
                    child: const Text(
                      'Aprobar Justificativo',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAttachmentDialog(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (d) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text(
                'Comprobante Médico / Justificativo',
                style: TextStyle(fontSize: 14),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(d).pop(),
                ),
              ],
            ),
            Image.network(
              url,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No fue posible cargar el comprobante.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
