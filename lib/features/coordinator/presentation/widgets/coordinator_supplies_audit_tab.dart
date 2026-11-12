import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/src/core/utils/responsive.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// Tab auditing supply budget surveys across active courses.
class CoordinatorSuppliesAuditTab extends StatelessWidget {
  const CoordinatorSuppliesAuditTab({
    super.key,
    required this.coordinatorRepository,
  });

  final CoordinatorRepository coordinatorRepository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SurveyAudit>>(
      future: coordinatorRepository.getSurveyAudits(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SurveysSkeleton();
        }
        final encuestas = snapshot.data ?? [];
        if (encuestas.isEmpty) {
          return const Center(
            child: Text('No hay encuestas de insumos registradas.'),
          );
        }

        return Responsive.constrainedContainer(
          maxWidth: 1200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= Responsive.tabletBreakpoint) {
                return GridView.builder(
                  padding: Responsive.screenPadding(context),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 140,
                  ),
                  itemCount: encuestas.length,
                  itemBuilder: (_, idx) => _AuditCard(survey: encuestas[idx]),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 88,
                ),
                itemCount: encuestas.length,
                itemBuilder: (_, idx) => _AuditCard(survey: encuestas[idx]),
              );
            },
          ),
        );
      },
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.survey});

  final SurveyAudit survey;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    survey.cursoNombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Clase: ${survey.fechaClase}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AuditMetric(
                  label: 'Presupuesto Total',
                  value: Formatters.currency(survey.costoTotal),
                ),
                _AuditMetric(
                  label: 'Confirmados',
                  value: '${survey.totalConfirmados}',
                  valueColor: AppTheme.primary,
                ),
                _AuditMetric(
                  label: 'Cuota por Alumno',
                  value: Formatters.currency(survey.montoIndividual),
                  valueColor: AppTheme.successGreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditMetric extends StatelessWidget {
  const _AuditMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
