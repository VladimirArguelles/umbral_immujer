import 'dart:async';

import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// Live Realtime monitor tab listing today's recorded absences.
class CoordinatorLiveAbsencesTab extends StatefulWidget {
  const CoordinatorLiveAbsencesTab({
    super.key,
    required this.coordinatorRepository,
  });

  final CoordinatorRepository coordinatorRepository;

  @override
  State<CoordinatorLiveAbsencesTab> createState() =>
      _CoordinatorLiveAbsencesTabState();
}

class _CoordinatorLiveAbsencesTabState
    extends State<CoordinatorLiveAbsencesTab> {
  final String _fechaHoy = Formatters.isoDate(DateTime.now());
  List<LiveAbsence> _ausencias = [];
  bool _isLoading = true;
  StreamSubscription<dynamic>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _loadAusencias();
    _realtimeSubscription = widget.coordinatorRepository
        .streamTodayAttendance(_fechaHoy)
        .listen((_) => _loadAusencias());
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAusencias() async {
    final list = await widget.coordinatorRepository.getTodayAbsences(_fechaHoy);
    if (mounted) {
      setState(() {
        _ausencias = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.errorRed.withValues(alpha: 0.12),
          child: Row(
            children: [
              const Icon(Icons.circle, color: AppTheme.errorRed, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Monitor en Vivo: Ausencias detectadas hoy ($_fechaHoy): ${_ausencias.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorRed,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.errorRed,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const AttendanceSkeleton()
              : _ausencias.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 54,
                        color: AppTheme.successGreen,
                      ),
                      SizedBox(height: 12),
                      Text('No se registran ausencias en la jornada de hoy.'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 88,
                  ),
                  itemCount: _ausencias.length,
                  itemBuilder: (context, idx) {
                    final aus = _ausencias[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                          color: AppTheme.errorRed,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.errorRed,
                          child: Icon(
                            Icons.person_off,
                            color: AppTheme.onError,
                          ),
                        ),
                        title: Text(
                          aus.alumnoNombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Curso: ${aus.cursoNombre}'),
                            Text(
                              'C.I: ${aus.cedula} • ${aus.horaMarcada != null ? Formatters.dateTime(aus.horaMarcada!) : ""}',
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'AUSENTE',
                            style: TextStyle(
                              color: AppTheme.onError,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
