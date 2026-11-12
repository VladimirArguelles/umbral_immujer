import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:umbral_immujer/features/student/data/student_repository.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_attendance_cards.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_justify_absence_sheet.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// Attendance tracking and medical justification tab for a student.
class StudentAttendanceTab extends StatefulWidget {
  const StudentAttendanceTab({
    super.key,
    required this.studentRepository,
    this.isSuperAdmin = false,
  });

  final StudentRepository studentRepository;
  final bool isSuperAdmin;

  @override
  State<StudentAttendanceTab> createState() => _StudentAttendanceTabState();
}

class _StudentAttendanceTabState extends State<StudentAttendanceTab> {
  List<StudentCourse> _misCursos = [];
  StudentCourse? _selectedCurso;
  AttendanceSummary? _resumen;
  List<JustificativoAsistencia> _justificativos = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final cursos = await widget.studentRepository.getMyCourses(
        statusFilter: 'activo',
        isSuperAdmin: widget.isSuperAdmin,
      );
      if (cursos.isNotEmpty) {
        _misCursos = cursos;
        _selectedCurso = cursos.first;
        await _loadAttendance(_selectedCurso!.id);
      } else {
        setState(() {
          _misCursos = [];
          _selectedCurso = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando cursos: $e')),
        );
      }
    }
  }

  Future<void> _loadAttendance(String cursoId) async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        widget.studentRepository.getAttendanceByCourse(cursoId),
        widget.studentRepository.getJustificativos(cursoId: cursoId),
      ]);
      if (!mounted) return;
      setState(() {
        _resumen = results[0] as AttendanceSummary;
        _justificativos = results[1] as List<JustificativoAsistencia>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener asistencias: $e')),
      );
    }
  }

  Future<void> _openJustifyModal({String? fechaPreseleccionada}) async {
    if (_selectedCurso == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentJustifyAbsenceSheet(
        curso: _selectedCurso!,
        initialFecha: fechaPreseleccionada,
        studentRepository: widget.studentRepository,
        picker: _picker,
        onSubmitted: () => _loadAttendance(_selectedCurso!.id),
      ),
    );
  }

  void _viewProofImage(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  JustificativoAsistencia? _justificationForDate(String fecha) {
    for (final j in _justificativos) {
      if (j.fecha == fecha) return j;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _misCursos.isEmpty) {
      return const AttendanceSkeleton();
    }

    if (_misCursos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Debes estar inscrito en un curso activo para consultar tu asistencia.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.dynamicTextMuted, fontSize: 16),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedCurso != null) {
          await _loadAttendance(_selectedCurso!.id);
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          DropdownButtonFormField<StudentCourse>(
            initialValue: _selectedCurso,
            decoration: InputDecoration(
              labelText: 'Seleccionar Curso',
              prefixIcon: const Icon(Icons.school_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppTheme.dynamicCard,
            ),
            items: _misCursos
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.nombre, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (curso) {
              if (curso != null && curso.id != _selectedCurso?.id) {
                setState(() => _selectedCurso = curso);
                _loadAttendance(curso.id);
              }
            },
          ),
          const SizedBox(height: 16),
          _JustifyAbsenceCta(onTap: () => _openJustifyModal()),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_resumen != null) ...[
            if (_resumen!.tieneAlertaDosAusencias) ...[
              const _TwoAbsencesWarningBanner(),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: StudentAttendanceMetricCard(
                    title: 'Clases Totales',
                    value: '${_resumen!.totalClases}',
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StudentAttendanceMetricCard(
                    title: 'Presente',
                    value: '${_resumen!.presentes}',
                    color: AppTheme.successGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StudentAttendanceMetricCard(
                    title: 'Inasistencias',
                    value: '${_resumen!.inasistencias}',
                    color: _resumen!.inasistencias >= 2
                        ? AppTheme.errorRed
                        : AppTheme.warningOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Historial de Asistencia',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_resumen!.historial.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text(
                    'Aún no hay registros de asistencia en este curso.',
                    style: TextStyle(color: AppTheme.dynamicTextMuted),
                  ),
                ),
              )
            else
              ..._resumen!.historial.map(
                (record) => StudentAttendanceHistoryCard(
                  record: record,
                  justification: _justificationForDate(record.fecha),
                  onJustifyDate: (fecha) =>
                      _openJustifyModal(fechaPreseleccionada: fecha),
                  onViewProof: _viewProofImage,
                ),
              ),
          ],
          if (_justificativos.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Historial de Justificativos Médicos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._justificativos.map(
              (j) => StudentJustificationCard(
                justification: j,
                onViewProof: _viewProofImage,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JustifyAbsenceCta extends StatelessWidget {
  const _JustifyAbsenceCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.secondary.withValues(alpha: 0.9)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Justificar Ausencia Médica',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Envía el motivo y adjunta tu récipe o soporte',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TwoAbsencesWarningBanner extends StatelessWidget {
  const _TwoAbsencesWarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.errorRed, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.errorRed,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ATENCIÓN: 2 INASISTENCIAS',
                  style: TextStyle(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tienes 2 o más inasistencias registradas. Comunícate con Coordinación o envía tu justificativo médico.',
                  style: TextStyle(
                    color: AppTheme.dynamicText,
                    fontSize: 13,
                    height: 1.4,
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
