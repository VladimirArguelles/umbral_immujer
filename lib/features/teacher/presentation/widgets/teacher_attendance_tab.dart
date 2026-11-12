import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/teacher/data/attendance_offline_service.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// Daily attendance-taking tab with offline queue support and batch mark-present.
class TeacherAttendanceTab extends StatefulWidget {
  const TeacherAttendanceTab({
    super.key,
    required this.teacherRepository,
    this.isSuperAdmin = false,
  });

  final TeacherRepository teacherRepository;
  final bool isSuperAdmin;

  @override
  State<TeacherAttendanceTab> createState() => _TeacherAttendanceTabState();
}

class _TeacherAttendanceTabState extends State<TeacherAttendanceTab> {
  List<TeacherCourse> _cursos = [];
  TeacherCourse? _selectedCurso;
  final String _fechaSeleccionada = Formatters.isoDate(DateTime.now());
  List<StudentAttendanceItem> _alumnos = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCursos();
  }

  Future<void> _loadCursos() async {
    setState(() => _isLoading = true);
    final cursos = await widget.teacherRepository.getMyCourses(
      isSuperAdmin: widget.isSuperAdmin,
    );
    if (!mounted) return;
    setState(() {
      _cursos = cursos;
      if (cursos.isNotEmpty) _selectedCurso = cursos.first;
      _isLoading = false;
    });
    if (_selectedCurso != null) {
      await _loadAlumnosParaLista(_selectedCurso!.id);
    }
  }

  Future<void> _loadAlumnosParaLista(String cursoId) async {
    setState(() => _isLoading = true);
    final lista = await widget.teacherRepository.getStudentsForAttendance(
      courseId: cursoId,
      date: _fechaSeleccionada,
    );
    if (!mounted) return;
    setState(() {
      _alumnos = lista;
      _isLoading = false;
    });
  }

  void _marcarTodosComoPresentes() {
    setState(() {
      for (final a in _alumnos) {
        a.estadoAsistencia = 'Presente';
      }
    });
  }

  void _toggleAsistencia(StudentAttendanceItem alumno) {
    setState(() {
      alumno.estadoAsistencia = alumno.isPresente ? 'Ausente' : 'Presente';
    });
  }

  Future<void> _guardarAsistencia() async {
    if (_selectedCurso == null) return;
    setState(() => _isSaving = true);
    try {
      final result = await widget.teacherRepository.saveAttendance(
        courseId: _selectedCurso!.id,
        date: _fechaSeleccionada,
        students: _alumnos,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.isOffline ? Icons.cloud_off : Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(result.message)),
            ],
          ),
          backgroundColor:
              result.isOffline ? const Color(0xFFE65100) : AppTheme.successGreen,
          duration: Duration(seconds: result.isOffline ? 5 : 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar asistencia: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _cursos.isEmpty) return const AttendanceSkeleton();

    if (_cursos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No tienes cursos asignados actualmente. Contacta al coordinador de IMMUJER.',
          ),
        ),
      );
    }

    final presentesCount = _alumnos.where((a) => a.isPresente).length;
    final ausentesCount = _alumnos.where((a) => !a.isPresente).length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: AppTheme.surfaceContainerLow,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TeacherCourse>(
                      isExpanded: true,
                      initialValue: _selectedCurso,
                      decoration: const InputDecoration(
                        labelText: 'Curso',
                        prefixIcon: Icon(Icons.class_outlined),
                      ),
                      selectedItemBuilder: (context) => _cursos
                          .map(
                            (c) => Text(
                              c.nombre,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                          .toList(),
                      items: _cursos
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c.nombre,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCurso = val);
                          _loadAlumnosParaLista(val.id);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.today,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _fechaSeleccionada,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Presentes: $presentesCount | Ausentes: $ausentesCount',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: OutlinedButton.icon(
                      onPressed:
                          _alumnos.isEmpty ? null : _marcarTodosComoPresentes,
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Todos Presentes',
                          maxLines: 1,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _OfflineSyncBanner(
                onSync: widget.teacherRepository.syncPendingOfflineAttendance,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _alumnos.isEmpty
                  ? const Center(
                      child: Text('No hay alumnos inscritos en este curso.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 88,
                      ),
                      itemCount: _alumnos.length,
                      itemBuilder: (context, idx) => _StudentAttendanceCard(
                        student: _alumnos[idx],
                        onToggle: () => _toggleAsistencia(_alumnos[idx]),
                      ),
                    ),
        ),
        Container(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 84,
          ),
          color: AppTheme.dynamicCard,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _guardarAsistencia,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: AppTheme.onSurface,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('Confirmar y Guardar Asistencia'),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineSyncBanner extends StatelessWidget {
  const _OfflineSyncBanner({required this.onSync});

  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AttendanceOfflineService.instance.pendingCountNotifier,
      builder: (context, pendingCount, _) {
        if (pendingCount == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFB74D)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.sync_problem,
                color: Color(0xFFE65100),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$pendingCount asistencia(s) pendiente(s) de sincronizar',
                  style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSync,
                child: const Text(
                  'Sincronizar ahora',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  const _StudentAttendanceCard({
    required this.student,
    required this.onToggle,
  });

  final StudentAttendanceItem student;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              student.isPresente ? AppTheme.successGreen : AppTheme.errorRed,
          child: Icon(
            student.isPresente ? Icons.check : Icons.close,
            color: AppTheme.onTertiary,
          ),
        ),
        title: Text(
          student.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('C.I: ${student.cedula} • Tel: ${student.telefono ?? "N/A"}'),
            if (student.confirmoEncuesta == true) ...[
              const SizedBox(height: 2),
              Text(
                'Encuesta: Confirmó asistencia (${student.estadoPago ?? "Sin pago"})',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        trailing: Switch(
          value: student.isPresente,
          activeThumbColor: AppTheme.successGreen,
          inactiveThumbColor: AppTheme.errorRed,
          onChanged: (_) => onToggle(),
        ),
        onTap: onToggle,
      ),
    );
  }
}
