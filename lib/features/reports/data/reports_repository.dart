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
}
