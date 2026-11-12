import 'package:umbral_immujer/features/superadmin/domain/super_admin_metrics.dart';

/// Result returned when fetching Super Admin dashboard metrics.
class SuperAdminMetricsResult {
  const SuperAdminMetricsResult({
    required this.metrics,
    this.partialError,
  });

  final SuperAdminMetrics metrics;
  final Object? partialError;
}

/// Contract for loading Super Admin overview metrics and ending sessions.
abstract class SuperAdminRepository {
  /// Fetches institutional counts and optional non-fatal RPC errors.
  Future<SuperAdminMetricsResult> fetchMetrics();

  /// Signs out the current authenticated user.
  Future<void> signOut();
}
