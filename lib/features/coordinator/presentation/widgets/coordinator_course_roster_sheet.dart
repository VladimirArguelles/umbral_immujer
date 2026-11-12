import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/features/coordinator/presentation/widgets/coordinator_roster_dialogs.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Opens the bottom sheet to manage students and syllabus topics for [course].
Future<void> showCoordinatorCourseRosterSheet(
  BuildContext context, {
  required CoordinatorRepository repository,
  required CourseDashboardItem course,
  required VoidCallback onReload,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => DefaultTabController(
      length: 2,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, _) => FutureBuilder<Map<String, dynamic>>(
          future: repository.getCourseStudentsAndTemas(course.id),
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? {};
            final alumnosList = data['alumnos'] as List? ?? [];
            final temasList = data['temas'] as List<String>? ?? [];

            return StatefulBuilder(
              builder: (_, setSheetState) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.nombre,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Gestión directa de plantilla de Alumnos y Temas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const TabBar(
                      tabs: [
                        Tab(
                          icon: Icon(Icons.people_alt_rounded, size: 18),
                          text: 'Alumnos',
                        ),
                        Tab(
                          icon: Icon(Icons.menu_book_rounded, size: 18),
                          text: 'Temas',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _RosterStudentsTab(
                            parentContext: context,
                            repository: repository,
                            course: course,
                            alumnosList: alumnosList,
                            onChanged: () {
                              setSheetState(() {});
                              onReload();
                            },
                          ),
                          _RosterTemasTab(
                            parentContext: context,
                            repository: repository,
                            course: course,
                            temasList: temasList,
                            onChanged: () => setSheetState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _RosterStudentsTab extends StatelessWidget {
  const _RosterStudentsTab({
    required this.parentContext,
    required this.repository,
    required this.course,
    required this.alumnosList,
    required this.onChanged,
  });

  final BuildContext parentContext;
  final CoordinatorRepository repository;
  final CourseDashboardItem course;
  final List<dynamic> alumnosList;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Alumnos Registrados (${alumnosList.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Añadir Alumno'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              onPressed: () => showCoordinatorAddStudentDialog(
                parentContext,
                repository: repository,
                course: course,
                onSuccess: onChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: alumnosList.isEmpty
              ? const Center(
                  child: Text('No hay alumnos inscritos en este curso.'),
                )
              : ListView.separated(
                  itemCount: alumnosList.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, aIdx) {
                    final item = alumnosList[aIdx];
                    final al = item['alumnos'] as Map<String, dynamic>?;
                    final studentId = item['alumno_id'] as String;
                    final nombre = al?['nombre_completo'] ?? 'Sin nombre';
                    final cedula = al?['cedula'] ?? '';
                    final telefono = al?['telefono'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryContainer,
                        child: Text(nombre.isNotEmpty ? nombre[0] : 'A'),
                      ),
                      title: Text(
                        nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'C.I: $cedula ${telefono.isNotEmpty ? "• Tlf: $telefono" : ""}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.person_remove_rounded,
                          color: AppTheme.errorRed,
                        ),
                        tooltip: 'Desincorporar Alumno',
                        onPressed: () async {
                          final conf = await showDialog<bool>(
                            context: parentContext,
                            builder: (d) => AlertDialog(
                              title: const Text('Desincorporar Alumno'),
                              content: Text(
                                '¿Desea desincorporar a $nombre de este curso?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(d).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(d).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.errorRed,
                                  ),
                                  child: const Text('Desincorporar'),
                                ),
                              ],
                            ),
                          );
                          if (conf == true) {
                            await repository.coordinatorDeleteStudent(
                              courseId: course.id,
                              studentId: studentId,
                            );
                            alumnosList.removeAt(aIdx);
                            onChanged();
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RosterTemasTab extends StatelessWidget {
  const _RosterTemasTab({
    required this.parentContext,
    required this.repository,
    required this.course,
    required this.temasList,
    required this.onChanged,
  });

  final BuildContext parentContext;
  final CoordinatorRepository repository;
  final CourseDashboardItem course;
  final List<String> temasList;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Temas del Curso (${temasList.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Añadir Tema'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              onPressed: () => showCoordinatorAddTemaDialog(
                parentContext,
                repository: repository,
                course: course,
                onSuccess: (nuevoTema) {
                  temasList.add(nuevoTema);
                  onChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: temasList.isEmpty
              ? const Center(
                  child: Text('No hay temas registrados para este curso.'),
                )
              : ListView.separated(
                  itemCount: temasList.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, tIdx) {
                    final tema = temasList[tIdx];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.secondaryContainer,
                        child: Text(
                          '${tIdx + 1}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      title: Text(tema),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                            tooltip: 'Editar Tema',
                            onPressed: () => showCoordinatorEditTemaDialog(
                              parentContext,
                              repository: repository,
                              course: course,
                              oldTema: tema,
                              onSuccess: (actualizado) {
                                temasList[tIdx] = actualizado;
                                onChanged();
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppTheme.errorRed,
                            ),
                            tooltip: 'Eliminar Tema',
                            onPressed: () async {
                              final conf = await showDialog<bool>(
                                context: parentContext,
                                builder: (d) => AlertDialog(
                                  title: const Text('Eliminar Tema'),
                                  content: Text(
                                    '¿Desea eliminar el tema "$tema"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(d).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(d).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.errorRed,
                                      ),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );
                              if (conf == true) {
                                await repository.coordinatorDeleteTema(
                                  courseId: course.id,
                                  tema: tema,
                                );
                                temasList.removeAt(tIdx);
                                onChanged();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
