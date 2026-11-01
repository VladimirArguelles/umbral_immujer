class CourseDashboardItem {
  final String id;
  final String nombre;
  final String? horario;
  final String? profesorId;
  final String? profesorNombre;
  final int alumnosInscritos;
  final int ausenciasHoy;
  final int presentesHoy;

  CourseDashboardItem({
    required this.id,
    required this.nombre,
    this.horario,
    this.profesorId,
    this.profesorNombre,
    required this.alumnosInscritos,
    required this.ausenciasHoy,
    this.presentesHoy = 0,
  });

  double get porcentajeAsistencia {
    final total = presentesHoy + ausenciasHoy;
    if (total == 0) return 100.0;
    return (presentesHoy / total) * 100;
  }
}

class LiveAbsence {
  final String asistenciaId;
  final String cursoNombre;
  final String alumnoNombre;
  final String cedula;
  final String fecha;
  final DateTime? horaMarcada;

  LiveAbsence({
    required this.asistenciaId,
    required this.cursoNombre,
    required this.alumnoNombre,
    required this.cedula,
    required this.fecha,
    this.horaMarcada,
  });
}

class AvailableTeacher {
  final String id;
  final String nombreCompleto;
  final String cedula;
  final String? telefono;
  final String? correo;
  final String? cursoActual;

  AvailableTeacher({
    required this.id,
    required this.nombreCompleto,
    required this.cedula,
    this.telefono,
    this.correo,
    this.cursoActual,
  });
}

class SurveyAudit {
  final String id;
  final String cursoNombre;
  final String fechaClase;
  final double costoTotal;
  final int totalConfirmados;
  final double montoIndividual;
  final String estado;

  SurveyAudit({
    required this.id,
    required this.cursoNombre,
    required this.fechaClase,
    required this.costoTotal,
    required this.totalConfirmados,
    required this.montoIndividual,
    required this.estado,
  });
}

class JustificativoRevisionItem {
  final String id;
  final String cursoId;
  final String cursoNombre;
  final String alumnoId;
  final String alumnoNombre;
  final String cedula;
  final String fecha;
  final String motivo;
  final String? comprobanteUrl;
  final String estado; // 'pendiente' | 'aprobado' | 'rechazado'
  final DateTime createdAt;

  JustificativoRevisionItem({
    required this.id,
    required this.cursoId,
    required this.cursoNombre,
    required this.alumnoId,
    required this.alumnoNombre,
    required this.cedula,
    required this.fecha,
    required this.motivo,
    this.comprobanteUrl,
    required this.estado,
    required this.createdAt,
  });

  factory JustificativoRevisionItem.fromJson(Map<String, dynamic> json) {
    final c = json['cursos'] as Map<String, dynamic>?;
    final a = json['alumnos'] as Map<String, dynamic>?;

    return JustificativoRevisionItem(
      id: json['id'] as String,
      cursoId: (json['curso_id'] ?? '') as String,
      cursoNombre: c?['nombre'] ?? 'Curso',
      alumnoId: (json['alumno_id'] ?? '') as String,
      alumnoNombre: a?['nombre_completo'] ?? 'Alumno',
      cedula: a?['cedula'] ?? '',
      fecha: json['fecha']?.toString() ?? '',
      motivo: json['motivo']?.toString() ?? '',
      comprobanteUrl: json['comprobante_url'] as String?,
      estado: json['estado'] as String? ?? 'pendiente',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class AporteCursoBsItem {
  final String surveyId;
  final String cursoNombre;
  final String fechaClase;
  final double costoTotalUsd;
  final double tasaBcvUsada;
  final int totalConfirmados;
  final double cuotaBs;
  final double totalAporteBs;

  AporteCursoBsItem({
    required this.surveyId,
    required this.cursoNombre,
    required this.fechaClase,
    required this.costoTotalUsd,
    required this.tasaBcvUsada,
    required this.totalConfirmados,
    required this.cuotaBs,
    required this.totalAporteBs,
  });
}

class SolicitudNotificacionItem {
  final String id;
  final String profesorId;
  final String profesorNombre;
  final String cursoId;
  final String cursoNombre;
  final String tipoSolicitud;
  final String estado;
  final Map<String, dynamic>? datosAnteriores;
  final Map<String, dynamic> datosNuevos;
  final String? motivo;
  final DateTime createdAt;

  SolicitudNotificacionItem({
    required this.id,
    required this.profesorId,
    required this.profesorNombre,
    required this.cursoId,
    required this.cursoNombre,
    required this.tipoSolicitud,
    required this.estado,
    this.datosAnteriores,
    required this.datosNuevos,
    this.motivo,
    required this.createdAt,
  });

  factory SolicitudNotificacionItem.fromJson(Map<String, dynamic> json) {
    return SolicitudNotificacionItem(
      id: json['id'] as String,
      profesorId: (json['profesor_id'] ?? '') as String,
      profesorNombre: json['profesor_nombre'] ?? 'Profesor',
      cursoId: (json['curso_id'] ?? '') as String,
      cursoNombre: json['curso_nombre'] ?? 'Curso',
      tipoSolicitud: json['tipo_solicitud'] as String,
      estado: json['estado'] as String? ?? 'pendiente',
      datosAnteriores: json['datos_anteriores'] as Map<String, dynamic>?,
      datosNuevos: (json['datos_nuevos'] as Map<String, dynamic>?) ?? {},
      motivo: json['motivo'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get tipoLabel {
    return switch (tipoSolicitud) {
      'crear_alumno' => 'Añadir Alumno',
      'editar_alumno' => 'Modificar Datos de Alumno',
      'eliminar_alumno' => 'Desincorporar Alumno',
      'crear_tema' => 'Añadir Nuevo Tema',
      'editar_tema' => 'Editar Tema',
      'eliminar_tema' => 'Eliminar Tema',
      _ => tipoSolicitud,
    };
  }
}
