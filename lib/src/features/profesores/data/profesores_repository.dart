import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/profesor_models.dart';

class ProfesoresRepository {
  final SupabaseClient _supabase;

  ProfesoresRepository(this._supabase);

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Cursos asignados al profesor actual
  Future<List<CursoProfesor>> getCursosDelProfesor() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final cursosData = await _supabase
        .from('cursos')
        .select('''
          id,
          nombre,
          descripcion,
          horario,
          estado,
          profesor_id,
          inscripciones (
            id,
            deleted_at
          )
        ''')
        .or('profesor_id.eq.$uid,profesor_id.is.null')
        .eq('estado', 'activo');

    final List<CursoProfesor> list = [];
    for (final item in (cursosData as List)) {
      final inscripciones = item['inscripciones'] as List? ?? [];
      final activas = inscripciones.where((i) => i['deleted_at'] == null).length;
      list.add(CursoProfesor.fromJson(item, totalAlumnos: activas));
    }
    return list;
  }

  /// Obtiene los alumnos del curso para la toma de asistencia del día
  Future<List<AlumnoListaAsistencia>> getAlumnosParaAsistencia({
    required String cursoId,
    required String fecha, // YYYY-MM-DD
  }) async {
    // 1. Alumnos inscritos activos
    final inscritos = await _supabase
        .from('inscripciones')
        .select('''
          alumno_id,
          alumnos:alumno_id (
            id,
            nombre_completo,
            cedula,
            telefono
          )
        ''')
        .eq('curso_id', cursoId)
        .isFilter('deleted_at', null);

    // 2. Asistencias ya guardadas para esa fecha
    final asistenciasExistentes = await _supabase
        .from('asistencias')
        .select('alumno_id, estado')
        .eq('curso_id', cursoId)
        .eq('fecha', fecha);

    final Map<String, String> asistenciaMap = {};
    for (final a in (asistenciasExistentes as List)) {
      asistenciaMap[a['alumno_id'] as String] = a['estado'] as String;
    }

    // 3. Encuesta activa o reciente para este curso y fecha
    final encuesta = await _supabase
        .from('encuestas')
        .select('id')
        .eq('curso_id', cursoId)
        .eq('fecha_clase', fecha)
        .maybeSingle();

    final Map<String, Map<String, dynamic>> respMap = {};
    if (encuesta != null) {
      final resps = await _supabase
          .from('respuestas_encuesta')
          .select('alumno_id, asistira, estado_pago')
          .eq('encuesta_id', encuesta['id']);
      for (final r in (resps as List)) {
        respMap[r['alumno_id'] as String] = r;
      }
    }

    final List<AlumnoListaAsistencia> resultado = [];

    for (final item in (inscritos as List)) {
      final alMap = item['alumnos'] as Map<String, dynamic>?;
      if (alMap == null) continue;

      final alumnoId = alMap['id'] as String;
      // Si ya existe asistencia guardada, usarla; si no, inicializar en 'Ausente'
      final estadoInicial = asistenciaMap[alumnoId] ?? 'Ausente';

      final resp = respMap[alumnoId];

      resultado.add(AlumnoListaAsistencia(
        alumnoId: alumnoId,
        nombreCompleto: (alMap['nombre_completo'] ?? '') as String,
        cedula: (alMap['cedula'] ?? '') as String,
        telefono: alMap['telefono'] as String?,
        estadoAsistencia: estadoInicial,
        confirmoEncuesta: resp?['asistira'] as bool?,
        estadoPago: resp?['estado_pago'] as String?,
      ));
    }

    // Ordenar priorizando los que confirmaron encuesta y pagaron
    resultado.sort((a, b) {
      if ((a.confirmoEncuesta == true) && (b.confirmoEncuesta != true)) return -1;
      if ((a.confirmoEncuesta != true) && (b.confirmoEncuesta == true)) return 1;
      return a.nombreCompleto.compareTo(b.nombreCompleto);
    });

    return resultado;
  }

  /// Guarda o actualiza (Upsert) la lista de asistencia completa del día
  Future<void> guardarAsistencia({
    required String cursoId,
    required String fecha, // YYYY-MM-DD
    required List<AlumnoListaAsistencia> alumnos,
  }) async {
    final uid = currentUserId;
    final List<Map<String, dynamic>> records = alumnos.map((a) {
      return {
        'curso_id': cursoId,
        'alumno_id': a.alumnoId,
        'fecha': fecha,
        'estado': a.estadoAsistencia,
        'recorded_by': uid,
      };
    }).toList();

    await _supabase.from('asistencias').upsert(
      records,
      onConflict: 'curso_id, alumno_id, fecha',
    );
  }

  /// Creación de Encuesta de Insumos por el Profesor
  Future<void> crearEncuesta({
    required String cursoId,
    required String fechaClase,
    required double costoTotalInsumos,
    required DateTime fechaLimite,
  }) async {
    final uid = currentUserId;
    await _supabase.from('encuestas').insert({
      'curso_id': cursoId,
      'fecha_clase': fechaClase,
      'costo_total_insumos': costoTotalInsumos,
      'fecha_limite': fechaLimite.toIso8601String(),
      'creada_por': uid,
      'estado': 'activa',
      'monto_individual_calculado': 0.00,
      'total_confirmados': 0,
    });
  }

  /// Checklist de recaudación para una encuesta dada
  Future<List<ItemRecaudacion>> getRecaudacionEncuesta(String encuestaId) async {
    final resps = await _supabase
        .from('respuestas_encuesta')
        .select('''
          id,
          alumno_id,
          monto_asignado,
          estado_pago,
          comprobante_url,
          asistira,
          alumnos:alumno_id (
            nombre_completo,
            cedula
          )
        ''')
        .eq('encuesta_id', encuestaId)
        .eq('asistira', true);

    return (resps as List).map((r) {
      final al = r['alumnos'] as Map<String, dynamic>?;
      return ItemRecaudacion(
        respuestaId: r['id'] as String,
        alumnoId: r['alumno_id'] as String,
        nombreCompleto: al?['nombre_completo'] ?? 'Alumno',
        cedula: al?['cedula'] ?? '',
        monto: (r['monto_asignado'] as num?)?.toDouble() ?? 0.0,
        estadoPago: r['estado_pago'] as String? ?? 'pendiente',
        comprobanteUrl: r['comprobante_url'] as String?,
      );
    }).toList();
  }

  /// Actualizar verificación de pago por parte del profesor
  Future<void> actualizarEstadoPago({
    required String respuestaId,
    required String estado, // 'verificado' | 'rechazado' | 'pendiente'
  }) async {
    await _supabase
        .from('respuestas_encuesta')
        .update({'estado_pago': estado})
        .eq('id', respuestaId);
  }

  /// Retirar alumno de un curso (Soft delete a la papelera con deleted_at)
  Future<void> retirarAlumno({required String inscripcionId}) async {
    await _supabase.from('inscripciones').update({
      'estado': 'retirado',
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', inscripcionId);
  }

  /// Restaurar alumno desde la papelera
  Future<void> restaurarAlumno({required String inscripcionId}) async {
    await _supabase.from('inscripciones').update({
      'estado': 'activo',
      'deleted_at': null,
    }).eq('id', inscripcionId);
  }

  /// Añadir alumno existente del padrón al curso
  Future<void> agregarAlumnoAlCurso({
    required String cursoId,
    required String alumnoId,
  }) async {
    await _supabase.from('inscripciones').upsert({
      'curso_id': cursoId,
      'alumno_id': alumnoId,
      'estado': 'activo',
      'deleted_at': null,
    }, onConflict: 'curso_id, alumno_id');
  }

  /// Obtener historial completo de alumnos de un curso (activos y en papelera)
  Future<List<AlumnoPapelera>> getHistorialAlumnosCurso(String cursoId) async {
    final data = await _supabase
        .from('inscripciones')
        .select('''
          id,
          alumno_id,
          estado,
          deleted_at,
          alumnos:alumno_id (
            nombre_completo,
            cedula
          )
        ''')
        .eq('curso_id', cursoId)
        .order('deleted_at', ascending: false);

    return (data as List).map((item) {
      final al = item['alumnos'] as Map<String, dynamic>?;
      return AlumnoPapelera(
        inscripcionId: item['id'] as String,
        alumnoId: item['alumno_id'] as String,
        nombreCompleto: al?['nombre_completo'] ?? 'Alumno',
        cedula: al?['cedula'] ?? '',
        estado: item['estado'] as String? ?? 'activo',
        deletedAt: item['deleted_at'] != null ? DateTime.tryParse(item['deleted_at'] as String) : null,
      );
    }).toList();
  }
}
