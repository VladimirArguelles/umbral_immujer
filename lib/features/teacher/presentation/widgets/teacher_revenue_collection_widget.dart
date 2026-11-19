import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';

/// Widget de balance de recaudación para el módulo de Profesores.
/// Refleja cuántos alumnos han cancelado de los que respondieron afirmativamente la encuesta,
/// cuántos faltan por cancelar y los nombres completos de los que aún no han cancelado.
class TeacherRevenueCollectionSummaryCard extends StatelessWidget {
  const TeacherRevenueCollectionSummaryCard({
    super.key,
    required this.recaudacion,
    this.surveyLabel,
  });

  final List<PaymentAuditItem> recaudacion;
  final String? surveyLabel;

  void _copyPendingNames(
    BuildContext context,
    List<PaymentAuditItem> pending,
  ) {
    if (pending.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('📋 Alumnos pendientes por cancelar su aporte:');
    for (final s in pending) {
      buffer.writeln(
        '• ${s.nombreCompleto} (C.I. ${s.cedula}) - Monto: ${Formatters.currency(s.monto)}',
      );
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Nombres de alumnos pendientes copiados al portapapeles.'),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalAfirmativos = recaudacion.length;
    final List<PaymentAuditItem> cancelados = recaudacion.where((item) {
      final hasReceipt =
          item.comprobanteUrl != null && item.comprobanteUrl!.trim().isNotEmpty;
      return hasReceipt || item.estadoPago == 'verificado';
    }).toList();

    final List<PaymentAuditItem> faltanPorCancelar = recaudacion.where((item) {
      final hasReceipt =
          item.comprobanteUrl != null && item.comprobanteUrl!.trim().isNotEmpty;
      return !hasReceipt && item.estadoPago != 'verificado';
    }).toList();

    final double porcentajeCancelado = totalAfirmativos > 0
        ? (cancelados.length / totalAfirmativos).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: faltanPorCancelar.isNotEmpty
              ? AppTheme.warningOrange.withValues(alpha: 0.35)
              : AppTheme.mintNeon.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título y encabezado
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.mintNeon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.mintNeon,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen de Recaudación',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Alumnos que respondieron afirmativamente a la encuesta',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicTextMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tarjetas métricas (Confirmados, Cancelados, Pendientes)
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  label: 'Confirmados (Sí)',
                  value: '$totalAfirmativos',
                  color: AppTheme.primary,
                  icon: Icons.how_to_reg_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBox(
                  label: 'Han Cancelado',
                  value: '${cancelados.length}',
                  color: AppTheme.mintNeon,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBox(
                  label: 'Faltan por Cancelar',
                  value: '${faltanPorCancelar.length}',
                  color: faltanPorCancelar.isNotEmpty
                      ? AppTheme.warningOrange
                      : AppTheme.dynamicTextMuted,
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barra de progreso de recaudación
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progreso de Aportes Cancelados',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.dynamicTextMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(porcentajeCancelado * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.mintNeon,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: porcentajeCancelado,
                  minHeight: 8,
                  backgroundColor:
                      AppTheme.primaryContainer.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.mintNeon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sección de los alumnos que faltan por cancelar
          if (faltanPorCancelar.isEmpty && totalAfirmativos > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.mintNeon.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.mintNeon.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: AppTheme.mintNeon,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¡Excelente! Todos los alumnos confirmados han cancelado su aporte.',
                      style: TextStyle(
                        color: AppTheme.mintNeon,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (faltanPorCancelar.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.dynamicSurfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.warningOrange.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_search_rounded,
                        color: AppTheme.warningOrange,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Alumnos pendientes por cancelar (${faltanPorCancelar.length})',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.dynamicText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () =>
                            _copyPendingNames(context, faltanPorCancelar),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Copiar',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Lista con los nombres de los que aún no han cancelado
                  Column(
                    children: faltanPorCancelar.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppTheme.warningOrange
                                  .withValues(alpha: 0.18),
                              child: Text(
                                item.nombreCompleto.isNotEmpty
                                    ? item.nombreCompleto[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  color: AppTheme.warningOrange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.nombreCompleto,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.dynamicText,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'C.I. ${item.cedula} • ${Formatters.currency(item.monto)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.dynamicTextMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warningOrange
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PENDIENTE',
                                style: TextStyle(
                                  color: AppTheme.warningOrange,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.dynamicSurfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.dynamicTextMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
