import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Opens a dialog to submit a Coordinator approval request to add a new student.
void showTeacherAddStudentDialog({
  required BuildContext context,
  required TeacherCourse course,
  required String teacherName,
  required TeacherRepository teacherRepository,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _TeacherAddStudentDialog(
      course: course,
      teacherName: teacherName,
      teacherRepository: teacherRepository,
    ),
  );
}

class _TeacherAddStudentDialog extends StatefulWidget {
  const _TeacherAddStudentDialog({
    required this.course,
    required this.teacherName,
    required this.teacherRepository,
  });

  final TeacherCourse course;
  final String teacherName;
  final TeacherRepository teacherRepository;

  @override
  State<_TeacherAddStudentDialog> createState() =>
      _TeacherAddStudentDialogState();
}

class _TeacherAddStudentDialogState extends State<_TeacherAddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.teacherRepository.createApprovalRequest(
        courseId: widget.course.id,
        courseName: widget.course.nombre,
        requestType: 'crear_alumno',
        teacherName: widget.teacherName,
        newValues: {
          'nombre_completo': _nombreCtrl.text.trim(),
          'cedula': _cedulaCtrl.text.trim(),
          'telefono': _telefonoCtrl.text.trim(),
          'correo': _correoCtrl.text.trim(),
        },
        reason: 'Incorporación de alumno por el docente',
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud de alumno enviada a Coordinación. Quedará activa al ser aprobada.',
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Añadir Nuevo Alumno',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Sujeto a aprobación de Coordinación',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre y Apellido *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa el nombre completo'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cedulaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cédula de Identidad *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa la cédula'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (Opcional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _correoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo (Opcional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La solicitud quedará en estado pendiente y se aplicará tras ser aprobada por Coordinación.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _submit,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.pureWhite,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: const Text('Enviar a Coordinación'),
        ),
      ],
    );
  }
}
