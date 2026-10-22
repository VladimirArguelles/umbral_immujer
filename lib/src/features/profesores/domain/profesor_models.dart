class CursoProfesor {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? horario;
  final int totalAlumnos;

  CursoProfesor({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.horario,
    required this.totalAlumnos,
  });

  factory CursoProfesor.fromJson(Map<String, dynamic> json, {int totalAlumnos = 0}) {
    return CursoProfesor(
      id: (json['id'] ?? '') as String,
      nombre: (json['nombre'] ?? 'Curso') as String,
      descripcion: json['descripcion'] as String?,
      horario: json['horario'] as String?,
      totalAlumnos: totalAlumnos,
    );
  }
}

class AlumnoListaAsistencia {
  final String alumnoId;
  final String nombreCompleto;
  final String cedula;
  final String? telefono;
  String estadoAsistencia; // 'Presente' | 'Ausente'
  final bool? confirmoEncuesta;
  final String? estadoPago;

  AlumnoListaAsistencia({
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

class ItemRecaudacion {
  final String respuestaId;
  final String alumnoId;
  final String nombreCompleto;
  final String cedula;
  final double monto;
  final String estadoPago; // 'pendiente' | 'verificado' | 'rechazado'
  final String? comprobanteUrl;

  ItemRecaudacion({
    required this.respuestaId,
    required this.alumnoId,
    required this.nombreCompleto,
    required this.cedula,
    required this.monto,
    required this.estadoPago,
    this.comprobanteUrl,
  });
}

class AlumnoPapelera {
  final String inscripcionId;
  final String alumnoId;
  final String nombreCompleto;
  final String cedula;
  final String estado; // 'activo' | 'retirado'
  final DateTime? deletedAt;

  AlumnoPapelera({
    required this.inscripcionId,
    required this.alumnoId,
    required this.nombreCompleto,
    required this.cedula,
    required this.estado,
    this.deletedAt,
  });

  bool get estaEliminado => deletedAt != null || estado == 'retirado';
}
