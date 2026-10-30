import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/student_models.dart';

class StudentRepository {
  final SupabaseClient _supabase;

  StudentRepository(this._supabase);

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Obtiene el registro de 'alumnos' correspondiente al usuario autenticado
  Future<Map<String, dynamic>?> getAlumnoRecord() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final record = await _supabase
        .from('alumnos')
        .select()
        .eq('user_id', uid)
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
          .maybeSingle();
      if (byEmail != null) {
        final linked = await _supabase
            .from('alumnos')
            .update({'user_id': uid})
            .eq('id', byEmail['id'])
            .isFilter('user_id', null)
            .select()
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
    return null;
  }

  /// Obtiene los cursos activos e historial del alumno
  Future<List<StudentCourse>> getMyCourses({String? statusFilter}) async {
    final alumno = await getAlumnoRecord();
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
    return (data as List).map((item) => StudentCourse.fromJson(item)).toList();
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
  Future<List<StudentSurvey>> getActiveSurveys() async {
    final alumno = await getAlumnoRecord();
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
    if (cursoIds.isEmpty) return [];

    final encuestasData = await _supabase
        .from('encuestas_participacion')
        .select('''
          id,
          curso_id,
          fecha_clase,
          costo_total_insumos,
          fecha_limite,
          monto_individual_calculado,
          total_confirmados,
          estado,
          cursos:curso_id (
            nombre
          )
        ''')
        .inFilter('curso_id', cursoIds)
        .eq('estado', 'activa')
        .order('fecha_limite', ascending: true);

    final List<StudentSurvey> resultado = [];

    for (final enc in (encuestasData as List)) {
      final encuestaId = enc['id'] as String;

      // Buscar respuesta del alumno
      final respData = await _supabase
          .from('respuestas_encuesta')
          .select()
          .eq('encuesta_id', encuestaId)
          .eq('alumno_id', alumno['id'])
          .maybeSingle();

      final cursoMap = enc['cursos'] as Map<String, dynamic>?;

      resultado.add(
        StudentSurvey(
          id: encuestaId,
          cursoId: enc['curso_id'] as String,
          cursoNombre: cursoMap?['nombre'] ?? 'Curso',
          fechaClase: enc['fecha_clase']?.toString() ?? '',
          costoTotalInsumos:
              (enc['costo_total_insumos'] as num?)?.toDouble() ?? 0.0,
          fechaLimite:
              DateTime.tryParse(enc['fecha_limite'] as String? ?? '') ??
              DateTime.now(),
          montoIndividual:
              (enc['monto_individual_calculado'] as num?)?.toDouble() ?? 0.0,
          totalConfirmados: (enc['total_confirmados'] as num?)?.toInt() ?? 0,
          estadoEncuesta: enc['estado'] as String? ?? 'activa',
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
  Future<List<StudentSurvey>> getSurveysHistory() async {
    final alumno = await getAlumnoRecord();
    if (alumno == null) return [];

    final inscripciones = await _supabase
        .from('inscripciones')
        .select('curso_id')
        .eq('alumno_id', alumno['id'])
        .isFilter('deleted_at', null);

    final cursoIds = (inscripciones as List)
        .map((i) => i['curso_id'] as String)
        .toList();
    if (cursoIds.isEmpty) return [];

    final encuestasData = await _supabase
        .from('encuestas_participacion')
        .select('''
          id,
          curso_id,
          fecha_clase,
          costo_total_insumos,
          fecha_limite,
          monto_individual_calculado,
          total_confirmados,
          estado,
          cursos:curso_id (
            nombre
          )
        ''')
        .inFilter('curso_id', cursoIds)
        .order('fecha_clase', ascending: false);

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

      final respData = await _supabase
          .from('respuestas_encuesta')
          .select()
          .eq('encuesta_id', encuestaId)
          .eq('alumno_id', alumno['id'])
          .maybeSingle();

      final cursoMap = enc['cursos'] as Map<String, dynamic>?;

      resultado.add(
        StudentSurvey(
          id: encuestaId,
          cursoId: enc['curso_id'] as String,
          cursoNombre: cursoMap?['nombre'] ?? 'Curso',
          fechaClase: enc['fecha_clase']?.toString() ?? '',
          costoTotalInsumos:
              (enc['costo_total_insumos'] as num?)?.toDouble() ?? 0.0,
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
  Future<List<StudentPaymentRecord>> getPaymentHistory() async {
    final alumno = await getAlumnoRecord();
    if (alumno == null) return [];

    final data = await _supabase
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
  }) async {
    final alumno = await getAlumnoRecord();
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
  }

  /// Subir imagen de comprobante a Supabase Storage y registrar URL
  Future<String> uploadPaymentProof({
    required String surveyId,
    required File imageFile,
  }) async {
    final alumno = await getAlumnoRecord();
    if (alumno == null) throw Exception('Alumno no identificado.');

    final fileExt = imageFile.path.split('.').last;
    final fileName =
        '${surveyId}_${alumno['id']}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = 'comprobantes/$fileName';

    // Subir a Storage
    await _supabase.storage
        .from('comprobantes')
        .upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

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
