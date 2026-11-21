import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/core/services/error_tracking_service.dart';

import '../domain/teacher_models.dart';
import 'attendance_offline_service.dart';

/// Resultado del guardado de asistencia (indica si fue online o encolado localmente).
class AttendanceSaveResult {
  final bool isOffline;
  final String message;

  const AttendanceSaveResult({
    required this.isOffline,
    required this.message,
  });
}

class TeacherRepository {
  final SupabaseClient _supabase;

  TeacherRepository(this._supabase);

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Cursos asignados al profesor actual
  Future<List<TeacherCourse>> getMyCourses({bool isSuperAdmin = false}) async {
    final uid = currentUserId;
    if (uid == null) return [];

    dynamic query = _supabase
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
        .eq('estado', 'activo');
    if (!isSuperAdmin) {
      query = query.eq('profesor_id', uid);
    }
    final cursosData = await query;

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
    try {
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

      // Respaldar en caché local SQLite / Hive para uso offline
      await AttendanceOfflineService.instance.cacheStudents(courseId, resultado);
      await AttendanceOfflineService.instance.cacheAttendanceRecord(
        courseId: courseId,
        date: date,
        students: resultado,
      );

      return resultado;
    } catch (e) {
      // Fallback offline si no hay conexión de red
      final cached = AttendanceOfflineService.instance.getCachedStudents(courseId);
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  /// Guarda o actualiza (Upsert) la lista de asistencia del día.
  /// En caso de pérdida de conexión, encola el lote en el almacenamiento local para sincronización en segundo plano.
  Future<AttendanceSaveResult> saveAttendance({
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

    try {
      await _supabase
          .from('asistencia')
          .upsert(records, onConflict: 'curso_id, alumno_id, fecha');

      // Actualizar caché y liberar cualquier tarea pendiente
      await AttendanceOfflineService.instance.cacheAttendanceRecord(
        courseId: courseId,
        date: date,
        students: students,
      );
      await AttendanceOfflineService.instance.removePending(courseId, date);

      return const AttendanceSaveResult(
        isOffline: false,
        message: '¡Asistencia sincronizada y guardada exitosamente!',
      );
    } catch (e) {
      // Fallback offline: encolar localmente
      await AttendanceOfflineService.instance.enqueueForSync(
        courseId: courseId,
        date: date,
        students: students,
        recordedBy: uid,
      );

      return const AttendanceSaveResult(
        isOffline: true,
        message: 'Asistencia guardada localmente (Modo sin conexión). Se sincronizará automáticamente al recuperar señal.',
      );
    }
  }

  /// Obtiene la tasa BCV oficial más reciente con Fecha Valor
  Future<({double tasa, String? fechaValor})> getLatestBcvRateInfo() async {
    try {
      final res = await _supabase
          .from('tasa_cambiaria')
          .select('tasa_bcv, fecha')
          .order('fecha', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null && res['tasa_bcv'] != null) {
        return (
          tasa: (res['tasa_bcv'] as num).toDouble(),
          fechaValor: res['fecha'] as String?,
        );
      }
    } catch (_) {}

    try {
      final configRes = await _supabase
          .from('configuracion_general')
          .select('valor')
          .eq('clave', 'tasa_cambio_oficial')
          .maybeSingle();
      if (configRes != null && configRes['valor'] != null) {
        return (
          tasa: (configRes['valor'] as num).toDouble(),
          fechaValor: null,
        );
      }
    } catch (_) {}

    return (tasa: 1.0, fechaValor: null);
  }

  /// Creación de Encuesta de Insumos por el Profesor
  Future<void> createSurvey({
    required String courseId,
    required String classDate,
    required double totalSupplyCost,
    required DateTime deadline,
    String? pagoMovilCedula,
    String? pagoMovilTelefono,
    String? pagoMovilBanco,
  }) async {
    try {
      final uid = currentUserId;

      // Obtener la tasa BCV oficial con Fecha Valor para congelarla en la encuesta
      final rateInfo = await getLatestBcvRateInfo();
      final tasaBcv = rateInfo.tasa;

      final insertPayload = <String, dynamic>{
        'curso_id': courseId,
        'fecha_clase': classDate,
        'costo_total_insumos': totalSupplyCost,
        'tasa_bcv_usada': tasaBcv,
        'fecha_limite': deadline.toIso8601String(),
        'creada_por': uid,
        'estado': 'activa',
        'monto_individual_calculado': 0.00,
        'total_confirmados': 0,
      };

      if (pagoMovilCedula != null && pagoMovilCedula.trim().isNotEmpty) {
        insertPayload['pago_movil_cedula'] = pagoMovilCedula.trim();
      }
      if (pagoMovilTelefono != null && pagoMovilTelefono.trim().isNotEmpty) {
        insertPayload['pago_movil_telefono'] = pagoMovilTelefono.trim();
      }
      if (pagoMovilBanco != null && pagoMovilBanco.trim().isNotEmpty) {
        insertPayload['pago_movil_banco'] = pagoMovilBanco.trim();
      }

      await _supabase.from('encuestas_participacion').insert(insertPayload);
    } catch (e, stackTrace) {
      unawaited(
        ErrorTrackingService.instance.reportException(
          error: e,
          stackTrace: stackTrace,
          module: 'teacher_repository:createSurvey',
          severity: 'error',
          metadata: {
            'course_id': courseId,
            'total_supply_cost': totalSupplyCost,
          },
        ),
      );
      rethrow;
    }
  }

  /// Actualizar el monto del aporte en USD fijado por el profesor y recalcular cuota en Bs
  Future<void> updateSurveySupplyCost({
    required String surveyId,
    required double totalSupplyCost,
  }) async {
    try {
      final rateInfo = await getLatestBcvRateInfo();
      final tasaBcv = rateInfo.tasa;

      await _supabase.from('encuestas_participacion').update({
        'costo_total_insumos': totalSupplyCost,
        'tasa_bcv_usada': tasaBcv,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', surveyId);

      try {
        await _supabase.rpc('recalcular_monto_encuesta', params: {'p_encuesta_id': surveyId});
      } catch (rpcErr, rpcStack) {
        unawaited(
          ErrorTrackingService.instance.reportException(
            error: rpcErr,
            stackTrace: rpcStack,
            module: 'teacher_repository:recalcular_monto_encuesta',
            severity: 'warning',
          ),
        );
      }
    } catch (e, stackTrace) {
      unawaited(
        ErrorTrackingService.instance.reportException(
          error: e,
          stackTrace: stackTrace,
          module: 'teacher_repository:updateSurveySupplyCost',
          severity: 'error',
          metadata: {
            'survey_id': surveyId,
            'total_supply_cost': totalSupplyCost,
          },
        ),
      );
      rethrow;
    }
  }

  /// Obtiene encuestas del docente (activas o historial)
  Future<List<TeacherSurvey>> getTeacherSurveys({
    required bool activeOnly,
    bool isSuperAdmin = false,
  }) async {
    var query = _supabase
        .from('encuestas_participacion')
        .select('''
          id,
          curso_id,
          fecha_clase,
          costo_total_insumos,
          tasa_bcv_usada,
          fecha_limite,
          monto_individual_calculado,
          total_confirmados,
          estado,
          created_at,
          pago_movil_cedula,
          pago_movil_telefono,
          pago_movil_banco,
          cursos:curso_id (
            nombre,
            profesor_id
          )
        ''');

    if (!isSuperAdmin) {
      final courses = await getMyCourses(isSuperAdmin: false);
      if (courses.isEmpty) return [];
      final courseIds = courses.map((c) => c.id).toList();
      query = query.inFilter('curso_id', courseIds);
    }

    if (activeOnly) {
      query = query.eq('estado', 'activa');
    } else {
      query = query.neq('estado', 'activa');
    }

    final data = await query.order('created_at', ascending: false);
    return (data as List).map((item) => TeacherSurvey.fromJson(item)).toList();
  }

  /// Actualiza estado de una encuesta (ej. 'cerrada', 'finalizada', 'activa')
  Future<void> updateSurveyStatus({
    required String surveyId,
    required String status,
  }) async {
    await _supabase
        .from('encuestas_participacion')
        .update({
          'estado': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', surveyId);
  }

  /// Modificar encuesta completa (presupuesto, fecha de clase, fecha límite)
  Future<void> updateSurveyDetails({
    required String surveyId,
    required double totalSupplyCost,
    required String classDate,
    required DateTime deadline,
    String? pagoMovilCedula,
    String? pagoMovilTelefono,
    String? pagoMovilBanco,
  }) async {
    try {
      final rateInfo = await getLatestBcvRateInfo();
      final tasaBcv = rateInfo.tasa;

      final updatePayload = <String, dynamic>{
        'costo_total_insumos': totalSupplyCost,
        'fecha_clase': classDate,
        'fecha_limite': deadline.toIso8601String(),
        'tasa_bcv_usada': tasaBcv,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (pagoMovilCedula != null) updatePayload['pago_movil_cedula'] = pagoMovilCedula.trim();
      if (pagoMovilTelefono != null) updatePayload['pago_movil_telefono'] = pagoMovilTelefono.trim();
      if (pagoMovilBanco != null) updatePayload['pago_movil_banco'] = pagoMovilBanco.trim();

      await _supabase.from('encuestas_participacion').update(updatePayload).eq('id', surveyId);

      try {
        await _supabase.rpc('recalcular_monto_encuesta', params: {'p_encuesta_id': surveyId});
      } catch (rpcErr, rpcStack) {
        unawaited(
          ErrorTrackingService.instance.reportException(
            error: rpcErr,
            stackTrace: rpcStack,
            module: 'teacher_repository:recalcular_monto_encuesta',
            severity: 'warning',
          ),
        );
      }
    } catch (e, stackTrace) {
      unawaited(
        ErrorTrackingService.instance.reportException(
          error: e,
          stackTrace: stackTrace,
          module: 'teacher_repository:updateSurveyDetails',
          severity: 'error',
          metadata: {
            'survey_id': surveyId,
            'total_supply_cost': totalSupplyCost,
          },
        ),
      );
      rethrow;
    }
  }

  /// Elimina una encuesta de participación y sus respuestas asociadas
  Future<void> deleteSurvey(String surveyId) async {
    try {
      try {
        await _supabase
            .from('respuestas_encuesta')
            .delete()
            .eq('encuesta_id', surveyId);
      } catch (_) {}

      final deleted = await _supabase
          .from('encuestas_participacion')
          .delete()
          .eq('id', surveyId)
          .select('id');

      if ((deleted as List).isEmpty) {
        throw Exception('No se pudo eliminar la encuesta de la base de datos (0 registros afectados).');
      }
    } catch (e, stackTrace) {
      unawaited(
        ErrorTrackingService.instance.reportException(
          error: e,
          stackTrace: stackTrace,
          module: 'teacher_repository:deleteSurvey',
          severity: 'error',
          metadata: {'survey_id': surveyId},
        ),
      );
      rethrow;
    }
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
            cedula,
            avatar_url
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
            cedula,
            avatar_url
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
        avatarUrl: al?['avatar_url'] as String?,
      );
    }).toList();
  }

  /// Crear solicitud de aprobación para modificación (alumnos o temas)
  Future<void> createApprovalRequest({
    required String courseId,
    required String courseName,
    required String requestType, // 'crear_alumno' | 'editar_alumno' | 'eliminar_alumno' | 'crear_tema' | 'editar_tema' | 'eliminar_tema'
    required Map<String, dynamic> newValues,
    Map<String, dynamic>? oldValues,
    String? reason,
    String? teacherName,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Usuario no autenticado.');

    await _supabase.from('solicitudes_aprobacion').insert({
      'profesor_id': uid,
      'profesor_nombre': teacherName,
      'curso_id': courseId,
      'curso_nombre': courseName,
      'tipo_solicitud': requestType,
      'estado': 'pendiente',
      'datos_anteriores': oldValues,
      'datos_nuevos': newValues,
      'motivo': reason,
    });
  }

  /// Consultar solicitudes de aprobación enviadas por el profesor
  Future<List<SolicitudAprobacionItem>> getMyApprovalRequests(
    String courseId,
  ) async {
    final uid = currentUserId;
    if (uid == null) return [];

    final data = await _supabase
        .from('solicitudes_aprobacion')
        .select()
        .eq('curso_id', courseId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((j) => SolicitudAprobacionItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Obtener temas actuales del curso
  Future<List<String>> getCourseTemas(String courseId) async {
    final res = await _supabase
        .from('cursos')
        .select('temas')
        .eq('id', courseId)
        .maybeSingle();

    if (res == null) return [];
    final temasList = res['temas'] as List? ?? [];
    return temasList.map((e) => e.toString()).toList();
  }

  /// Listado resumido de encuestas disponibles para la pestaña de Auditoría de Recaudación.
  Future<List<Map<String, dynamic>>> getAuditSurveysList() async {
    final data = await _supabase
        .from('encuestas_participacion')
        .select(
          'id, fecha_clase, costo_total_insumos, monto_individual_calculado, total_confirmados, cursos(nombre)',
        )
        .order('fecha_clase', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Sincroniza asistencias encoladas offline usando el cliente activo de Supabase.
  Future<bool> syncPendingOfflineAttendance() {
    return AttendanceOfflineService.instance.syncPendingQueue(_supabase);
  }

  /// Obtiene las notificaciones del profesor (respuestas de encuestas y pagos subidos)
  Future<List<TeacherNotificationItem>> getTeacherNotifications({
    required bool isSuperAdmin,
    String? profesorId,
  }) async {
    try {
      List<String>? courseIds;
      if (!isSuperAdmin) {
        final courses = await getMyCourses(isSuperAdmin: false);
        if (courses.isEmpty) return [];
        courseIds = courses.map((c) => c.id).toList();
      }

      final raw = await _supabase
          .from('respuestas_encuesta')
          .select('''
            id,
            encuesta_id,
            alumno_id,
            asistira,
            estado_pago,
            comprobante_url,
            comprobante_subido_at,
            monto_asignado,
            created_at,
            updated_at,
            alumnos:alumno_id (
              id,
              nombre_completo,
              cedula
            ),
            encuestas_participacion:encuesta_id (
              id,
              curso_id,
              fecha_clase,
              cursos:curso_id (
                id,
                nombre,
                profesor_id
              )
            )
          ''')
          .order('created_at', ascending: false)
          .limit(100);

      final List<TeacherNotificationItem> items = [];

      for (final r in (raw as List)) {
        final enc = r['encuestas_participacion'] as Map<String, dynamic>?;
        if (enc == null) continue;
        final curso = enc['cursos'] as Map<String, dynamic>?;
        final cId = enc['curso_id']?.toString() ?? '';

        if (!isSuperAdmin && courseIds != null && !courseIds.contains(cId)) {
          continue;
        }

        final al = r['alumnos'] as Map<String, dynamic>?;
        final alNombre = al?['nombre_completo']?.toString() ?? 'Alumno';
        final alCedula = al?['cedula']?.toString() ?? '';
        final cursoNombre = curso?['nombre']?.toString() ?? 'Curso';
        final surveyId = enc['id']?.toString() ?? '';
        final respId = r['id']?.toString() ?? '';

        // 1. Notificación de respuesta si asistira != null
        if (r['asistira'] != null) {
          final willAttend = r['asistira'] == true;
          final respCreatedAt =
              DateTime.tryParse(r['created_at']?.toString() ?? '') ??
                  DateTime.now();
          items.add(
            TeacherNotificationItem(
              id: 'resp_$respId',
              surveyId: surveyId,
              cursoId: cId,
              cursoNombre: cursoNombre,
              alumnoId: r['alumno_id']?.toString() ?? '',
              alumnoNombre: alNombre,
              alumnoCedula: alCedula,
              type: willAttend
                  ? TeacherNotificationType.surveyResponseAffirmative
                  : TeacherNotificationType.surveyResponseNegative,
              timestamp: respCreatedAt,
            ),
          );
        }

        // 2. Notificación de pago si tiene comprobante
        final compUrl = r['comprobante_url']?.toString();
        if (compUrl != null && compUrl.trim().isNotEmpty) {
          final payDateStr =
              r['comprobante_subido_at'] ?? r['updated_at'] ?? r['created_at'];
          final payTimestamp =
              DateTime.tryParse(payDateStr?.toString() ?? '') ?? DateTime.now();
          items.add(
            TeacherNotificationItem(
              id: 'pay_$respId',
              surveyId: surveyId,
              cursoId: cId,
              cursoNombre: cursoNombre,
              alumnoId: r['alumno_id']?.toString() ?? '',
              alumnoNombre: alNombre,
              alumnoCedula: alCedula,
              type: TeacherNotificationType.paymentUploaded,
              monto: (r['monto_asignado'] as num?)?.toDouble(),
              comprobanteUrl: compUrl,
              timestamp: payTimestamp,
            ),
          );
        }
      }

      // Ordenar cronológicamente descendente
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    } catch (e, stackTrace) {
      unawaited(
        ErrorTrackingService.instance.reportException(
          error: e,
          stackTrace: stackTrace,
          module: 'teacher_repository:getTeacherNotifications',
          severity: 'warning',
        ),
      );
      return [];
    }
  }

  /// Obtiene el desglose completo de una encuesta: confirmados, negativos y alumnos pendientes por responder
  Future<SurveyResponseBreakdown> getSurveyDetailedBreakdown(
    String surveyId,
  ) async {
    // 1. Obtener datos de la encuesta y curso
    final surveyData = await _supabase
        .from('encuestas_participacion')
        .select('''
          id,
          curso_id,
          fecha_clase,
          fecha_limite,
          costo_total_insumos,
          tasa_bcv_usada,
          monto_individual_calculado,
          cursos:curso_id (
            id,
            nombre
          )
        ''')
        .eq('id', surveyId)
        .single();

    final cursoId = surveyData['curso_id'] as String;
    final cursoMap = surveyData['cursos'] as Map<String, dynamic>?;
    final cursoNombre = cursoMap?['nombre']?.toString() ?? 'Curso';

    // 2. Obtener alumnos activos inscritos en el curso
    final inscritosRaw = await _supabase
        .from('inscripciones')
        .select('''
          alumno_id,
          estado,
          deleted_at,
          alumnos:alumno_id (
            id,
            nombre_completo,
            cedula,
            telefono
          )
        ''')
        .eq('curso_id', cursoId)
        .isFilter('deleted_at', null);

    final List<Map<String, dynamic>> alumnosInscritos = [];
    for (final item in (inscritosRaw as List)) {
      if (item['estado'] == 'retirado') continue;
      final al = item['alumnos'] as Map<String, dynamic>?;
      if (al != null) {
        alumnosInscritos.add(al);
      }
    }

    // 3. Obtener respuestas de la encuesta
    final respuestasRaw = await _supabase
        .from('respuestas_encuesta')
        .select('''
          id,
          alumno_id,
          asistira,
          estado_pago,
          comprobante_url,
          created_at,
          alumnos:alumno_id (
            id,
            nombre_completo,
            cedula,
            telefono
          )
        ''')
        .eq('encuesta_id', surveyId);

    final List<SurveyStudentResponseItem> afirmativos = [];
    final List<SurveyStudentResponseItem> negativos = [];
    final List<SurveyStudentResponseItem> pendientes = [];
    final Set<String> procesados = {};

    for (final r in (respuestasRaw as List)) {
      final aId = r['alumno_id']?.toString() ?? '';
      procesados.add(aId);
      final al = r['alumnos'] as Map<String, dynamic>?;
      final nombre = al?['nombre_completo']?.toString() ?? 'Alumno';
      final cedula = al?['cedula']?.toString() ?? '';
      final telf = al?['telefono']?.toString();
      final willAttend = r['asistira'] as bool?;
      final stItem = SurveyStudentResponseItem(
        alumnoId: aId,
        nombreCompleto: nombre,
        cedula: cedula,
        telefono: telf,
        asistira: willAttend,
        estadoPago: r['estado_pago'] as String?,
        comprobanteUrl: r['comprobante_url'] as String?,
        respondioAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      );

      if (willAttend == true) {
        afirmativos.add(stItem);
      } else if (willAttend == false) {
        negativos.add(stItem);
      } else {
        pendientes.add(stItem);
      }
    }

    // Alumnos inscritos que aún NO tienen respuesta registrada
    for (final al in alumnosInscritos) {
      final aId = al['id']?.toString() ?? '';
      if (!procesados.contains(aId)) {
        pendientes.add(
          SurveyStudentResponseItem(
            alumnoId: aId,
            nombreCompleto: al['nombre_completo']?.toString() ?? 'Alumno',
            cedula: al['cedula']?.toString() ?? '',
            telefono: al['telefono']?.toString(),
            asistira: null,
            estadoPago: null,
            comprobanteUrl: null,
            respondioAt: null,
          ),
        );
      }
    }

    // Ordenar alfabéticamente
    afirmativos.sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));
    negativos.sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));
    pendientes.sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));

    final totalInscritos =
        alumnosInscritos.length >
                (afirmativos.length + negativos.length + pendientes.length)
            ? alumnosInscritos.length
            : (afirmativos.length + negativos.length + pendientes.length);

    return SurveyResponseBreakdown(
      surveyId: surveyId,
      cursoId: cursoId,
      cursoNombre: cursoNombre,
      fechaClase: surveyData['fecha_clase']?.toString() ?? '',
      fechaLimite: DateTime.tryParse(
        surveyData['fecha_limite']?.toString() ?? '',
      ),
      costoTotalInsumos:
          (surveyData['costo_total_insumos'] as num?)?.toDouble() ?? 0.0,
      montoIndividualCalculado:
          (surveyData['monto_individual_calculado'] as num?)?.toDouble() ?? 0.0,
      tasaBcvUsada: (surveyData['tasa_bcv_usada'] as num?)?.toDouble(),
      totalInscritos: totalInscritos,
      alumnosAfirmativos: afirmativos,
      alumnosNegativos: negativos,
      alumnosPendientes: pendientes,
    );
  }
}
