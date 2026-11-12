import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/report_models.dart';

class ReportsRepository {
  final SupabaseClient _client;

  ReportsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Obtiene la lista básica de cursos para los filtros
  Future<List<Map<String, String>>> getCursosParaFiltro() async {
    final response = await _client
        .from('cursos')
        .select('id, nombre')
        .order('nombre', ascending: true);

    return (response as List)
        .map((c) => {
              'id': c['id'].toString(),
              'nombre': c['nombre'].toString(),
            })
        .toList();
  }

  /// Obtiene la matrícula de alumnos filtrada opcionalmente por curso
  Future<List<ReporteAlumnoInscrito>> getAlumnosPorCurso({String? cursoId}) async {
    var query = _client.from('view_reporte_alumnos_curso').select();

    if (cursoId != null && cursoId.isNotEmpty && cursoId != 'todos') {
      query = query.eq('curso_id', cursoId);
    }

    final response = await query.order('curso_nombre').order('nombre_completo');
    return (response as List)
        .map((item) => ReporteAlumnoInscrito.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene la carga docente y relación de profesores por curso
  Future<List<ReporteProfesorCurso>> getProfesoresCursos({String? cursoId}) async {
    var query = _client.from('view_reporte_profesores_cursos').select();

    if (cursoId != null && cursoId.isNotEmpty && cursoId != 'todos') {
      query = query.eq('curso_id', cursoId);
    }

    final response = await query.order('curso_nombre');
    return (response as List)
        .map((item) => ReporteProfesorCurso.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene el temario y plan de formación por curso
  Future<List<ReporteTemaCurso>> getTemasPorCurso({String? cursoId}) async {
    var query = _client.from('view_reporte_temas_curso').select();

    if (cursoId != null && cursoId.isNotEmpty && cursoId != 'todos') {
      query = query.eq('curso_id', cursoId);
    }

    final response = await query.order('curso_nombre').order('orden');
    return (response as List)
        .map((item) => ReporteTemaCurso.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene el resumen consolidado de asistencia por curso y fecha
  Future<List<ReporteAsistenciaResumen>> getAsistenciaResumen({String? cursoId}) async {
    var query = _client.from('view_reporte_asistencia_resumen').select();

    if (cursoId != null && cursoId.isNotEmpty && cursoId != 'todos') {
      query = query.eq('curso_id', cursoId);
    }

    final response = await query.order('fecha', ascending: false).order('curso_nombre');
    return (response as List)
        .map((item) => ReporteAsistenciaResumen.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene el detalle individual de asistencia para la sábana
  Future<List<ReporteAsistenciaDetallada>> getAsistenciaDetallada({
    String? cursoId,
    DateTime? fecha,
  }) async {
    var query = _client.from('view_reporte_asistencia_detallada').select();

    if (cursoId != null && cursoId.isNotEmpty && cursoId != 'todos') {
      query = query.eq('curso_id', cursoId);
    }
    if (fecha != null) {
      final fechaStr = fecha.toIso8601String().split('T')[0];
      query = query.eq('fecha', fechaStr);
    }

    final response = await query.order('nombre_completo').order('fecha');
    return (response as List)
        .map((item) => ReporteAsistenciaDetallada.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene el listado oficial de inscripciones filtrable por curso.
  Future<List<ReporteInscripcion>> getInscripcionesReporte({
    String? cursoId,
  }) async {
    try {
      var query = _client.from('view_reporte_inscripciones').select();
      if (cursoId != null && cursoId.isNotEmpty && cursoId != 'todos') {
        query = query.eq('curso_id', cursoId);
      }
      final response = await query
          .order('fecha_inscripcion', ascending: false)
          .order('nombre_completo');
      return (response as List)
          .map((item) => ReporteInscripcion.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      // Fallback directo sobre tabla inscripciones si la vista aún no existe.
    }

    var query = _client
        .from('inscripciones')
        .select('''
          id,
          curso_id,
          alumno_id,
          estado,
          origen,
          observaciones,
          created_at,
          cursos:curso_id (
            nombre,
            horario,
            cupo_maximo,
            perfiles:profesor_id ( nombre_completo )
          ),
          alumnos:alumno_id (
            id,
            cedula,
            nombre_completo,
            correo,
            telefono
          )
        ''')
        .isFilter('deleted_at', null);

    if (cursoId != null && cursoId.isNotEmpty && cursoId != 'todos') {
      query = query.eq('curso_id', cursoId);
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      final curso = map['cursos'] as Map<String, dynamic>?;
      final profesor = curso?['perfiles'] as Map<String, dynamic>?;
      final alumno = map['alumnos'] as Map<String, dynamic>?;
      return ReporteInscripcion(
        inscripcionId: (map['id'] ?? '').toString(),
        cursoId: (map['curso_id'] ?? '').toString(),
        cursoNombre: (curso?['nombre'] ?? '').toString(),
        horario: (curso?['horario'] ?? 'Por definir').toString(),
        cupoMaximo: (curso?['cupo_maximo'] as num?)?.toInt() ?? 30,
        profesorNombre: (profesor?['nombre_completo'] ?? 'Sin asignar').toString(),
        alumnoId: (map['alumno_id'] ?? alumno?['id'] ?? '').toString(),
        cedula: (alumno?['cedula'] ?? '').toString(),
        nombreCompleto: (alumno?['nombre_completo'] ?? '').toString(),
        correo: (alumno?['correo'] ?? '').toString(),
        telefono: (alumno?['telefono'] ?? '').toString(),
        estadoInscripcion: (map['estado'] ?? 'activo').toString(),
        origen: (map['origen'] ?? 'formulario').toString(),
        observaciones: map['observaciones'] as String?,
        fechaInscripcion: DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal(),
      );
    }).toList();
  }
}
