import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/core/utils/schedule_parser.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/features/coordinator/presentation/pages/asistencia_cursos_page.dart';
import 'package:umbral_immujer/features/coordinator/presentation/pages/ausencias_hoy_page.dart';
import 'package:umbral_immujer/features/coordinator/presentation/pages/cursos_activos_page.dart';
import 'package:umbral_immujer/features/coordinator/presentation/widgets/coordinator_contributions_widgets.dart';
import 'package:umbral_immujer/features/coordinator/presentation/widgets/coordinator_course_card.dart';
import 'package:umbral_immujer/features/coordinator/presentation/widgets/coordinator_course_roster_sheet.dart';
import 'package:umbral_immujer/features/coordinator/presentation/widgets/coordinator_justificativos_list.dart';
import 'package:umbral_immujer/features/coordinator/presentation/widgets/coordinator_notifications_sheet.dart';
import 'package:umbral_immujer/features/superadmin/presentation/gestion_cursos_page.dart';
import 'package:umbral_immujer/features/superadmin/presentation/gestion_profesores_page.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/src/core/widgets/formation_image_carousel.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// Main overview tab for the Coordinator dashboard showing KPIs, courses, and filters.
class CoordinatorCoursesTab extends StatefulWidget {
  const CoordinatorCoursesTab({
    super.key,
    required this.coordinatorRepository,
  });

  final CoordinatorRepository coordinatorRepository;

  @override
  State<CoordinatorCoursesTab> createState() => _CoordinatorCoursesTabState();
}

class _CoordinatorCoursesTabState extends State<CoordinatorCoursesTab> {
  late Future<List<CourseDashboardItem>> _dashboardFuture;
  late Future<List<SolicitudNotificacionItem>> _notificacionesFuture;
  late Future<List<AporteCursoBsItem>> _aportesFuture;
  late Future<List<JustificativoRevisionItem>> _justificativosFuture;
  final String _fechaHoy = Formatters.isoDate(DateTime.now());
  int _filtroDinamicoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    setState(() {
      _dashboardFuture = widget.coordinatorRepository.getCourseDashboard(
        _fechaHoy,
      );
      _notificacionesFuture = widget.coordinatorRepository
          .getPendingApprovalRequests();
      _aportesFuture = widget.coordinatorRepository.getAportesCursosEnBs();
      _justificativosFuture = widget.coordinatorRepository
          .getJustificativosRevision();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_dashboardFuture, _notificacionesFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CoursesSkeleton();
        }

        final cursos = (snapshot.data?[0] as List<CourseDashboardItem>?) ?? [];
        final notificaciones =
            (snapshot.data?[1] as List<SolicitudNotificacionItem>?) ?? [];

        final totalAusencias = cursos.fold<int>(
          0,
          (prev, c) => prev + c.ausenciasHoy,
        );
        final totalPresentes = cursos.fold<int>(
          0,
          (prev, c) => prev + c.presentesHoy,
        );
        final totalMarcadas = totalPresentes + totalAusencias;
        final asistenciaPromedio = totalMarcadas == 0
            ? 100.0
            : (totalPresentes / totalMarcadas) * 100;
        final cursosOperandoAhora = cursos
            .where((c) => ScheduleParser.isCourseActiveNow(c.horario))
            .length;
        final cursosOperandoHoy = cursos.where((c) => c.isActiveToday).length;

        return RefreshIndicator(
          onRefresh: () async => _loadAll(),
          child: ListView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 88,
            ),
            children: [
              const FormationImageCarousel(),
              const SizedBox(height: 16),
              _QuickActionsBar(
                notificaciones: notificaciones,
                onOpenCourses: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const GestionCursosPage(),
                  ),
                ).then((_) => _loadAll()),
                onOpenTeachers: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const GestionProfesoresPage(),
                  ),
                ).then((_) => _loadAll()),
                onOpenNotifications: () => showCoordinatorNotificationsSheet(
                  context,
                  repository: widget.coordinatorRepository,
                  requests: notificaciones,
                  onReload: _loadAll,
                ),
              ),
              const SizedBox(height: 16),
              _KpiRow(
                cursosOperandoAhora: cursosOperandoAhora,
                cursosOperandoHoy: cursosOperandoHoy,
                asistenciaPromedio: asistenciaPromedio,
                totalPresentes: totalPresentes,
                totalAusencias: totalAusencias,
                onOpenActiveCourses: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CursosActivosPage(
                      initialCursos: cursos,
                      coordinatorRepository: widget.coordinatorRepository,
                    ),
                  ),
                ).then((_) => _loadAll()),
                onOpenAttendance: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AsistenciaCursosPage(
                      initialCursos: cursos,
                      coordinatorRepository: widget.coordinatorRepository,
                    ),
                  ),
                ).then((_) => _loadAll()),
                onOpenAbsences: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AusenciasHoyPage(
                      initialCursos: cursos,
                      coordinatorRepository: widget.coordinatorRepository,
                    ),
                  ),
                ).then((_) => _loadAll()),
              ),
              const SizedBox(height: 16),
              CoordinatorContributionsSummaryCard(
                aportesFuture: _aportesFuture,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cursos en Sistema y Tiempo Real',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.dynamicText,
                    ),
                  ),
                  Text(
                    '${cursos.length} cursos',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.dynamicTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (cursos.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No hay cursos registrados en el sistema.'),
                    ),
                  ),
                )
              else
                _CoursesResponsiveList(
                  cursos: cursos,
                  onOpenRoster: (course) => showCoordinatorCourseRosterSheet(
                    context,
                    repository: widget.coordinatorRepository,
                    course: course,
                    onReload: _loadAll,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Supervisión Detallada & Filtros Dinámicos',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text(
                      'Aportes por Curso (Bs)',
                      style: TextStyle(fontSize: 12),
                    ),
                    icon: Icon(Icons.currency_exchange_rounded, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(
                      'Justificativos Alumnos',
                      style: TextStyle(fontSize: 12),
                    ),
                    icon: Icon(Icons.assignment_late_rounded, size: 16),
                  ),
                ],
                selected: {_filtroDinamicoIndex},
                onSelectionChanged: (newSelection) =>
                    setState(() => _filtroDinamicoIndex = newSelection.first),
              ),
              const SizedBox(height: 16),
              if (_filtroDinamicoIndex == 0)
                CoordinatorAportesBsList(aportesFuture: _aportesFuture)
              else
                CoordinatorJustificativosList(
                  justificativosFuture: _justificativosFuture,
                  repository: widget.coordinatorRepository,
                  onReload: _loadAll,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar({
    required this.notificaciones,
    required this.onOpenCourses,
    required this.onOpenTeachers,
    required this.onOpenNotifications,
  });

  final List<SolicitudNotificacionItem> notificaciones;
  final VoidCallback onOpenCourses;
  final VoidCallback onOpenTeachers;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.school_rounded, size: 16),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Gestión Cursos',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryContainer,
              foregroundColor: AppTheme.onPrimaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onOpenCourses,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.badge_rounded, size: 16),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Gestión Profesores',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryContainer,
              foregroundColor: AppTheme.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onOpenTeachers,
          ),
        ),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: notificaciones.isNotEmpty,
          label: Text('${notificaciones.length}'),
          backgroundColor: AppTheme.errorRed,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: IconButton(
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(
                Icons.notifications_active_rounded,
                size: 20,
                color: AppTheme.onTertiaryContainer,
              ),
              tooltip: 'Centro de Notificaciones y Aprobaciones',
              onPressed: onOpenNotifications,
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.cursosOperandoAhora,
    required this.cursosOperandoHoy,
    required this.asistenciaPromedio,
    required this.totalPresentes,
    required this.totalAusencias,
    required this.onOpenActiveCourses,
    required this.onOpenAttendance,
    required this.onOpenAbsences,
  });

  final int cursosOperandoAhora;
  final int cursosOperandoHoy;
  final double asistenciaPromedio;
  final int totalPresentes;
  final int totalAusencias;
  final VoidCallback onOpenActiveCourses;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenAbsences;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          CoordinatorMetricCard(
            title: 'Cursos Activos',
            value: '$cursosOperandoAhora',
            subtitle: '$cursosOperandoHoy programados hoy',
            icon: Icons.calendar_today_rounded,
            color: AppTheme.primary,
            onTap: onOpenActiveCourses,
          ),
          CoordinatorMetricCard(
            title: '% Asistencia',
            value: '${asistenciaPromedio.toStringAsFixed(1)}%',
            subtitle: '$totalPresentes presentes',
            icon: Icons.pie_chart_rounded,
            color: AppTheme.successGreen,
            onTap: onOpenAttendance,
          ),
          CoordinatorMetricCard(
            title: 'Ausencias Hoy',
            value: '$totalAusencias',
            subtitle: totalAusencias > 0 ? 'Alerta activa' : 'Sin faltas',
            icon: Icons.warning_amber_rounded,
            color: totalAusencias > 0
                ? AppTheme.errorRed
                : AppTheme.outlineVariant,
            onTap: onOpenAbsences,
          ),
        ];

        if (constraints.maxWidth < 420) {
          return Column(
            children: [
              for (final card in cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: card,
                ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
            const SizedBox(width: 10),
            Expanded(child: cards[2]),
          ],
        );
      },
    );
  }
}

class _CoursesResponsiveList extends StatelessWidget {
  const _CoursesResponsiveList({
    required this.cursos,
    required this.onOpenRoster,
  });

  final List<CourseDashboardItem> cursos;
  final ValueChanged<CourseDashboardItem> onOpenRoster;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth >= 1050 ? 3 : 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 310,
            ),
            itemCount: cursos.length,
            itemBuilder: (context, index) => CoordinatorCourseCard(
              course: cursos[index],
              onOpenRoster: () => onOpenRoster(cursos[index]),
            ),
          );
        }
        return Column(
          children: [
            for (final c in cursos)
              CoordinatorCourseCard(
                course: c,
                onOpenRoster: () => onOpenRoster(c),
              ),
          ],
        );
      },
    );
  }
}
