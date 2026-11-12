import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';

/// Global consolidated contributions summary card in Bolívares and USD.
class CoordinatorContributionsSummaryCard extends StatelessWidget {
  const CoordinatorContributionsSummaryCard({
    super.key,
    required this.aportesFuture,
  });

  final Future<List<AporteCursoBsItem>> aportesFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AporteCursoBsItem>>(
      future: aportesFuture,
      builder: (context, snapshot) {
        final aportes = snapshot.data ?? [];
        final granTotalBs = aportes.fold<double>(
          0.0,
          (prev, a) => prev + a.totalAporteBs,
        );
        final granTotalUsd = aportes.fold<double>(
          0.0,
          (prev, a) => prev + a.costoTotalUsd,
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monto Total de Aportes por Cursos',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.dynamicText,
                          ),
                        ),
                        Text(
                          'Recaudación global consolidada en Bolívares (Tasa Oficial BCV)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppTheme.dynamicTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bs. ${Formatters.currency(granTotalBs)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.mintNeon,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '~ \$${granTotalUsd.toStringAsFixed(2)} USD',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ),
                ],
              ),
              if (aportes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final a in aportes)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          '${a.cursoNombre}: Bs. ${Formatters.currency(a.totalAporteBs)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Detailed list of per-course supply contributions calculated in Bolívares.
class CoordinatorAportesBsList extends StatelessWidget {
  const CoordinatorAportesBsList({super.key, required this.aportesFuture});

  final Future<List<AporteCursoBsItem>> aportesFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AporteCursoBsItem>>(
      future: aportesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final aportes = snapshot.data ?? [];
        if (aportes.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No hay aportes ni encuestas registradas para cálculo en Bolívares.',
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final a in aportes)
              Card(
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
                              a.cursoNombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Clase: ${a.fechaClase}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Costo Insumos: \$${a.costoTotalUsd.toStringAsFixed(2)} USD',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Tasa BCV: ${a.tasaBcvUsada.toStringAsFixed(2)} Bs/USD',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Alumnos Confirmados: ${a.totalConfirmados}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Divider(height: 16),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          Text(
                            'Cuota por Alumno: Bs. ${Formatters.currency(a.cuotaBs)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.successGreen,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Total: Bs. ${Formatters.currency(a.totalAporteBs)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.successGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
