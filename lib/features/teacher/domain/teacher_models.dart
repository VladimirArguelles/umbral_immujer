class TeacherCourse {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? horario;
  final int totalAlumnos;

  TeacherCourse({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.horario,
    required this.totalAlumnos,
  });

  factory TeacherCourse.fromJson(
    Map<String, dynamic> json, {
    int totalAlumnos = 0,
  }) {
    return TeacherCourse(
      id: (json['id'] ?? '') as String,
      nombre: (json['nombre'] ?? 'Curso') as String,
      descripcion: json['descripcion'] as String?,
      horario: json['horario'] as String?,
      totalAlumnos: totalAlumnos,
    );
  }
}

class StudentAttendanceItem {
  final String alumnoId;
  final String nombreCompleto;
  final String cedula;
  final String? telefono;
  String estadoAsistencia; // 'Presente' | 'Ausente'
  final bool? confirmoEncuesta;
  final String? estadoPago;

  StudentAttendanceItem({
    required this.alumnoId,
    required this.nombreCompleto,
    required this.cedula,
    this.telefono,
    this.estadoAsistencia = 'Ausente',
    this.confirmoEncuesta,
    this.estadoPago,
  });

  bool get isPresente => estadoAsistencia == 'Presente';
}

class PaymentAuditItem {
  final String respuestaId;
  final String alumnoId;
  final String nombreCompleto;
  final String cedula;
  final double monto;
  final String estadoPago; // 'pendiente' | 'verificado' | 'rechazado'
  final String? comprobanteUrl;

  PaymentAuditItem({
    required this.respuestaId,
    required this.alumnoId,
    required this.nombreCompleto,
    required this.cedula,
    required this.monto,
    required this.estadoPago,
    this.comprobanteUrl,
  });
}

class ArchivedStudentEnrollment {
  final String inscripcionId;
  final String alumnoId;
  final String nombreCompleto;
  final String cedula;
  final String estado; // 'activo' | 'retirado'
  final DateTime? deletedAt;

  ArchivedStudentEnrollment({
    required this.inscripcionId,
    required this.alumnoId,
    required this.nombreCompleto,
    required this.cedula,
    required this.estado,
    this.deletedAt,
  });

  bool get estaEliminado => deletedAt != null || estado == 'retirado';
}

class SolicitudAprobacionItem {
  final String id;
  final String profesorId;
  final String? profesorNombre;
  final String cursoId;
  final String? cursoNombre;
  final String tipoSolicitud;
  final String estado; // 'pendiente' | 'aprobado' | 'rechazado'
  final Map<String, dynamic>? datosAnteriores;
  final Map<String, dynamic> datosNuevos;
  final String? motivo;
  final String? observacionRevision;
  final DateTime createdAt;
  final DateTime? fechaRevision;

  SolicitudAprobacionItem({
    required this.id,
    required this.profesorId,
    this.profesorNombre,
    required this.cursoId,
    this.cursoNombre,
    required this.tipoSolicitud,
    required this.estado,
    this.datosAnteriores,
    required this.datosNuevos,
    this.motivo,
    this.observacionRevision,
    required this.createdAt,
    this.fechaRevision,
  });

  factory SolicitudAprobacionItem.fromJson(Map<String, dynamic> json) {
    return SolicitudAprobacionItem(
      id: json['id'] as String,
      profesorId: json['profesor_id'] as String,
      profesorNombre: json['profesor_nombre'] as String?,
      cursoId: json['curso_id'] as String,
      cursoNombre: json['curso_nombre'] as String?,
      tipoSolicitud: json['tipo_solicitud'] as String,
      estado: json['estado'] as String? ?? 'pendiente',
      datosAnteriores: json['datos_anteriores'] as Map<String, dynamic>?,
      datosNuevos: (json['datos_nuevos'] as Map<String, dynamic>?) ?? {},
      motivo: json['motivo'] as String?,
      observacionRevision: json['observacion_revision'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      fechaRevision: json['fecha_revision'] != null
          ? DateTime.tryParse(json['fecha_revision'].toString())
          : null,
    );
  }

  String get tipoLabel {
    return switch (tipoSolicitud) {
      'crear_alumno' => 'Nuevo Alumno',
      'editar_alumno' => 'Modificar Alumno',
      'eliminar_alumno' => 'Desincorporar Alumno',
      'crear_tema' => 'Nuevo Tema',
      'editar_tema' => 'Modificar Tema',
      'eliminar_tema' => 'Eliminar Tema',
      _ => tipoSolicitud,
    };
  }
}
