enum UserRole {
  alumno,
  profesor,
  coordinador,
  superAdmin,
  operadorInscripcion;

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return UserRole.superAdmin;
      case 'profesor':
      case 'teacher':
        return UserRole.profesor;
      case 'coordinador':
      case 'coordinator':
      case 'administrador':
      case 'admin':
        return UserRole.coordinador;
      case 'operador_inscripcion':
      case 'operadorinscripcion':
        return UserRole.operadorInscripcion;
      case 'alumno':
      case 'student':
        return UserRole.alumno;
      default:
        return UserRole.alumno;
    }
  }

  String toDbString() {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.profesor:
        return 'profesor';
      case UserRole.coordinador:
        return 'coordinador';
      case UserRole.operadorInscripcion:
        return 'operador_inscripcion';
      case UserRole.alumno:
        return 'alumno';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.profesor:
        return 'Profesor';
      case UserRole.coordinador:
        return 'Coordinador';
      case UserRole.operadorInscripcion:
        return 'Operador de Inscripción';
      case UserRole.alumno:
        return 'Alumno';
    }
  }
}

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? cedula;
  final String? telefono;
  final UserRole role;
  final String? avatarUrl;
  final bool accesoActivo;

  /// Alias de conveniencia para compatibilidad con esquemas de base de datos
  UserRole get rol => role;

  /// Helpers de autorización de roles
  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isCoordinador => role == UserRole.coordinador || isSuperAdmin;
  bool get isProfesor => role == UserRole.profesor || isCoordinador;
  bool get isOperadorInscripcion => role == UserRole.operadorInscripcion;
  bool get canAccessInscripciones =>
      isSuperAdmin || isCoordinador || isProfesor || isOperadorInscripcion;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.cedula,
    this.telefono,
    required this.role,
    this.avatarUrl,
    this.accesoActivo = true,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: (json['correo'] ?? json['email'] ?? '') as String,
      fullName: (json['nombre_completo'] ?? json['full_name'] ?? 'Usuario') as String,
      cedula: json['cedula'] as String?,
      telefono: json['telefono'] as String?,
      role: UserRole.fromString(json['rol'] as String?),
      avatarUrl: json['avatar_url'] as String?,
      accesoActivo: (json['acceso_activo'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'correo': email,
      'nombre_completo': fullName,
      'cedula': cedula,
      'telefono': telefono,
      'rol': role.toDbString(),
      'avatar_url': avatarUrl,
      'acceso_activo': accesoActivo,
    };
  }

  UserProfile copyWith({
    String? email,
    String? fullName,
    String? cedula,
    String? telefono,
    UserRole? role,
    String? avatarUrl,
    bool? accesoActivo,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      cedula: cedula ?? this.cedula,
      telefono: telefono ?? this.telefono,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      accesoActivo: accesoActivo ?? this.accesoActivo,
    );
  }
}
