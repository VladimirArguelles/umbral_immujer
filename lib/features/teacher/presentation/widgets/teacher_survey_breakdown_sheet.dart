import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';

/// Modal para visualizar el desglose detallado de respuestas de una encuesta:
/// Alumnos afirmativos, negativos y faltantes por responder, junto con una barra de progreso.
Future<void> showTeacherSurveyBreakdownModal({
  required BuildContext context,
  required TeacherRepository teacherRepository,
  required String surveyId,
  String? surveyTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.dynamicCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (modalCtx) => _TeacherSurveyBreakdownContent(
      teacherRepository: teacherRepository,
      surveyId: surveyId,
      surveyTitle: surveyTitle,
    ),
  );
}

class _TeacherSurveyBreakdownContent extends StatefulWidget {
  const _TeacherSurveyBreakdownContent({
    required this.teacherRepository,
    required this.surveyId,
    this.surveyTitle,
  });

  final TeacherRepository teacherRepository;
  final String surveyId;
  final String? surveyTitle;

  @override
  State<_TeacherSurveyBreakdownContent> createState() =>
      _TeacherSurveyBreakdownContentState();
}

class _TeacherSurveyBreakdownContentState
    extends State<_TeacherSurveyBreakdownContent> {
  SurveyResponseBreakdown? _breakdown;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedFilter = 0; // 0: Todos, 1: Pendientes, 2: Afirmativos, 3: Negativos

  @override
  void initState() {
    super.initState();
    _loadBreakdown();
  }

  Future<void> _loadBreakdown() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.teacherRepository.getSurveyDetailedBreakdown(
        widget.surveyId,
      );
      if (!mounted) return;
      setState(() {
        _breakdown = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo cargar el desglose de la encuesta: $e';
        _isLoading = false;
      });
    }
  }

  void _copyPendingNames(List<SurveyStudentResponseItem> pending) {
    if (pending.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('📋 Alumnos pendientes por responder la encuesta:');
    for (final s in pending) {
      buffer.writeln('• ${s.nombreCompleto} (C.I. ${s.cedula})');
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
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        if (_isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (_errorMessage != null) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.errorRed,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.dynamicText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadBreakdown,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        final breakdown = _breakdown!;
        final fechaDate = DateTime.tryParse(breakdown.fechaClase);
        final fechaClaseStr = fechaDate != null
            ? Formatters.date(fechaDate)
            : breakdown.fechaClase;

        List<SurveyStudentResponseItem> visibleStudents;
        switch (_selectedFilter) {
          case 1:
            visibleStudents = breakdown.alumnosPendientes;
            break;
          case 2:
            visibleStudents = breakdown.alumnosAfirmativos;
            break;
          case 3:
            visibleStudents = breakdown.alumnosNegativos;
            break;
          default:
            visibleStudents = [
              ...breakdown.alumnosPendientes,
              ...breakdown.alumnosAfirmativos,
              ...breakdown.alumnosNegativos,
            ];
            break;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra indicadora de arrastre
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.dynamicBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Cabecera del modal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.poll_rounded,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalle de Respuestas',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.dynamicText,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${breakdown.cursoNombre} • Práctica: $fechaClaseStr',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.dynamicTextMuted,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppTheme.dynamicTextMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Widget de Barra de Progreso y Métricas
              _SurveyProgressBarCard(
                breakdown: breakdown,
                onCopyPending: () =>
                    _copyPendingNames(breakdown.alumnosPendientes),
              ),
              const SizedBox(height: 14),

              // Filtros de navegación rápida
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todos (${breakdown.totalInscritos})',
                      isSelected: _selectedFilter == 0,
                      onTap: () => setState(() => _selectedFilter = 0),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pendientes (${breakdown.totalPendientes})',
                      isSelected: _selectedFilter == 1,
                      badgeColor: AppTheme.errorRed,
                      onTap: () => setState(() => _selectedFilter = 1),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Confirmados (${breakdown.alumnosAfirmativos.length})',
                      isSelected: _selectedFilter == 2,
                      badgeColor: AppTheme.mintNeon,
                      onTap: () => setState(() => _selectedFilter = 2),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'No asistirán (${breakdown.alumnosNegativos.length})',
                      isSelected: _selectedFilter == 3,
                      badgeColor: AppTheme.warningOrange,
                      onTap: () => setState(() => _selectedFilter = 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Listado de Alumnos
              Expanded(
                child: visibleStudents.isEmpty
                    ? Center(
                        child: Text(
                          'No hay alumnos en esta categoría.',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.dynamicTextMuted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: visibleStudents.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final student = visibleStudents[idx];
                          return _StudentResponseTile(student: student);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tarjeta destacada con barra de progreso y conteo de alumnos pendientes vs respondidos
class _SurveyProgressBarCard extends StatelessWidget {
  const _SurveyProgressBarCard({
    required this.breakdown,
    required this.onCopyPending,
  });

  final SurveyResponseBreakdown breakdown;
  final VoidCallback onCopyPending;

  @override
  Widget build(BuildContext context) {
    final int total = breakdown.totalInscritos;
    final int respondieron = breakdown.totalRespondieron;
    final int pendientes = breakdown.totalPendientes;
    final int afirmativos = breakdown.alumnosAfirmativos.length;
    final int negativos = breakdown.alumnosNegativos.length;

    final double pctAfirmativos = total > 0 ? (afirmativos / total) : 0.0;
    final double pctNegativos = total > 0 ? (negativos / total) : 0.0;
    final double pctPendientes = total > 0 ? (pendientes / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dynamicSurfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dynamicBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: AppTheme.mintNeon,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Progreso de Respuestas',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.dynamicText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (pendientes > 0
                          ? AppTheme.errorRed
                          : AppTheme.mintNeon)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$respondieron / $total Respondieron',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: pendientes > 0
                        ? AppTheme.errorRed
                        : AppTheme.mintNeon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Barra de progreso segmentada personalizada
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (pctAfirmativos > 0)
                    Flexible(
                      flex: (pctAfirmativos * 100).round().clamp(1, 100),
                      child: Container(color: AppTheme.mintNeon),
                    ),
                  if (pctNegativos > 0)
                    Flexible(
                      flex: (pctNegativos * 100).round().clamp(1, 100),
                      child: Container(color: AppTheme.warningOrange),
                    ),
                  if (pctPendientes > 0)
                    Flexible(
                      flex: (pctPendientes * 100).round().clamp(1, 100),
                      child: Container(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Callout de alumnos pendientes
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.errorRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Pendientes por responder: $pendientes alumnos (${breakdown.porcentajePendientes.toStringAsFixed(0)}%)',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.dynamicTextMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (pendientes > 0)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onCopyPending,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.copy_rounded,
                          size: 13,
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
        ],
      ),
    );
  }
}

/// Fila individual con avatar y datos del alumno
class _StudentResponseTile extends StatelessWidget {
  const _StudentResponseTile({required this.student});

  final SurveyStudentResponseItem student;

  @override
  Widget build(BuildContext context) {
    Color statusBg;
    Color statusFg;
    IconData statusIcon;
    String statusLabel;

    if (student.asistira == true) {
      statusBg = AppTheme.mintNeon.withValues(alpha: 0.15);
      statusFg = AppTheme.mintNeon;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'ASISTIRÁ';
    } else if (student.asistira == false) {
      statusBg = AppTheme.errorRed.withValues(alpha: 0.15);
      statusFg = AppTheme.errorRed;
      statusIcon = Icons.cancel_rounded;
      statusLabel = 'NO ASISTIRÁ';
    } else {
      statusBg = AppTheme.primary.withValues(alpha: 0.12);
      statusFg = AppTheme.primary;
      statusIcon = Icons.pending_rounded;
      statusLabel = 'PENDIENTE';
    }

    final initials = student.nombreCompleto.isNotEmpty
        ? student.nombreCompleto
            .trim()
            .split(' ')
            .take(2)
            .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
            .join()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.dynamicSurfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: student.asistira == null
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.dynamicBorder,
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: statusFg.withValues(alpha: 0.18),
            child: Text(
              initials,
              style: TextStyle(
                color: statusFg,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.nombreCompleto,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.dynamicText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'C.I. ${student.cedula}${student.telefono != null && student.telefono!.isNotEmpty ? " • ${student.telefono}" : ""}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.dynamicTextMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusFg, size: 13),
                const SizedBox(width: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusFg,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de filtrado rápido
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.badgeColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color? badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (badgeColor ?? AppTheme.primary).withValues(alpha: 0.2)
              : AppTheme.dynamicSurfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (badgeColor ?? AppTheme.primary)
                : AppTheme.dynamicBorder,
            width: 1.1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (badgeColor ?? AppTheme.primary)
                : AppTheme.dynamicTextMuted,
          ),
        ),
      ),
    );
  }
}
