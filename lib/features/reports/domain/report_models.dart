enum TipoReporte {
  alumnos('Matrícula de Alumnos', 'Listado oficial de inscripciones y datos de contacto'),
  inscripciones('Inscripciones', 'Registro oficial de aspirantes inscritos por fecha, curso y origen'),
  asistencia('Sábana de Asistencia', 'Histórico detallado y porcentaje de asistencia por fecha'),
  temario('Plan Curricular / Temas', 'Módulos, temas y cronograma de formación'),
  profesores('Carga Docente', 'Asignación de profesores y matrícula por curso');

  final String titulo;
  final String descripcion;
  const TipoReporte(this.titulo, this.descripcion);
}

class ReporteAlumnoInscrito {
  final String cursoId;
  final String cursoNombre;
  final String horario;
  final String profesorNombre;
  final String alumnoId;
  final String cedula;
  final String nombreCompleto;
  final String correo;
  final String telefono;
  final String estadoInscripcion;
  final DateTime? fechaInscripcion;

  ReporteAlumnoInscrito({
    required this.cursoId,
    required this.cursoNombre,
    required this.horario,
    required this.profesorNombre,
    required this.alumnoId,
    required this.cedula,
    required this.nombreCompleto,
    required this.correo,
    required this.telefono,
    required this.estadoInscripcion,
    this.fechaInscripcion,
  });

  factory ReporteAlumnoInscrito.fromMap(Map<String, dynamic> map) {
    return ReporteAlumnoInscrito(
      cursoId: map['curso_id'] as String? ?? '',
      cursoNombre: map['curso_nombre'] as String? ?? '',
      horario: map['horario'] as String? ?? 'Por definir',
      profesorNombre: map['profesor_nombre'] as String? ?? 'Sin asignar',
      alumnoId: map['alumno_id'] as String? ?? '',
      cedula: map['cedula'] as String? ?? '',
      nombreCompleto: map['nombre_completo'] as String? ?? '',
      correo: map['correo'] as String? ?? '',
      telefono: map['telefono'] as String? ?? '',
      estadoInscripcion: map['estado_inscripcion'] as String? ?? 'activo',
      fechaInscripcion: map['fecha_inscripcion'] != null
          ? DateTime.tryParse(map['fecha_inscripcion'].toString())
          : null,
    );
  }
}

class ReporteProfesorCurso {
  final String cursoId;
  final String cursoNombre;
  final String horario;
  final String? profesorId;
  final String profesorNombre;
  final String? cedula;
  final String? telefono;
  final String? correo;
  final int totalAlumnos;

  ReporteProfesorCurso({
    required this.cursoId,
    required this.cursoNombre,
    required this.horario,
    this.profesorId,
    required this.profesorNombre,
    this.cedula,
    this.telefono,
    this.correo,
    required this.totalAlumnos,
  });

  factory ReporteProfesorCurso.fromMap(Map<String, dynamic> map) {
    return ReporteProfesorCurso(
      cursoId: map['curso_id'] as String? ?? '',
      cursoNombre: map['curso_nombre'] as String? ?? '',
      horario: map['horario'] as String? ?? 'Por definir',
      profesorId: map['profesor_id'] as String?,
      profesorNombre: map['profesor_nombre'] as String? ?? 'Sin asignar',
      cedula: map['cedula'] as String?,
      telefono: map['telefono'] as String?,
      correo: map['correo'] as String?,
      totalAlumnos: int.tryParse(map['total_alumnos']?.toString() ?? '0') ?? 0,
    );
  }
}

class ReporteTemaCurso {
  final String cursoId;
  final String cursoNombre;
  final String temaId;
  final int orden;
  final String modulo;
  final String titulo;
  final String descripcion;

  ReporteTemaCurso({
    required this.cursoId,
    required this.cursoNombre,
    required this.temaId,
    required this.orden,
    required this.modulo,
    required this.titulo,
    required this.descripcion,
  });

  factory ReporteTemaCurso.fromMap(Map<String, dynamic> map) {
    return ReporteTemaCurso(
      cursoId: map['curso_id'] as String? ?? '',
      cursoNombre: map['curso_nombre'] as String? ?? '',
      temaId: map['tema_id'] as String? ?? '',
      orden: (map['orden'] as num?)?.toInt() ?? 0,
      modulo: map['modulo'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
    );
  }
}

class ReporteAsistenciaResumen {
  final String cursoId;
  final String cursoNombre;
  final DateTime fecha;
  final int totalAlumnos;
  final int totalPresentes;
  final int totalAusentes;
  final double porcentajeAsistencia;

  ReporteAsistenciaResumen({
    required this.cursoId,
    required this.cursoNombre,
    required this.fecha,
    required this.totalAlumnos,
    required this.totalPresentes,
    required this.totalAusentes,
    required this.porcentajeAsistencia,
  });

  factory ReporteAsistenciaResumen.fromMap(Map<String, dynamic> map) {
    return ReporteAsistenciaResumen(
      cursoId: map['curso_id'] as String? ?? '',
      cursoNombre: map['curso_nombre'] as String? ?? '',
      fecha: DateTime.tryParse(map['fecha']?.toString() ?? '') ?? DateTime.now(),
      totalAlumnos: (map['total_alumnos'] as num?)?.toInt() ?? 0,
      totalPresentes: (map['total_presentes'] as num?)?.toInt() ?? 0,
      totalAusentes: (map['total_ausentes'] as num?)?.toInt() ?? 0,
      porcentajeAsistencia: (map['porcentaje_asistencia'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReporteAsistenciaDetallada {
  final String cursoId;
  final String cursoNombre;
  final String alumnoId;
  final String cedula;
  final String nombreCompleto;
  final DateTime fecha;
  final String estado;

  ReporteAsistenciaDetallada({
    required this.cursoId,
    required this.cursoNombre,
    required this.alumnoId,
    required this.cedula,
    required this.nombreCompleto,
    required this.fecha,
    required this.estado,
  });

  factory ReporteAsistenciaDetallada.fromMap(Map<String, dynamic> map) {
    return ReporteAsistenciaDetallada(
      cursoId: map['curso_id'] as String? ?? '',
      cursoNombre: map['curso_nombre'] as String? ?? '',
      alumnoId: map['alumno_id'] as String? ?? '',
      cedula: map['cedula'] as String? ?? '',
      nombreCompleto: map['nombre_completo'] as String? ?? '',
      fecha: DateTime.tryParse(map['fecha']?.toString() ?? '') ?? DateTime.now(),
      estado: map['estado'] as String? ?? 'Presente',
    );
  }
}

class ReporteInscripcion {
  final String inscripcionId;
  final String cursoId;
  final String cursoNombre;
  final String horario;
  final int cupoMaximo;
  final String profesorNombre;
  final String alumnoId;
  final String cedula;
  final String nombreCompleto;
  final String correo;
  final String telefono;
  final String estadoInscripcion;
  final String origen;
  final String? observaciones;
  final DateTime? fechaInscripcion;

  const ReporteInscripcion({
    required this.inscripcionId,
    required this.cursoId,
    required this.cursoNombre,
    required this.horario,
    required this.cupoMaximo,
    required this.profesorNombre,
    required this.alumnoId,
    required this.cedula,
    required this.nombreCompleto,
    required this.correo,
    required this.telefono,
    required this.estadoInscripcion,
    required this.origen,
    this.observaciones,
    this.fechaInscripcion,
  });

  factory ReporteInscripcion.fromMap(Map<String, dynamic> map) {
    return ReporteInscripcion(
      inscripcionId: map['inscripcion_id']?.toString() ?? '',
      cursoId: map['curso_id']?.toString() ?? '',
      cursoNombre: map['curso_nombre']?.toString() ?? '',
      horario: map['horario']?.toString() ?? 'Por definir',
      cupoMaximo: (map['cupo_maximo'] as num?)?.toInt() ?? 30,
      profesorNombre: map['profesor_nombre']?.toString() ?? 'Sin asignar',
      alumnoId: map['alumno_id']?.toString() ?? '',
      cedula: map['cedula']?.toString() ?? '',
      nombreCompleto: map['nombre_completo']?.toString() ?? '',
      correo: map['correo']?.toString() ?? '',
      telefono: map['telefono']?.toString() ?? '',
      estadoInscripcion: map['estado_inscripcion']?.toString() ?? 'activo',
      origen: map['origen']?.toString() ?? 'formulario',
      observaciones: map['observaciones'] as String?,
      fechaInscripcion: map['fecha_inscripcion'] != null
          ? DateTime.tryParse(map['fecha_inscripcion'].toString())?.toLocal()
          : null,
    );
  }
}
