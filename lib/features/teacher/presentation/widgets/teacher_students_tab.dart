import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_add_student_dialog.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_manage_student_sheet.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_topics_dialog.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// Students roster, retired-trash history, and syllabus-topics management tab.
class TeacherStudentsTab extends StatefulWidget {
  const TeacherStudentsTab({
    super.key,
    required this.teacherRepository,
    required this.teacherName,
    this.isSuperAdmin = false,
  });

  final TeacherRepository teacherRepository;
  final String teacherName;
  final bool isSuperAdmin;

  @override
  State<TeacherStudentsTab> createState() => _TeacherStudentsTabState();
}

class _TeacherStudentsTabState extends State<TeacherStudentsTab> {
  List<TeacherCourse> _cursos = [];
  TeacherCourse? _selectedCurso;
  List<ArchivedStudentEnrollment> _historialAlumnos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCursos();
  }

  Future<void> _loadCursos() async {
    final cursos = await widget.teacherRepository.getMyCourses(
      isSuperAdmin: widget.isSuperAdmin,
    );
    if (!mounted) return;
    setState(() {
      _cursos = cursos;
      if (cursos.isNotEmpty) _selectedCurso = cursos.first;
    });
    if (_selectedCurso != null) {
      await _loadHistorial(_selectedCurso!.id);
    }
  }

  Future<void> _loadHistorial(String cursoId) async {
    setState(() => _isLoading = true);
    final hist = await widget.teacherRepository.getCourseStudentHistory(cursoId);
    if (!mounted) return;
    setState(() {
      _historialAlumnos = hist;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<TeacherCourse>(
                isExpanded: true,
                initialValue: _selectedCurso,
                decoration: const InputDecoration(
                  labelText: 'Curso',
                  prefixIcon: Icon(Icons.school_outlined),
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
                    _loadHistorial(val.id);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _selectedCurso == null
                          ? null
                          : () => showTeacherAddStudentDialog(
                                context: context,
                                course: _selectedCurso!,
                                teacherName: widget.teacherName,
                                teacherRepository: widget.teacherRepository,
                              ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Añadir Alumno',
                          maxLines: 1,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.secondary,
                        side: const BorderSide(color: AppTheme.secondary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _selectedCurso == null
                          ? null
                          : () => showTeacherTopicsDialog(
                                context: context,
                                course: _selectedCurso!,
                                teacherName: widget.teacherName,
                                teacherRepository: widget.teacherRepository,
                              ),
                      icon: const Icon(Icons.topic_outlined, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Gestión Temas',
                          maxLines: 1,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.secondary.withValues(alpha: 0.25),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.pending_actions_rounded,
                size: 16,
                color: AppTheme.secondary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Regla de negocio: Toda acción de modificación (alumnos y temas) queda en estado pendiente y no surtirá efecto hasta recibir aprobación de Coordinación.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const AttendanceSkeleton()
              : _historialAlumnos.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No hay alumnos inscritos en este curso.'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: _historialAlumnos.length,
                      itemBuilder: (context, idx) => _StudentEnrollmentTile(
                        enrollment: _historialAlumnos[idx],
                        onManage: () => showTeacherManageStudentSheet(
                          context: context,
                          course: _selectedCurso!,
                          student: _historialAlumnos[idx],
                          teacherName: widget.teacherName,
                          teacherRepository: widget.teacherRepository,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _StudentEnrollmentTile extends StatelessWidget {
  const _StudentEnrollmentTile({
    required this.enrollment,
    required this.onManage,
  });

  final ArchivedStudentEnrollment enrollment;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final inTrash = enrollment.estaEliminado;
    return Card(
      color:
          inTrash ? AppTheme.surfaceContainerHigh : AppTheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              inTrash ? AppTheme.onSurfaceVariant : AppTheme.primary,
          child: Icon(
            inTrash ? Icons.delete_outline : Icons.person,
            color: AppTheme.onSurface,
          ),
        ),
        title: Text(
          enrollment.nombreCompleto,
          style: TextStyle(
            decoration: inTrash ? TextDecoration.lineThrough : null,
            color: inTrash ? AppTheme.onSurfaceVariant : AppTheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'C.I: ${enrollment.cedula} • Estado: ${inTrash ? "En Papelera / Retirado" : "Activo"}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.tune_rounded, color: AppTheme.primary),
          tooltip: 'Gestionar datos del alumno (Editar / Eliminar)',
          onPressed: onManage,
        ),
      ),
    );
  }
}
