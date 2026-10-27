import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/coordinator_models.dart';

class CoordinatorRepository {
  final SupabaseClient _supabase;

  CoordinatorRepository(this._supabase);

  /// Dashboard global de cursos con conteo de inscritos y ausencias de la jornada actual
  Future<List<CourseDashboardItem>> getCourseDashboard(String date) async {
    final cursosData = await _supabase
        .from('cursos')
        .select('''
          id,
          nombre,
          horario,
          profesor_id,
          profiles:profesor_id (
            nombre_completo
          ),
          inscripciones (
            id,
            deleted_at
          ),
          asistencias (
            id,
            fecha,
            estado
          )
        ''')
        .eq('estado', 'activo');

    final List<CourseDashboardItem> lista = [];

    for (final c in (cursosData as List)) {
      final prof = c['profiles'] as Map<String, dynamic>?;
      final inscripciones = (c['inscripciones'] as List? ?? [])
          .where((i) => i['deleted_at'] == null)
          .toList();
      final asistencias = (c['asistencias'] as List? ?? [])
          .where(
            (a) =>
                a['fecha'] == date &&
                (a['estado'] as String).toLowerCase() == 'ausente',
          )
          .toList();

      lista.add(
        CourseDashboardItem(
          id: c['id'] as String,
          nombre: c['nombre'] as String,
          horario: c['horario'] as String?,
          profesorId: c['profesor_id'] as String?,
          profesorNombre: prof?['nombre_completo'] ?? 'Sin Profesor Asignado',
          alumnosInscritos: inscripciones.length,
          ausenciasHoy: asistencias.length,
        ),
      );
    }

    return lista;
  }

  /// Suscripción en Tiempo Real (Supabase Realtime) a las ausencias marcadas hoy
  Stream<List<Map<String, dynamic>>> streamTodayAttendance(String date) {
    return _supabase
        .from('asistencias')
        .stream(primaryKey: ['id'])
        .eq('fecha', date);
  }

  /// Detalle de ausencias de hoy con nombres de alumno y curso
  Future<List<LiveAbsence>> getTodayAbsences(String date) async {
    final data = await _supabase
        .from('asistencias')
        .select('''
          id,
          fecha,
          created_at,
          cursos:curso_id (
            nombre
          ),
          alumnos:alumno_id (
            nombre_completo,
            cedula
          )
        ''')
        .eq('fecha', date)
        .eq('estado', 'Ausente')
        .order('created_at', ascending: false);

    return (data as List).map((item) {
      final c = item['cursos'] as Map<String, dynamic>?;
      final a = item['alumnos'] as Map<String, dynamic>?;

      return LiveAbsence(
        asistenciaId: item['id'] as String,
        cursoNombre: c?['nombre'] ?? 'Curso',
        alumnoNombre: a?['nombre_completo'] ?? 'Alumno',
        cedula: a?['cedula'] ?? '',
        fecha: item['fecha'] as String,
        horaMarcada: item['created_at'] != null
            ? DateTime.tryParse(item['created_at'] as String)
            : null,
      );
    }).toList();
  }

  /// Lista de profesores registrados para asignación
  Future<List<AvailableTeacher>> getRegisteredTeachers() async {
    final profs = await _supabase
        .from('profiles')
        .select('id, nombre_completo, cedula, telefono, correo')
        .eq('rol', 'profesor');

    final List<AvailableTeacher> list = [];
    for (final p in (profs as List)) {
      // Curso actual si tiene
      final cursoActual = await _supabase
          .from('cursos')
          .select('nombre')
          .eq('profesor_id', p['id'])
          .eq('estado', 'activo')
          .maybeSingle();

      list.add(
        AvailableTeacher(
          id: p['id'] as String,
          nombreCompleto: p['nombre_completo'] as String,
          cedula: (p['cedula'] ?? '') as String,
          telefono: p['telefono'] as String?,
          correo: p['correo'] as String?,
          cursoActual: cursoActual?['nombre'] as String?,
        ),
      );
    }
    return list;
  }

  /// Reasignación o asignación de un profesor a un curso
  Future<void> assignTeacherToCourse({
    required String courseId,
    required String teacherId,
  }) async {
    await _supabase
        .from('cursos')
        .update({'profesor_id': teacherId})
        .eq('id', courseId);
  }

  /// Desasignar profesor de un curso (dejar sin profesor asignado temporalmente)
  Future<void> unassignTeacher({required String courseId}) async {
    await _supabase
        .from('cursos')
        .update({'profesor_id': null})
        .eq('id', courseId);
  }

  /// Auditoría de encuestas e insumos en todos los cursos
  Future<List<SurveyAudit>> getSurveyAudits() async {
    final data = await _supabase
        .from('encuestas')
        .select('''
          id,
          fecha_clase,
          costo_total_insumos,
          total_confirmados,
          monto_individual_calculado,
          estado,
          cursos:curso_id (
            nombre
          )
        ''')
        .order('fecha_clase', ascending: false);

    return (data as List).map((e) {
      final c = e['cursos'] as Map<String, dynamic>?;
      return SurveyAudit(
        id: e['id'] as String,
        cursoNombre: c?['nombre'] ?? 'Curso',
        fechaClase: e['fecha_clase']?.toString() ?? '',
        costoTotal: (e['costo_total_insumos'] as num?)?.toDouble() ?? 0.0,
        totalConfirmados: (e['total_confirmados'] as num?)?.toInt() ?? 0,
        montoIndividual:
            (e['monto_individual_calculado'] as num?)?.toDouble() ?? 0.0,
        estado: e['estado'] as String? ?? 'activa',
      );
    }).toList();
  }
}
