import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// Directory tab listing registered teachers and their assigned courses.
class CoordinatorTeachersTab extends StatefulWidget {
  const CoordinatorTeachersTab({
    super.key,
    required this.coordinatorRepository,
  });

  final CoordinatorRepository coordinatorRepository;

  @override
  State<CoordinatorTeachersTab> createState() => _CoordinatorTeachersTabState();
}

class _CoordinatorTeachersTabState extends State<CoordinatorTeachersTab> {
  late Future<List<AvailableTeacher>> _profesoresFuture;

  @override
  void initState() {
    super.initState();
    _loadProfesores();
  }

  void _loadProfesores() {
    setState(() {
      _profesoresFuture = widget.coordinatorRepository.getRegisteredTeachers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AvailableTeacher>>(
      future: _profesoresFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AttendanceSkeleton();
        }
        final profs = snapshot.data ?? [];
        if (profs.isEmpty) {
          return const Center(
            child: Text('No hay docentes con cuenta activa registrados.'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadProfesores(),
          child: ListView.builder(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 88,
            ),
            itemCount: profs.length,
            itemBuilder: (context, idx) {
              final p = profs[idx];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: Icon(Icons.school, color: AppTheme.onPrimary),
                  ),
                  title: Text(
                    p.nombreCompleto,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'C.I: ${p.cedula} • ${p.telefono ?? "Sin teléfono"}\nCurso actual: ${p.cursoActual ?? "Disponible para asignación"}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
