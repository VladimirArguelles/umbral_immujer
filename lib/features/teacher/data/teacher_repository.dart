import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/teacher_models.dart';

class TeacherRepository {
  final SupabaseClient _supabase;

  TeacherRepository(this._supabase);

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Cursos asignados al profesor actual
  Future<List<TeacherCourse>> getMyCourses() async {
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
        .eq('profesor_id', uid)
        .eq('estado', 'activo');

    final List<TeacherCourse> list = [];
    for (final item in (cursosData as List)) {
      final inscripciones = item['inscripciones'] as List? ?? [];
      final activas = inscripciones
          .where((i) => i['deleted_at'] == null)
          .length;
      list.add(TeacherCourse.fromJson(item, totalAlumnos: activas));
    }
    return list;
  }

  /// Obtiene los alumnos del curso para la toma de asistencia del día
  Future<List<StudentAttendanceItem>> getStudentsForAttendance({
    required String courseId,
    required String date, // YYYY-MM-DD
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
        .eq('curso_id', courseId)
        .isFilter('deleted_at', null);

    // 2. Asistencias ya guardadas para esa fecha
    final asistenciasExistentes = await _supabase
        .from('asistencia')
        .select('alumno_id, estado')
        .eq('curso_id', courseId)
        .eq('fecha', date);

    final Map<String, String> asistenciaMap = {};
    for (final a in (asistenciasExistentes as List)) {
      asistenciaMap[a['alumno_id'] as String] = a['estado'] as String;
    }

    // 3. Encuesta activa o reciente para este curso y fecha
    final encuesta = await _supabase
        .from('encuestas_participacion')
        .select('id')
        .eq('curso_id', courseId)
        .eq('fecha_clase', date)
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

    final List<StudentAttendanceItem> resultado = [];

    for (final item in (inscritos as List)) {
      final alMap = item['alumnos'] as Map<String, dynamic>?;
      if (alMap == null) continue;

      final alumnoId = alMap['id'] as String;
      // Si ya existe asistencia guardada, usarla; si no, inicializar en 'Ausente'
      final estadoInicial = asistenciaMap[alumnoId] ?? 'Ausente';

      final resp = respMap[alumnoId];

      resultado.add(
        StudentAttendanceItem(
          alumnoId: alumnoId,
          nombreCompleto: (alMap['nombre_completo'] ?? '') as String,
          cedula: (alMap['cedula'] ?? '') as String,
          telefono: alMap['telefono'] as String?,
          estadoAsistencia: estadoInicial,
          confirmoEncuesta: resp?['asistira'] as bool?,
          estadoPago: resp?['estado_pago'] as String?,
        ),
      );
    }

    // Ordenar priorizando los que confirmaron encuesta y pagaron
    resultado.sort((a, b) {
      if ((a.confirmoEncuesta == true) && (b.confirmoEncuesta != true)) {
        return -1;
      }
      if ((a.confirmoEncuesta != true) && (b.confirmoEncuesta == true)) {
        return 1;
      }
      return a.nombreCompleto.compareTo(b.nombreCompleto);
    });

    return resultado;
  }

  /// Guarda o actualiza (Upsert) la lista de asistencia completa del día
  Future<void> saveAttendance({
    required String courseId,
    required String date, // YYYY-MM-DD
    required List<StudentAttendanceItem> students,
  }) async {
    final uid = currentUserId;
    final List<Map<String, dynamic>> records = students.map((a) {
      return {
        'curso_id': courseId,
        'alumno_id': a.alumnoId,
        'fecha': date,
        'estado': a.estadoAsistencia,
        'recorded_by': uid,
      };
    }).toList();

    await _supabase
        .from('asistencia')
        .upsert(records, onConflict: 'curso_id, alumno_id, fecha');
  }

  /// Creación de Encuesta de Insumos por el Profesor
  Future<void> createSurvey({
    required String courseId,
    required String classDate,
    required double totalSupplyCost,
    required DateTime deadline,
  }) async {
    final uid = currentUserId;
    await _supabase.from('encuestas_participacion').insert({
      'curso_id': courseId,
      'fecha_clase': classDate,
      'costo_total_insumos': totalSupplyCost,
      'fecha_limite': deadline.toIso8601String(),
      'creada_por': uid,
      'estado': 'activa',
      'monto_individual_calculado': 0.00,
      'total_confirmados': 0,
    });
  }

  /// Checklist de recaudación para una encuesta dada
  Future<List<PaymentAuditItem>> getSurveyPayments(String surveyId) async {
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
        .eq('encuesta_id', surveyId)
        .eq('asistira', true);

    return (resps as List).map((r) {
      final al = r['alumnos'] as Map<String, dynamic>?;
      return PaymentAuditItem(
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
  Future<void> updatePaymentStatus({
    required String responseId,
    required String status, // 'verificado' | 'rechazado' | 'pendiente'
  }) async {
    await _supabase
        .from('respuestas_encuesta')
        .update({'estado_pago': status})
        .eq('id', responseId);
  }

  /// Retirar alumno de un curso (Soft delete a la papelera con deleted_at)
  Future<void> withdrawStudent({required String enrollmentId}) async {
    await _supabase
        .from('inscripciones')
        .update({
          'estado': 'retirado',
          'deleted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', enrollmentId);
  }

  /// Restaurar alumno desde la papelera
  Future<void> restoreStudent({required String enrollmentId}) async {
    await _supabase
        .from('inscripciones')
        .update({'estado': 'activo', 'deleted_at': null})
        .eq('id', enrollmentId);
  }

  /// Añadir alumno existente del padrón al curso
  Future<void> addStudentToCourse({
    required String courseId,
    required String studentId,
  }) async {
    await _supabase.from('inscripciones').upsert({
      'curso_id': courseId,
      'alumno_id': studentId,
      'estado': 'activo',
      'deleted_at': null,
    }, onConflict: 'curso_id, alumno_id');
  }

  /// Obtener historial completo de alumnos de un curso (activos y en papelera)
  Future<List<ArchivedStudentEnrollment>> getCourseStudentHistory(
    String courseId,
  ) async {
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
        .eq('curso_id', courseId)
        .order('deleted_at', ascending: false);

    return (data as List).map((item) {
      final al = item['alumnos'] as Map<String, dynamic>?;
      return ArchivedStudentEnrollment(
        inscripcionId: item['id'] as String,
        alumnoId: item['alumno_id'] as String,
        nombreCompleto: al?['nombre_completo'] ?? 'Alumno',
        cedula: al?['cedula'] ?? '',
        estado: item['estado'] as String? ?? 'activo',
        deletedAt: item['deleted_at'] != null
            ? DateTime.tryParse(item['deleted_at'] as String)
            : null,
      );
    }).toList();
  }
}
