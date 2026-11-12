import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/student/data/student_repository.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// Courses tab displaying active and finished courses for the student.
class StudentCoursesTab extends StatefulWidget {
  const StudentCoursesTab({
    super.key,
    required this.studentRepository,
    this.isSuperAdmin = false,
  });

  final StudentRepository studentRepository;
  final bool isSuperAdmin;

  @override
  State<StudentCoursesTab> createState() => _StudentCoursesTabState();
}

class _StudentCoursesTabState extends State<StudentCoursesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<StudentCourse>> _cursosActivosFuture;
  late Future<List<StudentCourse>> _cursosHistorialFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCursos();
  }

  void _loadCursos() {
    _cursosActivosFuture = widget.studentRepository.getMyCourses(
      statusFilter: 'activo',
      isSuperAdmin: widget.isSuperAdmin,
    );
    _cursosHistorialFuture = widget.studentRepository.getMyCourses(
      statusFilter: 'finalizado',
      isSuperAdmin: widget.isSuperAdmin,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppTheme.dynamicCard,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.dynamicTextMuted,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Cursos Activos', icon: Icon(Icons.play_circle_outline)),
              Tab(text: 'Historial / Finalizados', icon: Icon(Icons.history)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCursosList(_cursosActivosFuture, isActivo: true),
              _buildCursosList(_cursosHistorialFuture, isActivo: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCursosList(
    Future<List<StudentCourse>> future, {
    required bool isActivo,
  }) {
    return FutureBuilder<List<StudentCourse>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CoursesSkeleton();
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(height: 12),
                  Text('Error al cargar tus cursos: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(_loadCursos),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final cursos = snapshot.data ?? [];
        if (cursos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActivo ? Icons.school_outlined : Icons.archive_outlined,
                    size: 64,
                    color: AppTheme.dynamicTextMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isActivo
                        ? 'No estás inscrito en ningún curso activo por el momento.'
                        : 'No tienes cursos finalizados en tu historial.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.dynamicTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(_loadCursos);
            await future;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: cursos.length,
            itemBuilder: (context, index) =>
                _StudentCourseCard(course: cursos[index], isActivo: isActivo),
          ),
        );
      },
    );
  }
}

class _StudentCourseCard extends StatelessWidget {
  const _StudentCourseCard({required this.course, required this.isActivo});

  final StudentCourse course;
  final bool isActivo;

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        isActivo ? AppTheme.successGreen : AppTheme.dynamicTextMuted;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    course.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    course.estado.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            if (course.descripcion != null &&
                course.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                course.descripcion!,
                style: TextStyle(color: AppTheme.dynamicTextMuted, fontSize: 14),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Profesor: ${course.profesorNombre ?? "Por asignar"}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (course.horario != null && course.horario!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Horario: ${course.horario}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.dynamicTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
