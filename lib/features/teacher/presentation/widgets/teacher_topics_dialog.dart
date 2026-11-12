import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Opens the course syllabus topics modal allowing teachers to propose topic changes.
void showTeacherTopicsDialog({
  required BuildContext context,
  required TeacherCourse course,
  required String teacherName,
  required TeacherRepository teacherRepository,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _TeacherTopicsDialog(
      course: course,
      teacherName: teacherName,
      teacherRepository: teacherRepository,
    ),
  );
}

class _TeacherTopicsDialog extends StatefulWidget {
  const _TeacherTopicsDialog({
    required this.course,
    required this.teacherName,
    required this.teacherRepository,
  });

  final TeacherCourse course;
  final String teacherName;
  final TeacherRepository teacherRepository;

  @override
  State<_TeacherTopicsDialog> createState() => _TeacherTopicsDialogState();
}

class _TeacherTopicsDialogState extends State<_TeacherTopicsDialog> {
  List<String> _temas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemas();
  }

  Future<void> _loadTemas() async {
    setState(() => _loading = true);
    try {
      final list = await widget.teacherRepository.getCourseTemas(widget.course.id);
      if (!mounted) return;
      setState(() {
        _temas = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _proposeTopicInput({String? oldTema}) async {
    final ctrl = TextEditingController(text: oldTema ?? '');
    final isEditing = oldTema != null;
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isEditing ? 'Editar Tema' : 'Añadir Tema'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText:
                isEditing ? 'Nuevo título del tema *' : 'Título del tema *',
            hintText: isEditing
                ? null
                : 'Ej. Introducción a Técnicas de Repostería',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('Enviar a Coordinación'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (result == null || result.isEmpty || (isEditing && result == oldTema)) {
      return;
    }
    try {
      await widget.teacherRepository.createApprovalRequest(
        courseId: widget.course.id,
        courseName: widget.course.nombre,
        requestType: isEditing ? 'editar_tema' : 'crear_tema',
        teacherName: widget.teacherName,
        oldValues: isEditing ? {'tema': oldTema} : null,
        newValues: {'tema': result},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Modificación de tema enviada a Coordinación para aprobación.'
                : 'Solicitud de tema enviada a Coordinación para aprobación.',
          ),
        ),
      );
      await _loadTemas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _proposeDeleteTopic(String tema) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Eliminar Tema?'),
        content: Text(
          '¿Deseas enviar a Coordinación la solicitud para eliminar el tema "$tema"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Solicitar Eliminación'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.teacherRepository.createApprovalRequest(
        courseId: widget.course.id,
        courseName: widget.course.nombre,
        requestType: 'eliminar_tema',
        teacherName: widget.teacherName,
        newValues: {'tema': tema},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud de eliminación de tema enviada a Coordinación.',
          ),
        ),
      );
      await _loadTemas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainerLow,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.topic_rounded, color: AppTheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestión de Temas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.course.nombre,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.primary),
            tooltip: 'Proponer nuevo tema',
            onPressed: () => _proposeTopicInput(),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 550,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _temas.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No hay temas registrados en este curso aún.',
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _temas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) => _TopicRowTile(
                        index: index,
                        tema: _temas[index],
                        onEdit: () => _proposeTopicInput(oldTema: _temas[index]),
                        onDelete: () => _proposeDeleteTopic(_temas[index]),
                      ),
                    ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _TopicRowTile extends StatelessWidget {
  const _TopicRowTile({
    required this.index,
    required this.tema,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final String tema;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.secondary.withValues(alpha: 0.15),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tema,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Editar tema',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AppTheme.errorRed,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Eliminar tema',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
