import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/features/superadmin/domain/super_admin_metrics.dart';
import 'package:umbral_immujer/features/superadmin/domain/super_admin_repository.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';

/// Supabase-backed implementation of [SuperAdminRepository].
class SupabaseSuperAdminRepository implements SuperAdminRepository {
  SupabaseSuperAdminRepository({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<SuperAdminMetricsResult> fetchMetrics() async {
    Object? authenticatedUsersError;
    final authenticatedUsersFuture = _client
        .rpc<int>('count_authenticated_users')
        .then<int?>((count) => count)
        .catchError((Object error) {
          authenticatedUsersError = error;
          return null;
        });

    final futures = await Future.wait([
      _client.from('alumnos').select('id').count(),
      _client.from('cursos').select('id').eq('estado', 'activo').count(),
      _client.from('perfiles').select('id').eq('rol', 'profesor').count(),
      _client.from('perfiles').select('id').eq('rol', 'coordinador').count(),
      _client.from('asistencia').select('id').count(),
      _client.from('asistencia').select('id').eq('estado', 'Presente').count(),
    ]);

    final authenticatedUsers = await authenticatedUsersFuture;

    return SuperAdminMetricsResult(
      metrics: SuperAdminMetrics(
        totalStudents: futures[0].count,
        totalCourses: futures[1].count,
        totalTeachers: futures[2].count,
        totalCoordinators: futures[3].count,
        totalUsers: authenticatedUsers,
        totalAttendances: futures[4].count,
        totalPresent: futures[5].count,
      ),
      partialError: authenticatedUsersError,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
