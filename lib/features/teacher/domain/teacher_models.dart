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
