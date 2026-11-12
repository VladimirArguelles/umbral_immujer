/// Aggregated institutional metrics shown on the Super Admin dashboard.
class SuperAdminMetrics {
  const SuperAdminMetrics({
    this.totalStudents,
    this.totalCourses,
    this.totalTeachers,
    this.totalCoordinators,
    this.totalUsers,
    this.totalAttendances,
    this.totalPresent,
  });

  final int? totalStudents;
  final int? totalCourses;
  final int? totalTeachers;
  final int? totalCoordinators;
  final int? totalUsers;
  final int? totalAttendances;
  final int? totalPresent;

  /// Ratio of present attendance records to total attendance records.
  double? get attendanceRate {
    final total = totalAttendances;
    final present = totalPresent;
    if (total == null || present == null || total == 0) return null;
    return present / total;
  }
}

/// Quick configuration toggles held in the Super Admin settings sheet.
class SuperAdminQuickSettings {
  const SuperAdminQuickSettings({
    required this.platformName,
    required this.activeCycle,
    required this.rlsEnabled,
    required this.notificationsEnabled,
    required this.maintenanceMode,
  });

  final String platformName;
  final String activeCycle;
  final bool rlsEnabled;
  final bool notificationsEnabled;
  final bool maintenanceMode;

  SuperAdminQuickSettings copyWith({
    String? platformName,
    String? activeCycle,
    bool? rlsEnabled,
    bool? notificationsEnabled,
    bool? maintenanceMode,
  }) {
    return SuperAdminQuickSettings(
      platformName: platformName ?? this.platformName,
      activeCycle: activeCycle ?? this.activeCycle,
      rlsEnabled: rlsEnabled ?? this.rlsEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
    );
  }
}
