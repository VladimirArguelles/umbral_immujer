class CourseDashboardItem {
  final String id;
  final String nombre;
  final String? horario;
  final String? profesorId;
  final String? profesorNombre;
  final int alumnosInscritos;
  final int ausenciasHoy;

  CourseDashboardItem({
    required this.id,
    required this.nombre,
    this.horario,
    this.profesorId,
    this.profesorNombre,
    required this.alumnosInscritos,
    required this.ausenciasHoy,
  });
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
