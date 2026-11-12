import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Opens a bottom sheet to request edits or withdrawal of an enrolled student.
void showTeacherManageStudentSheet({
  required BuildContext context,
  required TeacherCourse course,
  required ArchivedStudentEnrollment student,
  required String teacherName,
  required TeacherRepository teacherRepository,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TeacherManageStudentSheet(
      course: course,
      student: student,
      teacherName: teacherName,
      teacherRepository: teacherRepository,
    ),
  );
}

class _TeacherManageStudentSheet extends StatefulWidget {
  const _TeacherManageStudentSheet({
    required this.course,
    required this.student,
    required this.teacherName,
    required this.teacherRepository,
  });

  final TeacherCourse course;
  final ArchivedStudentEnrollment student;
  final String teacherName;
  final TeacherRepository teacherRepository;

  @override
  State<_TeacherManageStudentSheet> createState() =>
      _TeacherManageStudentSheetState();
}

class _TeacherManageStudentSheetState
    extends State<_TeacherManageStudentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _cedulaCtrl;
  final _motivoCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.student.nombreCompleto);
    _cedulaCtrl = TextEditingController(text: widget.student.cedula);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cedulaCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.teacherRepository.createApprovalRequest(
        courseId: widget.course.id,
        courseName: widget.course.nombre,
        requestType: 'editar_alumno',
        teacherName: widget.teacherName,
        oldValues: {
          'alumno_id': widget.student.alumnoId,
          'nombre_completo': widget.student.nombreCompleto,
          'cedula': widget.student.cedula,
        },
        newValues: {
          'alumno_id': widget.student.alumnoId,
          'nombre_completo': _nombreCtrl.text.trim(),
          'cedula': _cedulaCtrl.text.trim(),
        },
        reason: _motivoCtrl.text.trim().isNotEmpty
            ? _motivoCtrl.text.trim()
            : null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Modificación enviada a Coordinación. Quedará en estado pendiente.',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  Future<void> _requestWithdrawal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Solicitar Desincorporación?'),
        content: Text(
          '¿Deseas enviar a Coordinación la solicitud para desincorporar a ${widget.student.nombreCompleto}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sí, Solicitar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await widget.teacherRepository.createApprovalRequest(
        courseId: widget.course.id,
        courseName: widget.course.nombre,
        requestType: 'eliminar_alumno',
        teacherName: widget.teacherName,
        newValues: {
          'alumno_id': widget.student.alumnoId,
          'nombre_completo': widget.student.nombreCompleto,
        },
        reason: _motivoCtrl.text.trim().isNotEmpty
            ? _motivoCtrl.text.trim()
            : 'Desincorporación solicitada por el docente',
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud de desincorporación enviada a Coordinación.',
          ),
          backgroundColor: AppTheme.tertiary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomInset + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gestión de Alumno',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                'Curso: ${widget.course.nombre}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cedulaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cédula de Identidad *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo del cambio (Opcional)',
                  hintText: 'Ej. Corrección de datos o desincorporación',
                  prefixIcon: Icon(Icons.comment_outlined),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.tertiary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppTheme.tertiary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Regla de negocio: Toda acción de modificación o eliminación queda en estado pendiente y no surtirá efecto hasta recibir la aprobación de Coordinación.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _submitEdit,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.pureWhite,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text(
                    'Guardar cambios',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: const BorderSide(color: AppTheme.errorRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _requestWithdrawal,
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: const Text(
                    'Solicitar Desincorporación',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
