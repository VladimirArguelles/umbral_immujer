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
          perfiles:profesor_id (
            nombre_completo
          ),
          inscripciones (
            id,
            deleted_at
          ),
          asistencia (
            id,
            fecha,
            estado
          )
        ''')
        .eq('estado', 'activo');

    final List<CourseDashboardItem> lista = [];

    for (final c in (cursosData as List)) {
      final prof = c['perfiles'] as Map<String, dynamic>?;
      final inscripciones = (c['inscripciones'] as List? ?? [])
          .where((i) => i['deleted_at'] == null)
          .toList();
      final asistencias = c['asistencia'] as List? ?? [];
      final ausencias = asistencias
          .where(
            (a) =>
                a['fecha'] == date &&
                (a['estado'] as String).toLowerCase() == 'ausente',
          )
          .length;
      final presentes = asistencias
          .where(
            (a) =>
                a['fecha'] == date &&
                (a['estado'] as String).toLowerCase() == 'presente',
          )
          .length;

      lista.add(
        CourseDashboardItem(
          id: c['id'] as String,
          nombre: c['nombre'] as String,
          horario: c['horario'] as String?,
          profesorId: c['profesor_id'] as String?,
          profesorNombre: prof?['nombre_completo'] ?? 'Sin Profesor Asignado',
          alumnosInscritos: inscripciones.length,
          ausenciasHoy: ausencias,
          presentesHoy: presentes,
        ),
      );
    }

    return lista;
  }

  /// Suscripción en Tiempo Real (Supabase Realtime) a las ausencias marcadas hoy
  Stream<List<Map<String, dynamic>>> streamTodayAttendance(String date) {
    return _supabase
        .from('asistencia')
        .stream(primaryKey: ['id'])
        .eq('fecha', date);
  }

  /// Detalle de ausencias de hoy con nombres de alumno y curso
  Future<List<LiveAbsence>> getTodayAbsences(String date) async {
    final data = await _supabase
        .from('asistencia')
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

  /// Pre-registro manual de un profesor por parte del coordinador durante inscripciones.
  /// Campos obligatorios: nombre completo, cédula, teléfono y rol ('profesor' o 'teacher').
  /// El campo email/correo es opcional (permite NULL) durante esta fase inicial.
  Future<Map<String, dynamic>> preRegisterTeacher({
    required String nombreCompleto,
    required String cedula,
    required String telefono,
    String? email,
  }) async {
    final cleanCedula = cedula.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    final cleanEmail =
        (email != null && email.trim().isNotEmpty) ? email.trim() : null;

    final data = {
      'nombre_completo': nombreCompleto.trim(),
      'cedula': cleanCedula,
      'telefono': telefono.trim(),
      'correo': cleanEmail,
      'email': cleanEmail,
      'rol': 'profesor',
    };

    final result = await _supabase
        .from('perfiles')
        .insert(data)
        .select()
        .single();

    return result;
  }

  /// Lista de profesores registrados para asignación
  Future<List<AvailableTeacher>> getRegisteredTeachers() async {
    final profs = await _supabase
        .from('perfiles')
        .select('id, nombre_completo, cedula, telefono, correo')
        .inFilter('rol', ['profesor', 'teacher']);

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
        .from('encuestas_participacion')
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

  /// Solicitudes de aprobación pendientes de profesores
  Future<List<SolicitudNotificacionItem>> getPendingApprovalRequests() async {
    try {
      final data = await _supabase
          .from('solicitudes_aprobacion')
          .select()
          .eq('estado', 'pendiente')
          .order('created_at', ascending: false);

      return (data as List)
          .map((item) =>
              SolicitudNotificacionItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Aprobar solicitud de profesor
  Future<void> approveApprovalRequest(
    String solicitudId, {
    String? observacion,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    try {
      await _supabase.rpc('aprobar_solicitud', params: {
        'p_solicitud_id': solicitudId,
        'p_revisor_id': uid,
        'p_observacion': observacion,
      });
    } catch (_) {
      // Fallback manual si no está creado el RPC
      await _supabase.from('solicitudes_aprobacion').update({
        'estado': 'aprobado',
        'revisado_por': uid,
        'fecha_revision': DateTime.now().toIso8601String(),
        'observacion_revision': observacion,
      }).eq('id', solicitudId);
    }
  }

  /// Rechazar solicitud de profesor
  Future<void> rejectApprovalRequest(
    String solicitudId, {
    required String observacion,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    try {
      await _supabase.rpc('rechazar_solicitud', params: {
        'p_solicitud_id': solicitudId,
        'p_revisor_id': uid,
        'p_observacion': observacion,
      });
    } catch (_) {
      await _supabase.from('solicitudes_aprobacion').update({
        'estado': 'rechazado',
        'revisado_por': uid,
        'fecha_revision': DateTime.now().toIso8601String(),
        'observacion_revision': observacion,
      }).eq('id', solicitudId);
    }
  }

  /// Justificativos de asistencia enviados por los alumnos para revisión
  Future<List<JustificativoRevisionItem>> getJustificativosRevision() async {
    try {
      final data = await _supabase
          .from('justificativos_asistencia')
          .select('''
            id,
            curso_id,
            alumno_id,
            fecha,
            motivo,
            comprobante_url,
            estado,
            created_at,
            cursos:curso_id (
              nombre
            ),
            alumnos:alumno_id (
              nombre_completo,
              cedula
            )
          ''')
          .order('created_at', ascending: false);

      return (data as List)
          .map((item) =>
              JustificativoRevisionItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Actualizar estado de un justificativo de alumno (aprobado / rechazado / pendiente)
  Future<void> updateJustificativoEstado(
    String justificativoId,
    String nuevoEstado,
  ) async {
    await _supabase
        .from('justificativos_asistencia')
        .update({'estado': nuevoEstado})
        .eq('id', justificativoId);
  }

  /// Aportes solicitados por curso expresados estrictamente en Bolívares (Bs.)
  Future<List<AporteCursoBsItem>> getAportesCursosEnBs() async {
    try {
      final data = await _supabase
          .from('encuestas_participacion')
          .select('''
            id,
            fecha_clase,
            costo_total_insumos,
            tasa_bcv_usada,
            total_confirmados,
            monto_individual_calculado,
            cursos:curso_id (
              nombre
            )
          ''')
          .eq('estado', 'activa')
          .order('fecha_clase', ascending: false);

      return (data as List).map((item) {
        final c = item['cursos'] as Map<String, dynamic>?;
        final totalConfirmados = (item['total_confirmados'] as num?)?.toInt() ?? 0;
        final cuotaBs = (item['monto_individual_calculado'] as num?)?.toDouble() ?? 0.0;
        final costoUsd = (item['costo_total_insumos'] as num?)?.toDouble() ?? 0.0;
        final tasaBcv = (item['tasa_bcv_usada'] as num?)?.toDouble() ?? 1.0;
        final totalBs = totalConfirmados > 0
            ? (cuotaBs * totalConfirmados)
            : (costoUsd * tasaBcv);

        return AporteCursoBsItem(
          surveyId: item['id'] as String,
          cursoNombre: c?['nombre'] ?? 'Curso',
          fechaClase: item['fecha_clase']?.toString() ?? '',
          costoTotalUsd: costoUsd,
          tasaBcvUsada: tasaBcv,
          totalConfirmados: totalConfirmados,
          cuotaBs: cuotaBs,
          totalAporteBs: totalBs,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Obtiene los alumnos y temas de un curso específico para el Coordinador
  Future<Map<String, dynamic>> getCourseStudentsAndTemas(String courseId) async {
    final cursoRes = await _supabase
        .from('cursos')
        .select('id, nombre, temas')
        .eq('id', courseId)
        .maybeSingle();

    final inscripciones = await _supabase
        .from('inscripciones')
        .select('''
          id,
          alumno_id,
          estado,
          alumnos:alumno_id (
            id,
            nombre_completo,
            cedula,
            telefono
          )
        ''')
        .eq('curso_id', courseId)
        .isFilter('deleted_at', null);

    final temasRaw = (cursoRes?['temas'] as List? ?? []);
    final List<String> temasList = temasRaw.map((e) => e.toString()).toList();

    return {
      'cursoNombre': cursoRes?['nombre'] ?? 'Curso',
      'temas': temasList,
      'alumnos': inscripciones,
    };
  }

  /// Coordinador añade alumno directamente a un curso
  Future<void> coordinatorAddStudent({
    required String courseId,
    required String courseName,
    required String nombre,
    required String cedula,
    String? telefono,
    String? email,
  }) async {
    final cleanCedula = cedula.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    final studentRes = await _supabase.from('alumnos').upsert({
      'nombre_completo': nombre.trim(),
      'cedula': cleanCedula,
      'telefono': telefono?.trim(),
      'email': email?.trim(),
      'curso': courseName,
    }, onConflict: 'cedula').select('id').single();

    final studentId = studentRes['id'] as String;

    await _supabase.from('inscripciones').upsert({
      'curso_id': courseId,
      'alumno_id': studentId,
      'estado': 'activo',
      'deleted_at': null,
    }, onConflict: 'curso_id, alumno_id');
  }

  /// Coordinador elimina/desincorpora alumno de un curso
  Future<void> coordinatorDeleteStudent({
    required String courseId,
    required String studentId,
  }) async {
    await _supabase
        .from('inscripciones')
        .update({
          'estado': 'retirado',
          'deleted_at': DateTime.now().toIso8601String(),
        })
        .eq('curso_id', courseId)
        .eq('alumno_id', studentId);
  }

  /// Coordinador añade tema a un curso
  Future<void> coordinatorAddTema({
    required String courseId,
    required String tema,
  }) async {
    final res = await _supabase.from('cursos').select('temas').eq('id', courseId).maybeSingle();
    final List<dynamic> current = res?['temas'] as List? ?? [];
    current.add(tema.trim());
    await _supabase.from('cursos').update({'temas': current}).eq('id', courseId);
    try {
      await _supabase.from('temas_curso').insert({
        'curso_id': courseId,
        'titulo': tema.trim(),
        'orden': current.length,
      });
    } catch (_) {}
  }

  /// Coordinador edita tema de un curso
  Future<void> coordinatorEditTema({
    required String courseId,
    required String oldTema,
    required String newTema,
  }) async {
    final res = await _supabase.from('cursos').select('temas').eq('id', courseId).maybeSingle();
    final List<dynamic> current = res?['temas'] as List? ?? [];
    final updated = current.map((t) => t.toString() == oldTema ? newTema.trim() : t).toList();
    await _supabase.from('cursos').update({'temas': updated}).eq('id', courseId);
    try {
      await _supabase
          .from('temas_curso')
          .update({'titulo': newTema.trim()})
          .eq('curso_id', courseId)
          .eq('titulo', oldTema);
    } catch (_) {}
  }

  /// Coordinador elimina tema de un curso
  Future<void> coordinatorDeleteTema({
    required String courseId,
    required String tema,
  }) async {
    final res = await _supabase.from('cursos').select('temas').eq('id', courseId).maybeSingle();
    final List<dynamic> current = res?['temas'] as List? ?? [];
    current.removeWhere((t) => t.toString() == tema);
    await _supabase.from('cursos').update({'temas': current}).eq('id', courseId);
    try {
      await _supabase
          .from('temas_curso')
          .delete()
          .eq('curso_id', courseId)
          .eq('titulo', tema);
    } catch (_) {}
  }
}
