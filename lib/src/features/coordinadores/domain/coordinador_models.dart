class DashboardCurso {
  final String id;
  final String nombre;
  final String? horario;
  final String? profesorId;
  final String? profesorNombre;
  final int alumnosInscritos;
  final int ausenciasHoy;

  DashboardCurso({
    required this.id,
    required this.nombre,
    this.horario,
    this.profesorId,
    this.profesorNombre,
    required this.alumnosInscritos,
    required this.ausenciasHoy,
  });
}

class AusenciaTiempoReal {
  final String asistenciaId;
  final String cursoNombre;
  final String alumnoNombre;
  final String cedula;
  final String fecha;
  final DateTime? horaMarcada;

  AusenciaTiempoReal({
    required this.asistenciaId,
    required this.cursoNombre,
    required this.alumnoNombre,
    required this.cedula,
    required this.fecha,
    this.horaMarcada,
  });
}

class ProfesorDisponible {
  final String id;
  final String nombreCompleto;
  final String cedula;
  final String? telefono;
  final String? correo;
  final String? cursoActual;

  ProfesorDisponible({
    required this.id,
    required this.nombreCompleto,
    required this.cedula,
    this.telefono,
    this.correo,
    this.cursoActual,
  });
}

class AuditoriaEncuesta {
  final String id;
  final String cursoNombre;
  final String fechaClase;
  final double costoTotal;
  final int totalConfirmados;
  final double montoIndividual;
  final String estado;

  AuditoriaEncuesta({
    required this.id,
    required this.cursoNombre,
    required this.fechaClase,
    required this.costoTotal,
    required this.totalConfirmados,
    required this.montoIndividual,
    required this.estado,
  });
}
