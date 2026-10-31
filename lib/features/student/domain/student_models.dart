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
    final pMap = (json['cursos'] is Map
            ? json['cursos']['perfiles']
            : null) ??
        json['perfiles'];
    if (pMap is Map) {
      profName = pMap['nombre_completo'] as String?;
    }

    final cursoMap =
        json['cursos'] is Map<String, dynamic> ? json['cursos'] : json;

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
  final String estadoEncuesta; // 'activa' | 'cerrada' | 'cancelada'

  // Datos de la respuesta del alumno si ya respondiÃ³
  final bool? respondio;
  final bool? asistira;
  final String? comprobanteUrl;
  final String? estadoPago; // 'pendiente' | 'verificado' | 'rechazado'
  final double? montoAsignado;
  final DateTime? comprobanteSubidoAt;

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
    this.montoAsignado,
    this.comprobanteSubidoAt,
  });

  bool get estaVencida => DateTime.now().isAfter(fechaLimite);
  bool get tieneCapturePendiente =>
      (asistira == true) && (comprobanteUrl == null || comprobanteUrl!.isEmpty);

  /// Monto de la cuota a cancelar por la alumna
  double get cuotaACancelar {
    if (montoAsignado != null && montoAsignado! > 0) {
      return montoAsignado!;
    }
    return montoIndividual;
  }
}

/// Registro del Historial de Pagos Realizados por la Alumna
class StudentPaymentRecord {
  final String id;
  final String encuestaId;
  final String cursoId;
  final String cursoNombre;
  final String fechaClase;
  final double montoCancelado;
  final String? comprobanteUrl;
  final String estadoPago; // 'pendiente' | 'verificado' | 'rechazado'
  final DateTime? comprobanteSubidoAt;
  final DateTime? fechaRespuesta;
  final bool asistira;

  StudentPaymentRecord({
    required this.id,
    required this.encuestaId,
    required this.cursoId,
    required this.cursoNombre,
    required this.fechaClase,
    required this.montoCancelado,
    this.comprobanteUrl,
    required this.estadoPago,
    this.comprobanteSubidoAt,
    this.fechaRespuesta,
    required this.asistira,
  });

  bool get isVerificado => estadoPago.toLowerCase() == 'verificado';
  bool get isPendiente => estadoPago.toLowerCase() == 'pendiente';
  bool get isRechazado => estadoPago.toLowerCase() == 'rechazado';
}

class JustificativoAsistencia {
  final String id;
  final String alumnoId;
  final String cursoId;
  final String fecha;
  final String motivo;
  final String? comprobanteUrl;
  final String estado; // 'pendiente' | 'aprobado' | 'rechazado'
  final String? comentariosRevision;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  JustificativoAsistencia({
    required this.id,
    required this.alumnoId,
    required this.cursoId,
    required this.fecha,
    required this.motivo,
    this.comprobanteUrl,
    this.estado = 'pendiente',
    this.comentariosRevision,
    this.createdAt,
    this.updatedAt,
  });

  factory JustificativoAsistencia.fromJson(Map<String, dynamic> json) {
    return JustificativoAsistencia(
      id: (json['id'] ?? '') as String,
      alumnoId: (json['alumno_id'] ?? '') as String,
      cursoId: (json['curso_id'] ?? '') as String,
      fecha: (json['fecha'] ?? '') as String,
      motivo: (json['motivo'] ?? '') as String,
      comprobanteUrl: json['comprobante_url'] as String?,
      estado: (json['estado'] ?? 'pendiente') as String,
      comentariosRevision: json['comentarios_revision'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  bool get isPendiente => estado.toLowerCase() == 'pendiente';
  bool get isAprobado => estado.toLowerCase() == 'aprobado';
  bool get isRechazado => estado.toLowerCase() == 'rechazado';
}
