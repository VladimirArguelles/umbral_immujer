enum UserRole {
  alumno,
  profesor,
  coordinador;

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'profesor':
        return UserRole.profesor;
      case 'coordinador':
      case 'administrador':
      case 'admin':
        return UserRole.coordinador;
      default:
        return UserRole.alumno;
    }
  }

  String toDbString() {
    switch (this) {
      case UserRole.profesor:
        return 'profesor';
      case UserRole.coordinador:
        return 'coordinador';
      case UserRole.alumno:
        return 'alumno';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.profesor:
        return 'Profesor';
      case UserRole.coordinador:
        return 'Coordinador';
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

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.cedula,
    this.telefono,
    required this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: (json['correo'] ?? json['email'] ?? '') as String,
      fullName: (json['nombre_completo'] ?? json['full_name'] ?? 'Usuario') as String,
      cedula: json['cedula'] as String?,
      telefono: json['telefono'] as String?,
      role: UserRole.fromString(json['rol'] as String?),
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
    };
  }
}
