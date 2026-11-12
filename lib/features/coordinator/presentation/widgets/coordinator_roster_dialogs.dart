import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';

/// Opens a dialog to enroll a new student directly into [course].
Future<void> showCoordinatorAddStudentDialog(
  BuildContext context, {
  required CoordinatorRepository repository,
  required CourseDashboardItem course,
  required VoidCallback onSuccess,
}) async {
  final nombreCtrl = TextEditingController();
  final cedulaCtrl = TextEditingController();
  final tlfCtrl = TextEditingController();
  final emailCtrl = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: Text('Añadir Alumno a ${course.nombre}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre Completo *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cedulaCtrl,
              decoration: const InputDecoration(
                labelText: 'Cédula de Identidad *',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tlfCtrl,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo Electrónico',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dCtx).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (nombreCtrl.text.trim().isEmpty ||
                cedulaCtrl.text.trim().isEmpty) {
              return;
            }
            Navigator.of(dCtx).pop();
            await repository.coordinatorAddStudent(
              courseId: course.id,
              courseName: course.nombre,
              nombre: nombreCtrl.text.trim(),
              cedula: cedulaCtrl.text.trim(),
              telefono: tlfCtrl.text.trim(),
              email: emailCtrl.text.trim(),
            );
            onSuccess();
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );

  nombreCtrl.dispose();
  cedulaCtrl.dispose();
  tlfCtrl.dispose();
  emailCtrl.dispose();
}

/// Opens a dialog to add a topic to [course].
Future<void> showCoordinatorAddTemaDialog(
  BuildContext context, {
  required CoordinatorRepository repository,
  required CourseDashboardItem course,
  required ValueChanged<String> onSuccess,
}) async {
  final temaCtrl = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: const Text('Añadir Tema al Curso'),
      content: TextField(
        controller: temaCtrl,
        decoration: const InputDecoration(labelText: 'Título del Tema *'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dCtx).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            final value = temaCtrl.text.trim();
            if (value.isEmpty) return;
            Navigator.of(dCtx).pop();
            await repository.coordinatorAddTema(
              courseId: course.id,
              tema: value,
            );
            onSuccess(value);
          },
          child: const Text('Añadir'),
        ),
      ],
    ),
  );
  temaCtrl.dispose();
}

/// Opens a dialog to rename an existing topic in [course].
Future<void> showCoordinatorEditTemaDialog(
  BuildContext context, {
  required CoordinatorRepository repository,
  required CourseDashboardItem course,
  required String oldTema,
  required ValueChanged<String> onSuccess,
}) async {
  final temaCtrl = TextEditingController(text: oldTema);
  await showDialog<void>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: const Text('Editar Tema'),
      content: TextField(
        controller: temaCtrl,
        decoration: const InputDecoration(labelText: 'Título del Tema *'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dCtx).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            final value = temaCtrl.text.trim();
            if (value.isEmpty) return;
            Navigator.of(dCtx).pop();
            await repository.coordinatorEditTema(
              courseId: course.id,
              oldTema: oldTema,
              newTema: value,
            );
            onSuccess(value);
          },
          child: const Text('Actualizar'),
        ),
      ],
    ),
  );
  temaCtrl.dispose();
}
