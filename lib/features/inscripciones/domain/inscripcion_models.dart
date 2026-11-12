/// Modelos de dominio para el módulo de Inscripciones y Accesos Temporales.
library;

class CursoConCupos {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? horario;
  final String estado;
  final int cupoMaximo;
  final bool admisionAbierta;
  final int inscritosCount;

  const CursoConCupos({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.horario,
    required this.estado,
    required this.cupoMaximo,
    required this.admisionAbierta,
    required this.inscritosCount,
  });

  int get cuposDisponibles => (cupoMaximo - inscritosCount).clamp(0, cupoMaximo);

  bool get cuposAgotados => inscritosCount >= cupoMaximo;

  bool get puedeInscribir =>
      estado == 'activo' && admisionAbierta && !cuposAgotados;

  double get porcentajeOcupacion {
    if (cupoMaximo <= 0) return 1.0;
    return (inscritosCount / cupoMaximo).clamp(0.0, 1.0);
  }

  String get resumenCupos {
    final unidad = cuposDisponibles == 1 ? 'cupo disponible' : 'cupos disponibles';
    return 'Inscritos: $inscritosCount / $cupoMaximo - $cuposDisponibles $unidad';
  }

  factory CursoConCupos.fromJson(Map<String, dynamic> json) {
    return CursoConCupos(
      id: json['id'] as String,
      nombre: (json['nombre'] ?? 'Curso') as String,
      descripcion: json['descripcion'] as String?,
      horario: json['horario'] as String?,
      estado: (json['estado'] ?? 'activo') as String,
      cupoMaximo: (json['cupo_maximo'] as num?)?.toInt() ?? 30,
      admisionAbierta: (json['admision_abierta'] as bool?) ?? true,
      inscritosCount: (json['inscritos_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class RegistroAspiranteRequest {
  final String cursoId;
  final String cedula;
  final String nombres;
  final String apellidos;
  final String telefono;
  final String correo;

  const RegistroAspiranteRequest({
    required this.cursoId,
    required this.cedula,
    required this.nombres,
    required this.apellidos,
    required this.telefono,
    required this.correo,
  });
}

class VerificacionCedulaResultado {
  final bool yaInscritoEnCurso;
  final String? alumnoId;
  final String? nombreExistente;
  final String? telefonoExistente;
  final String? correoExistente;

  const VerificacionCedulaResultado({
    required this.yaInscritoEnCurso,
    this.alumnoId,
    this.nombreExistente,
    this.telefonoExistente,
    this.correoExistente,
  });
}

class InscripcionResultado {
  final String inscripcionId;
  final String alumnoId;
  final String cursoId;
  final String cursoNombre;
  final String nombreCompleto;
  final String cedula;
  final int inscritosActuales;
  final int cupoMaximo;
  final int cuposRestantes;

  const InscripcionResultado({
    required this.inscripcionId,
    required this.alumnoId,
    required this.cursoId,
    required this.cursoNombre,
    required this.nombreCompleto,
    required this.cedula,
    required this.inscritosActuales,
    required this.cupoMaximo,
    required this.cuposRestantes,
  });

  factory InscripcionResultado.fromJson(Map<String, dynamic> json) {
    return InscripcionResultado(
      inscripcionId: (json['inscripcion_id'] ?? '') as String,
      alumnoId: (json['alumno_id'] ?? '') as String,
      cursoId: (json['curso_id'] ?? '') as String,
      cursoNombre: (json['curso_nombre'] ?? '') as String,
      nombreCompleto: (json['nombre_completo'] ?? '') as String,
      cedula: (json['cedula'] ?? '') as String,
      inscritosActuales: (json['inscritos_actuales'] as num?)?.toInt() ?? 0,
      cupoMaximo: (json['cupo_maximo'] as num?)?.toInt() ?? 30,
      cuposRestantes: (json['cupos_restantes'] as num?)?.toInt() ?? 0,
    );
  }
}

class InscripcionRecienteItem {
  final String id;
  final String cursoId;
  final String cursoNombre;
  final String alumnoNombre;
  final String cedula;
  final String? telefono;
  final String? correo;
  final String origen;
  final DateTime? createdAt;

  const InscripcionRecienteItem({
    required this.id,
    required this.cursoId,
    required this.cursoNombre,
    required this.alumnoNombre,
    required this.cedula,
    this.telefono,
    this.correo,
    required this.origen,
    this.createdAt,
  });
}

class OperadorTemporal {
  final String userId;
  final String email;
  final String nombreCompleto;
  final String? cedula;
  final String? telefono;
  final bool accesoActivo;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;

  const OperadorTemporal({
    required this.userId,
    required this.email,
    required this.nombreCompleto,
    this.cedula,
    this.telefono,
    required this.accesoActivo,
    this.createdAt,
    this.lastSignInAt,
  });

  factory OperadorTemporal.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString())?.toLocal();
    }

    return OperadorTemporal(
      userId: (json['user_id'] ?? json['id'] ?? '') as String,
      email: (json['email'] ?? json['correo'] ?? '') as String,
      nombreCompleto: (json['nombre_completo'] ?? 'Operador Temporal') as String,
      cedula: json['cedula'] as String?,
      telefono: json['telefono'] as String?,
      accesoActivo: (json['acceso_activo'] as bool?) ?? true,
      createdAt: parseDate(json['created_at']),
      lastSignInAt: parseDate(json['last_sign_in_at']),
    );
  }
}
