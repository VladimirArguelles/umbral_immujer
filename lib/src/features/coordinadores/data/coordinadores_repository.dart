import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/coordinador_models.dart';

class CoordinadoresRepository {
  final SupabaseClient _supabase;

  CoordinadoresRepository(this._supabase);

  /// Dashboard global de cursos con conteo de inscritos y ausencias de la jornada actual
  Future<List<DashboardCurso>> getCursosDashboard(String fechaHoy) async {
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

    final List<DashboardCurso> lista = [];

    for (final c in (cursosData as List)) {
      final prof = c['profiles'] as Map<String, dynamic>?;
      final inscripciones = (c['inscripciones'] as List? ?? []).where((i) => i['deleted_at'] == null).toList();
      final asistencias = (c['asistencias'] as List? ?? []).where((a) => a['fecha'] == fechaHoy && (a['estado'] as String).toLowerCase() == 'ausente').toList();

      lista.add(DashboardCurso(
        id: c['id'] as String,
        nombre: c['nombre'] as String,
        horario: c['horario'] as String?,
        profesorId: c['profesor_id'] as String?,
        profesorNombre: prof?['nombre_completo'] ?? 'Sin Profesor Asignado',
        alumnosInscritos: inscripciones.length,
        ausenciasHoy: asistencias.length,
      ));
    }

    return lista;
  }

  /// Suscripción en Tiempo Real (Supabase Realtime) a las ausencias marcadas hoy
  Stream<List<Map<String, dynamic>>> streamAsistenciasHoy(String fechaHoy) {
    return _supabase
        .from('asistencias')
        .stream(primaryKey: ['id'])
        .eq('fecha', fechaHoy);
  }

  /// Detalle de ausencias de hoy con nombres de alumno y curso
  Future<List<AusenciaTiempoReal>> getDetalleAusenciasHoy(String fechaHoy) async {
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
        .eq('fecha', fechaHoy)
        .eq('estado', 'Ausente')
        .order('created_at', ascending: false);

    return (data as List).map((item) {
      final c = item['cursos'] as Map<String, dynamic>?;
      final a = item['alumnos'] as Map<String, dynamic>?;

      return AusenciaTiempoReal(
        asistenciaId: item['id'] as String,
        cursoNombre: c?['nombre'] ?? 'Curso',
        alumnoNombre: a?['nombre_completo'] ?? 'Alumno',
        cedula: a?['cedula'] ?? '',
        fecha: item['fecha'] as String,
        horaMarcada: item['created_at'] != null ? DateTime.tryParse(item['created_at'] as String) : null,
      );
    }).toList();
  }

  /// Lista de profesores registrados para asignación
  Future<List<ProfesorDisponible>> getProfesoresRegistrados() async {
    final profs = await _supabase
        .from('profiles')
        .select('id, nombre_completo, cedula, telefono, correo')
        .eq('rol', 'profesor');

    final List<ProfesorDisponible> list = [];
    for (final p in (profs as List)) {
      // Curso actual si tiene
      final cursoActual = await _supabase
          .from('cursos')
          .select('nombre')
          .eq('profesor_id', p['id'])
          .eq('estado', 'activo')
          .maybeSingle();

      list.add(ProfesorDisponible(
        id: p['id'] as String,
        nombreCompleto: p['nombre_completo'] as String,
        cedula: (p['cedula'] ?? '') as String,
        telefono: p['telefono'] as String?,
        correo: p['correo'] as String?,
        cursoActual: cursoActual?['nombre'] as String?,
      ));
    }
    return list;
  }

  /// Reasignación o asignación de un profesor a un curso
  Future<void> asignarProfesorACurso({
    required String cursoId,
    required String profesorId,
  }) async {
    await _supabase
        .from('cursos')
        .update({'profesor_id': profesorId})
        .eq('id', cursoId);
  }

  /// Desasignar profesor de un curso (dejar sin profesor asignado temporalmente)
  Future<void> desasignarProfesor({required String cursoId}) async {
    await _supabase
        .from('cursos')
        .update({'profesor_id': null})
        .eq('id', cursoId);
  }

  /// Auditoría de encuestas e insumos en todos los cursos
  Future<List<AuditoriaEncuesta>> getAuditoriaEncuestas() async {
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
      return AuditoriaEncuesta(
        id: e['id'] as String,
        cursoNombre: c?['nombre'] ?? 'Curso',
        fechaClase: e['fecha_clase']?.toString() ?? '',
        costoTotal: (e['costo_total_insumos'] as num?)?.toDouble() ?? 0.0,
        totalConfirmados: (e['total_confirmados'] as num?)?.toInt() ?? 0,
        montoIndividual: (e['monto_individual_calculado'] as num?)?.toDouble() ?? 0.0,
        estado: e['estado'] as String? ?? 'activa',
      );
    }).toList();
  }
}
