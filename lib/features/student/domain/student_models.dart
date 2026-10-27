class StudentCourse {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? horario;
  final String? profesorNombre;
  final String estado; // 'activo' | 'finalizado'

  StudentCourse({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.horario,
    this.profesorNombre,
    required this.estado,
  });

  factory StudentCourse.fromJson(Map<String, dynamic> json) {
    String? profName;
    if (json['cursos'] != null && json['cursos']['profiles'] != null) {
      profName = json['cursos']['profiles']['nombre_completo'] as String?;
    } else if (json['profiles'] != null) {
      profName = json['profiles']['nombre_completo'] as String?;
    }

    final cursoMap = json['cursos'] is Map<String, dynamic>
        ? json['cursos']
        : json;

    return StudentCourse(
      id: (cursoMap['id'] ?? '') as String,
      nombre: (cursoMap['nombre'] ?? 'Curso') as String,
      descripcion: cursoMap['descripcion'] as String?,
      horario: cursoMap['horario'] as String?,
      profesorNombre: profName,
      estado: (json['estado'] ?? cursoMap['estado'] ?? 'activo') as String,
    );
  }
}

class AttendanceRecord {
  final String id;
  final String cursoId;
  final String fecha;
  final String estado; // 'Presente' | 'Ausente'
  final DateTime? createdAt;

  AttendanceRecord({
    required this.id,
    required this.cursoId,
    required this.fecha,
    required this.estado,
    this.createdAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: (json['id'] ?? '') as String,
      cursoId: (json['curso_id'] ?? '') as String,
      fecha: (json['fecha'] ?? '') as String,
      estado: (json['estado'] ?? 'Presente') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class AttendanceSummary {
  final int totalClases;
  final int presentes;
  final int inasistencias;
  final List<AttendanceRecord> historial;

  AttendanceSummary({
    required this.totalClases,
    required this.presentes,
    required this.inasistencias,
    required this.historial,
  });

  bool get tieneAlertaDosAusencias => inasistencias >= 2;
}

class StudentSurvey {
  final String id;
  final String cursoId;
  final String cursoNombre;
  final String fechaClase;
  final double costoTotalInsumos;
  final DateTime fechaLimite;
  final double montoIndividual;
  final int totalConfirmados;
  final String estadoEncuesta; // 'activa' | 'cerrada'

  // Datos de la respuesta del alumno si ya respondió
  final bool? respondio;
  final bool? asistira;
  final String? comprobanteUrl;
  final String? estadoPago; // 'pendiente' | 'verificado' | 'rechazado'

  StudentSurvey({
    required this.id,
    required this.cursoId,
    required this.cursoNombre,
    required this.fechaClase,
    required this.costoTotalInsumos,
    required this.fechaLimite,
    required this.montoIndividual,
    required this.totalConfirmados,
    required this.estadoEncuesta,
    this.respondio,
    this.asistira,
    this.comprobanteUrl,
    this.estadoPago,
  });

  bool get estaVencida => DateTime.now().isAfter(fechaLimite);
  bool get tieneCapturePendiente =>
      (asistira == true) && (comprobanteUrl == null || comprobanteUrl!.isEmpty);
}
