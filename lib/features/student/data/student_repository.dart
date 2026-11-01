import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/student_models.dart';

class StudentRepository {
  final SupabaseClient _supabase;

  StudentRepository(this._supabase);

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Obtiene el registro de 'alumnos' correspondiente al usuario autenticado
  Future<Map<String, dynamic>?> getAlumnoRecord({bool isSuperAdmin = false}) async {
    final uid = currentUserId;
    if (uid == null) return null;

    final record = await _supabase
        .from('alumnos')
        .select()
        .eq('user_id', uid)
        .limit(1)
        .maybeSingle();

    if (record != null) return record;

    // Buscar por correo si no tiene user_id aún
    final email = _supabase.auth.currentUser?.email;
    if (email != null) {
      final byEmail = await _supabase
          .from('alumnos')
          .select()
          .ilike('correo', email)
          .isFilter('user_id', null)
          .limit(1)
          .maybeSingle();
      if (byEmail != null) {
        final linked = await _supabase
            .from('alumnos')
            .update({'user_id': uid})
            .eq('id', byEmail['id'])
            .isFilter('user_id', null)
            .select()
            .limit(1)
            .maybeSingle();
        if (linked == null) {
          throw StateError(
            'No se pudo vincular el registro del alumno con la cuenta actual.',
          );
        }
        byEmail['user_id'] = uid;
        return byEmail;
      }
    }

    // Si es Super Admin o perfil administrativo, asegurar que exista un registro de alumno para pruebas y auditoría
    if (isSuperAdmin) {
      try {
        final perfilesRes = await _supabase
            .from('perfiles')
            .select('nombre_completo, cedula, telefono, correo')
            .eq('user_id', uid)
            .limit(1)
            .maybeSingle();

        final nombre = perfilesRes?['nombre_completo'] ?? email ?? 'Super Administrador';
        final cedula = perfilesRes?['cedula'] ?? 'SUPERADMIN';
        final telefono = perfilesRes?['telefono'];
        final correo = perfilesRes?['correo'] ?? email;

        // Intentar buscar si ya existe con esa cédula o correo
        final existing = await _supabase
            .from('alumnos')
            .select()
            .or('user_id.eq.$uid,correo.eq.$correo')
            .limit(1)
            .maybeSingle();

        if (existing != null) {
          if (existing['user_id'] == null) {
            await _supabase.from('alumnos').update({'user_id': uid}).eq('id', existing['id']);
            existing['user_id'] = uid;
          }
          return existing;
        }

        final inserted = await _supabase.from('alumnos').insert({
          'user_id': uid,
          'nombre_completo': nombre,
          'cedula': cedula,
          'telefono': telefono,
          'correo': correo,
          'curso': 'Repostería Básica',
        }).select().maybeSingle();

        return inserted;
      } catch (_) {}
    }

    return null;
  }

  /// Obtiene los cursos activos e historial del alumno
  Future<List<StudentCourse>> getMyCourses({
    String? statusFilter,
    bool isSuperAdmin = false,
  }) async {
    final alumno = await getAlumnoRecord(isSuperAdmin: isSuperAdmin);

    if (isSuperAdmin && alumno == null) {
      final allCourses = await _supabase
          .from('cursos')
          .select('''
            id,
            nombre,
            descripcion,
            horario,
            estado,
            perfiles:profesor_id (
              nombre_completo
            )
          ''')
          .eq('estado', 'activo')
          .order('nombre');

      return (allCourses as List).map((c) {
        return StudentCourse(
          id: c['id'] as String,
          nombre: c['nombre'] as String? ?? 'Curso',
          descripcion: c['descripcion'] as String?,
          horario: c['horario'] as String?,
          profesorNombre: (c['perfiles'] as Map?)?['nombre_completo'] as String?,
          estado: 'activo',
        );
      }).toList();
    }

    if (alumno == null) return [];

    var query = _supabase
        .from('inscripciones')
        .select('''
          estado,
          deleted_at,
          cursos:curso_id (
            id,
            nombre,
            descripcion,
            horario,
            estado,
            perfiles:profesor_id (
              nombre_completo
            )
          )
        ''')
        .eq('alumno_id', alumno['id'])
        .isFilter('deleted_at', null);

    if (statusFilter != null) {
      query = query.eq('estado', statusFilter);
    }

    final data = await query;
    final results = (data as List).map((item) => StudentCourse.fromJson(item)).toList();

    // Fallback si no tiene inscripciones pero tiene el curso en su perfil
    if (results.isEmpty && alumno['curso'] != null) {
      var fallbackQuery = _supabase
          .from('cursos')
          .select('''
            id,
            nombre,
            descripcion,
            horario,
            estado,
            perfiles:profesor_id (
              nombre_completo
            )
          ''')
          .ilike('nombre', (alumno['curso'] as String).trim());

      if (statusFilter != null) {
        fallbackQuery = fallbackQuery.eq('estado', statusFilter);
      }

      final cResList = await fallbackQuery;
      for (final cRes in cResList) {
        results.add(
          StudentCourse(
            id: cRes['id'] as String,
            nombre: cRes['nombre'] as String? ?? 'Curso',
            descripcion: cRes['descripcion'] as String?,
            horario: cRes['horario'] as String?,
            profesorNombre: (cRes['perfiles'] as Map?)?['nombre_completo'] as String?,
            estado: cRes['estado'] as String? ?? 'activo',
          ),
        );
      }
    }

    return results;
  }

  /// Consulta de asistencias por curso y cálculo de métricas
  Future<AttendanceSummary> getAttendanceByCourse(String courseId) async {
    final alumno = await getAlumnoRecord();
    if (alumno == null) {
      return AttendanceSummary(
        totalClases: 0,
        presentes: 0,
        inasistencias: 0,
        historial: [],
      );
    }

    final data = await _supabase
        .from('asistencia')
        .select()
        .eq('curso_id', courseId)
        .eq('alumno_id', alumno['id'])
        .order('fecha', ascending: false);

    final lista = (data as List)
        .map((e) => AttendanceRecord.fromJson(e))
        .toList();
    final presentes = lista
        .where((a) => a.estado.toLowerCase() == 'presente')
        .length;
    final inasistencias = lista
        .where((a) => a.estado.toLowerCase() == 'ausente')
        .length;

    return AttendanceSummary(
      totalClases: lista.length,
      presentes: presentes,
      inasistencias: inasistencias,
      historial: lista,
    );
  }

  /// Stream en tiempo real de asistencias para el alumno en un curso
  Stream<List<Map<String, dynamic>>> streamAsistenciasCurso(String cursoId) {
    return _supabase
        .from('asistencia')
        .stream(primaryKey: ['id'])
        .eq('curso_id', cursoId);
  }

  /// Obtiene los justificativos médicos registrados por el alumno para un curso
  Future<List<JustificativoAsistencia>> getJustificativos({
    required String cursoId,
  }) async {
    final alumno = await getAlumnoRecord();
    if (alumno == null) return [];

    final data = await _supabase
        .from('justificativos_asistencia')
        .select()
        .eq('curso_id', cursoId)
        .eq('alumno_id', alumno['id'])
        .order('fecha', ascending: false);

    return (data as List)
        .map((e) => JustificativoAsistencia.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Envía un justificativo médico de ausencia con motivo y soporte fotográfico
  Future<JustificativoAsistencia> submitAbsenceJustification({
    required String cursoId,
    required String fecha,
    required String motivo,
    Uint8List? imageBytes,
    String? fileExtension,
  }) async {
    final alumno = await getAlumnoRecord();
    if (alumno == null) {
      throw Exception('No se encontró el registro de alumno asociado al usuario.');
    }

    String? publicUrl;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final ext = (fileExtension ?? 'jpg').replaceAll('.', '');
      final fileName =
          'justificativo_${alumno['id']}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'justificativos/$fileName';

      // Subir archivo al bucket de Supabase con resguardo
      try {
        await _supabase.storage.from('justificativos').uploadBinary(
              storagePath,
              imageBytes,
              fileOptions: FileOptions(
                contentType: 'image/$ext',
                cacheControl: '3600',
                upsert: true,
              ),
            );
        publicUrl =
            _supabase.storage.from('justificativos').getPublicUrl(storagePath);
      } catch (_) {
        await _supabase.storage.from('comprobantes').uploadBinary(
              storagePath,
              imageBytes,
              fileOptions: FileOptions(
                contentType: 'image/$ext',
                cacheControl: '3600',
                upsert: true,
              ),
            );
        publicUrl =
            _supabase.storage.from('comprobantes').getPublicUrl(storagePath);
      }
    }

    final insertData = <String, dynamic>{
      'alumno_id': alumno['id'],
      'curso_id': cursoId,
      'fecha': fecha,
      'motivo': motivo.trim(),
      'estado': 'pendiente',
    };
    if (publicUrl != null) {
      insertData['comprobante_url'] = publicUrl;
    }

    final inserted = await _supabase
        .from('justificativos_asistencia')
        .insert(insertData)
        .select()
        .single();

    return JustificativoAsistencia.fromJson(inserted);
  }

  /// Obtiene las encuestas activas de los cursos donde el alumno está inscrito
  Future<List<StudentSurvey>> getActiveSurveys({bool isSuperAdmin = false}) async {
    final alumno = await getAlumnoRecord(isSuperAdmin: isSuperAdmin);

    final dynamic encuestasData;

    if (isSuperAdmin) {
      // Como Super Admin en vista de alumno, ver todas las encuestas activas del sistema
      encuestasData = await _supabase
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
            cursos:curso_id (
              nombre,
              perfiles:profesor_id (
                nombre_completo
              )
            )
          ''')
          .eq('estado', 'activa')
          .order('fecha_limite', ascending: true);
    } else {
      if (alumno == null) return [];

      // Cursos del alumno
      final inscripciones = await _supabase
          .from('inscripciones')
          .select('curso_id')
          .eq('alumno_id', alumno['id'])
          .isFilter('deleted_at', null);

      final cursoIds = (inscripciones as List)
          .map((i) => i['curso_id'] as String)
          .toList();

      // Si no tiene inscripciones pero tiene el nombre del curso asignado en la tabla alumnos
      if (cursoIds.isEmpty && alumno['curso'] != null && (alumno['curso'] as String).trim().isNotEmpty) {
        final cursoMatches = await _supabase
            .from('cursos')
            .select('id')
            .ilike('nombre', (alumno['curso'] as String).trim());
        for (final item in cursoMatches) {
          if (item['id'] != null) {
            cursoIds.add(item['id'] as String);
          }
        }
      }

      if (cursoIds.isEmpty) return [];

      encuestasData = await _supabase
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
            cursos:curso_id (
              nombre,
              perfiles:profesor_id (
                nombre_completo
              )
            )
          ''')
          .inFilter('curso_id', cursoIds)
          .eq('estado', 'activa')
          .order('fecha_limite', ascending: true);
    }

    final List<StudentSurvey> resultado = [];

    for (final enc in (encuestasData as List)) {
      final encuestaId = enc['id'] as String;

      // Buscar respuesta del alumno
      Map<String, dynamic>? respData;
      if (alumno != null) {
        respData = await _supabase
            .from('respuestas_encuesta')
            .select()
            .eq('encuesta_id', encuestaId)
            .eq('alumno_id', alumno['id'])
            .maybeSingle();
      }

      final cursoMap = enc['cursos'] as Map<String, dynamic>?;
      final fechaLimite =
          DateTime.tryParse(enc['fecha_limite'] as String? ?? '') ??
          DateTime.now();
      final estado = enc['estado'] as String? ?? 'activa';

      // Filtrar estrictamente: solo encuestas activas que no hayan vencido su fecha límite
      if (estado != 'activa' || DateTime.now().isAfter(fechaLimite)) {
        continue;
      }

      String? profName;
      if (cursoMap != null && cursoMap['perfiles'] is Map) {
        profName = cursoMap['perfiles']['nombre_completo'] as String?;
      }

      resultado.add(
        StudentSurvey(
          id: encuestaId,
          cursoId: enc['curso_id'] as String,
          cursoNombre: cursoMap?['nombre'] ?? 'Curso',
          profesorNombre: profName,
          fechaClase: enc['fecha_clase']?.toString() ?? '',
          costoTotalInsumos:
              (enc['costo_total_insumos'] as num?)?.toDouble() ?? 0.0,
          tasaBcvUsada: (enc['tasa_bcv_usada'] as num?)?.toDouble(),
          fechaLimite: fechaLimite,
          montoIndividual:
              (enc['monto_individual_calculado'] as num?)?.toDouble() ?? 0.0,
          totalConfirmados: (enc['total_confirmados'] as num?)?.toInt() ?? 0,
          estadoEncuesta: estado,
          respondio: respData != null,
          asistira: respData?['asistira'] as bool?,
          comprobanteUrl: respData?['comprobante_url'] as String?,
          estadoPago: respData?['estado_pago'] as String?,
          montoAsignado: (respData?['monto_asignado'] as num?)?.toDouble(),
          comprobanteSubidoAt: respData?['comprobante_subido_at'] != null
              ? DateTime.tryParse(respData!['comprobante_subido_at'] as String)
              : null,
        ),
      );
    }

    return resultado;
  }

  /// Obtiene el historial de encuestas (cerradas, finalizadas o pasadas) de los cursos del alumno
  Future<List<StudentSurvey>> getSurveysHistory({bool isSuperAdmin = false}) async {
    final alumno = await getAlumnoRecord(isSuperAdmin: isSuperAdmin);

    final dynamic encuestasData;

    if (isSuperAdmin) {
      encuestasData = await _supabase
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
            cursos:curso_id (
              nombre,
              perfiles:profesor_id (
                nombre_completo
              )
            )
          ''')
          .order('fecha_clase', ascending: false);
    } else {
      if (alumno == null) return [];

      final inscripciones = await _supabase
          .from('inscripciones')
          .select('curso_id')
          .eq('alumno_id', alumno['id'])
          .isFilter('deleted_at', null);

      final cursoIds = (inscripciones as List)
          .map((i) => i['curso_id'] as String)
          .toList();

      if (cursoIds.isEmpty && alumno['curso'] != null && (alumno['curso'] as String).trim().isNotEmpty) {
        final cursoMatches = await _supabase
            .from('cursos')
            .select('id')
            .ilike('nombre', (alumno['curso'] as String).trim());
        for (final item in cursoMatches) {
          if (item['id'] != null) {
            cursoIds.add(item['id'] as String);
          }
        }
      }

      if (cursoIds.isEmpty) return [];

      encuestasData = await _supabase
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
            cursos:curso_id (
              nombre,
              perfiles:profesor_id (
                nombre_completo
              )
            )
          ''')
          .inFilter('curso_id', cursoIds)
          .order('fecha_clase', ascending: false);
    }

    final List<StudentSurvey> resultado = [];

    for (final enc in (encuestasData as List)) {
      final estado = enc['estado'] as String? ?? 'activa';
      final fechaLimite =
          DateTime.tryParse(enc['fecha_limite'] as String? ?? '') ??
              DateTime.now();
      final esPasada = estado != 'activa' || DateTime.now().isAfter(fechaLimite);

      // Si aún está activa y vigente, se consulta en encuestas disponibles
      if (!esPasada) continue;

      final encuestaId = enc['id'] as String;

      Map<String, dynamic>? respData;
      if (alumno != null) {
        respData = await _supabase
            .from('respuestas_encuesta')
            .select()
            .eq('encuesta_id', encuestaId)
            .eq('alumno_id', alumno['id'])
            .maybeSingle();
      }

      final cursoMap = enc['cursos'] as Map<String, dynamic>?;

      String? profName;
      if (cursoMap != null && cursoMap['perfiles'] is Map) {
        profName = cursoMap['perfiles']['nombre_completo'] as String?;
      }

      resultado.add(
        StudentSurvey(
          id: encuestaId,
          cursoId: enc['curso_id'] as String,
          cursoNombre: cursoMap?['nombre'] ?? 'Curso',
          profesorNombre: profName,
          fechaClase: enc['fecha_clase']?.toString() ?? '',
          costoTotalInsumos:
              (enc['costo_total_insumos'] as num?)?.toDouble() ?? 0.0,
          tasaBcvUsada: (enc['tasa_bcv_usada'] as num?)?.toDouble(),
          fechaLimite: fechaLimite,
          montoIndividual:
              (enc['monto_individual_calculado'] as num?)?.toDouble() ?? 0.0,
          totalConfirmados: (enc['total_confirmados'] as num?)?.toInt() ?? 0,
          estadoEncuesta: estado,
          respondio: respData != null,
          asistira: respData?['asistira'] as bool?,
          comprobanteUrl: respData?['comprobante_url'] as String?,
          estadoPago: respData?['estado_pago'] as String?,
          montoAsignado: (respData?['monto_asignado'] as num?)?.toDouble(),
          comprobanteSubidoAt: respData?['comprobante_subido_at'] != null
              ? DateTime.tryParse(respData!['comprobante_subido_at'] as String)
              : null,
        ),
      );
    }

    return resultado;
  }

  /// Obtiene el historial de pagos realizados / comprobantes registrados por el alumno
  Future<List<StudentPaymentRecord>> getPaymentHistory({bool isSuperAdmin = false}) async {
    final alumno = await getAlumnoRecord(isSuperAdmin: isSuperAdmin);

    final dynamic data;
    if (isSuperAdmin && alumno == null) {
      data = await _supabase
          .from('respuestas_encuesta')
          .select('''
            id,
            encuesta_id,
            alumno_id,
            asistira,
            monto_asignado,
            comprobante_url,
            estado_pago,
            comprobante_subido_at,
            created_at,
            encuestas_participacion:encuesta_id (
              id,
              curso_id,
              fecha_clase,
              costo_total_insumos,
              monto_individual_calculado,
              estado,
              cursos:curso_id (
                id,
                nombre
              )
            )
          ''')
          .order('created_at', ascending: false);
    } else {
      if (alumno == null) return [];

      data = await _supabase
          .from('respuestas_encuesta')
          .select('''
            id,
            encuesta_id,
            alumno_id,
            asistira,
            monto_asignado,
            comprobante_url,
            estado_pago,
            comprobante_subido_at,
            created_at,
            encuestas_participacion:encuesta_id (
              id,
              curso_id,
              fecha_clase,
              costo_total_insumos,
              monto_individual_calculado,
              estado,
              cursos:curso_id (
                id,
                nombre
              )
            )
          ''')
          .eq('alumno_id', alumno['id'])
          .order('created_at', ascending: false);
    }

    final List<StudentPaymentRecord> records = [];

    for (final item in (data as List)) {
      final asistira = item['asistira'] as bool? ?? false;
      final comprobanteUrl = item['comprobante_url'] as String?;

      // Considerar registros donde asistirá o donde ya cargó comprobante
      if (!asistira && (comprobanteUrl == null || comprobanteUrl.isEmpty)) {
        continue;
      }

      final encMap = item['encuestas_participacion'] as Map<String, dynamic>?;
      final cursoMap = encMap?['cursos'] as Map<String, dynamic>?;
      final montoAsignado =
          (item['monto_asignado'] as num?)?.toDouble() ?? 0.0;
      final montoCalculado =
          (encMap?['monto_individual_calculado'] as num?)?.toDouble() ?? 0.0;
      final montoFinal = montoAsignado > 0 ? montoAsignado : montoCalculado;

      records.add(
        StudentPaymentRecord(
          id: item['id'] as String,
          encuestaId: item['encuesta_id'] as String,
          cursoId: encMap?['curso_id'] as String? ?? '',
          cursoNombre: cursoMap?['nombre'] ?? 'Curso',
          fechaClase: encMap?['fecha_clase']?.toString() ?? '',
          montoCancelado: montoFinal,
          comprobanteUrl: comprobanteUrl,
          estadoPago: (item['estado_pago'] as String?) ?? 'pendiente',
          comprobanteSubidoAt: item['comprobante_subido_at'] != null
              ? DateTime.tryParse(item['comprobante_subido_at'] as String)
              : null,
          fechaRespuesta: item['created_at'] != null
              ? DateTime.tryParse(item['created_at'] as String)
              : null,
          asistira: asistira,
        ),
      );
    }

    return records;
  }

  /// Responder a la encuesta (¿Asistirás a la próxima clase?)
  Future<void> respondToSurvey({
    required String surveyId,
    required bool willAttend,
    bool isSuperAdmin = false,
  }) async {
    final alumno = await getAlumnoRecord(isSuperAdmin: isSuperAdmin);
    if (alumno == null) {
      throw Exception('No se encontró el registro del alumno.');
    }

    // Verificar si la encuesta no ha vencido
    final enc = await _supabase
        .from('encuestas_participacion')
        .select('fecha_limite')
        .eq('id', surveyId)
        .single();
    final limite = DateTime.parse(enc['fecha_limite'] as String);
    if (DateTime.now().isAfter(limite)) {
      throw Exception(
        'El plazo límite para responder a esta encuesta ha expirado.',
      );
    }

    await _supabase.from('respuestas_encuesta').upsert({
      'encuesta_id': surveyId,
      'alumno_id': alumno['id'],
      'asistira': willAttend,
      'estado_pago': 'pendiente',
    }, onConflict: 'encuesta_id, alumno_id');

    try {
      await _supabase.rpc('recalcular_monto_encuesta', params: {'p_encuesta_id': surveyId});
    } catch (_) {}
  }

  /// Subir imagen de comprobante a Supabase Storage y registrar URL
  Future<String> uploadPaymentProof({
    required String surveyId,
    File? imageFile,
    Uint8List? imageBytes,
    String fileExtension = 'jpg',
    bool isSuperAdmin = false,
  }) async {
    final alumno = await getAlumnoRecord(isSuperAdmin: isSuperAdmin);
    if (alumno == null) throw Exception('Alumno no identificado.');

    final fileName =
        '${surveyId}_${alumno['id']}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final filePath = 'comprobantes/$fileName';

    // Subir a Storage (Compatible con Web vía bytes o móvil vía File)
    if (imageBytes != null) {
      await _supabase.storage.from('comprobantes').uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
    } else if (imageFile != null) {
      await _supabase.storage.from('comprobantes').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
    } else {
      throw Exception('No se proporcionó imagen de comprobante.');
    }

    final publicUrl = _supabase.storage
        .from('comprobantes')
        .getPublicUrl(filePath);

    // Actualizar registro en respuestas_encuesta
    await _supabase
        .from('respuestas_encuesta')
        .update({
          'comprobante_url': publicUrl,
          'comprobante_subido_at': DateTime.now().toIso8601String(),
          'estado_pago': 'pendiente',
        })
        .eq('encuesta_id', surveyId)
        .eq('alumno_id', alumno['id']);

    return publicUrl;
  }

  /// Stream en tiempo real de alumnos pendientes de capture en una encuesta
  Stream<List<Map<String, dynamic>>> streamPendientesCapture(
    String encuestaId,
  ) {
    return _supabase
        .from('respuestas_encuesta')
        .stream(primaryKey: ['id'])
        .eq('encuesta_id', encuestaId);
  }
}
