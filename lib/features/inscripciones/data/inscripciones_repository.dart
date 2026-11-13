import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/features/inscripciones/domain/inscripcion_models.dart';
import 'package:umbral_immujer/src/core/utils/app_logger.dart';

class InscripcionesRepository {
  final SupabaseClient _supabase;

  InscripcionesRepository(this._supabase);

  /// Obtiene cursos activos con su cupo máximo, admisión abierta y conteo de inscritos activos.
  Future<List<CursoConCupos>> getCursosConCupos() async {
    try {
      final rpcData = await _supabase.rpc('obtener_cursos_con_cupos');
      if (rpcData is List) {
        return rpcData
            .map((e) => CursoConCupos.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      AppLogger.warning(
        'Fallback en getCursosConCupos usando consulta directa: $e',
        tag: 'INSCRIPCIONES_REPO',
      );
    }

    final cursosRaw = await _supabase
        .from('cursos')
        .select('''
          id,
          nombre,
          descripcion,
          horario,
          estado,
          cupo_maximo,
          admision_abierta,
          inscripciones (
            id,
            estado,
            deleted_at
          )
        ''')
        .eq('estado', 'activo')
        .order('nombre');

    return (cursosRaw as List).map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final inscripciones = (map['inscripciones'] as List? ?? []);
      final activos = inscripciones.where((i) {
        final row = i as Map;
        return row['deleted_at'] == null &&
            (row['estado'] ?? 'activo').toString().toLowerCase() == 'activo';
      }).length;

      return CursoConCupos(
        id: map['id'] as String,
        nombre: (map['nombre'] ?? 'Curso') as String,
        descripcion: map['descripcion'] as String?,
        horario: map['horario'] as String?,
        estado: (map['estado'] ?? 'activo') as String,
        cupoMaximo: (map['cupo_maximo'] as num?)?.toInt() ?? 30,
        admisionAbierta: (map['admision_abierta'] as bool?) ?? true,
        inscritosCount: activos,
      );
    }).toList();
  }

  /// Suscripción en tiempo real a cambios de inscripciones, cursos y configuración global.
  RealtimeChannel subscribeRealtimeUpdates(VoidCallback onChanged) {
    final channel = _supabase.channel('inscripciones_realtime_sync');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inscripciones',
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cursos',
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'configuracion_general',
          callback: (_) => onChanged(),
        )
        .subscribe();
    return channel;
  }

  String? _formatDateOnly(DateTime? d) {
    if (d == null) return null;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime? _parseDateOnly(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().replaceAll('"', '').trim();
    if (str.isEmpty || str == 'null') return null;
    final parsed = DateTime.tryParse(str);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  bool _parseBoolFlag(dynamic val) {
    if (val is bool) return val;
    if (val is String) {
      return val.toLowerCase().trim() == 'true' || val.trim() == '1';
    }
    if (val is num) return val != 0;
    return false;
  }

  /// Obtiene la configuración completa del periodo (bandera + fechas inicio/fin).
  Future<InscripcionesPeriodoConfig> getPeriodoConfig() async {
    try {
      final rpcRes = await _supabase.rpc<dynamic>('get_inscripciones_periodo_config');
      if (rpcRes is Map) {
        return InscripcionesPeriodoConfig.fromJson(
          Map<String, dynamic>.from(rpcRes),
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Fallback lectura periodo desde configuracion_general: $e',
        tag: 'INSCRIPCIONES_REPO',
      );
    }

    bool flag = false;
    DateTime? inicio;
    DateTime? fin;

    try {
      final rows = await _supabase
          .from('configuracion_general')
          .select('clave, valor')
          .inFilter('clave', [
            'inscripciones_activas',
            'inscripciones_fecha_inicio',
            'inscripciones_fecha_fin',
          ]);

      for (final raw in (rows as List)) {
        final map = Map<String, dynamic>.from(raw as Map);
        final clave = map['clave']?.toString();
        final valor = map['valor'];
        if (clave == 'inscripciones_activas') {
          flag = _parseBoolFlag(valor);
        } else if (clave == 'inscripciones_fecha_inicio') {
          inicio = _parseDateOnly(valor);
        } else if (clave == 'inscripciones_fecha_fin') {
          fin = _parseDateOnly(valor);
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Aviso al leer configuracion_general: $e',
        tag: 'INSCRIPCIONES_REPO',
      );
      try {
        flag = await _supabase.rpc<bool>('is_inscripciones_activas');
      } catch (_) {}
    }

    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    var enRango = true;
    if (inicio != null && hoy.isBefore(inicio)) enRango = false;
    if (fin != null && hoy.isAfter(fin)) enRango = false;

    return InscripcionesPeriodoConfig(
      activasFlag: flag,
      activasEfectivo: flag && enRango,
      enRangoFechas: enRango,
      fechaInicio: inicio,
      fechaFin: fin,
    );
  }

  /// Consulta si la ventana de inscripciones está activa considerando fechas.
  Future<bool> isInscripcionesActivas() async {
    final config = await getPeriodoConfig();
    return config.activasEfectivo;
  }

  /// Verifica si la cédula ya existe en alumnos y si tiene inscripción activa en el curso indicado.
  Future<VerificacionCedulaResultado> verificarCedulaEnCurso({
    required String cedula,
    required String cursoId,
  }) async {
    final cleanCedula = cedula.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    final numericCedula = cedula.trim().replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanCedula.isEmpty && numericCedula.isEmpty) {
      return const VerificacionCedulaResultado(yaInscritoEnCurso: false);
    }

    Map<String, dynamic>? alumno;
    if (numericCedula.isNotEmpty) {
      alumno = await _supabase
          .from('alumnos')
          .select('id, nombre_completo, telefono, correo, cedula')
          .eq('cedula', numericCedula)
          .maybeSingle();
    }

    alumno ??= await _supabase
        .from('alumnos')
        .select('id, nombre_completo, telefono, correo, cedula')
        .eq('cedula', cleanCedula)
        .maybeSingle();

    if (alumno == null && numericCedula.isNotEmpty) {
      alumno = await _supabase
          .from('alumnos')
          .select('id, nombre_completo, telefono, correo, cedula')
          .ilike('cedula', '%$numericCedula%')
          .maybeSingle();
    }

    if (alumno == null) {
      return const VerificacionCedulaResultado(yaInscritoEnCurso: false);
    }

    final alumnoId = alumno['id'] as String;
    final existing = await _supabase
        .from('inscripciones')
        .select('id')
        .eq('curso_id', cursoId)
        .eq('alumno_id', alumnoId)
        .eq('estado', 'activo')
        .isFilter('deleted_at', null)
        .maybeSingle();

    return VerificacionCedulaResultado(
      yaInscritoEnCurso: existing != null,
      alumnoId: alumnoId,
      nombreExistente: alumno['nombre_completo'] as String?,
      telefonoExistente: alumno['telefono'] as String?,
      correoExistente: alumno['correo'] as String?,
    );
  }

  /// Valida la inscripción de una alumna contra las reglas de negocio remotas de PostgreSQL (Zero-Rebuild)
  Future<Map<String, dynamic>> validarInscripcionRemota({
    required String cursoId,
    required String cedula,
  }) async {
    try {
      final res = await _supabase.rpc<dynamic>(
        'validar_inscripcion_alumna',
        params: {
          'p_curso_id': cursoId,
          'p_cedula': cedula,
        },
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      AppLogger.warning('Error en validación remota RPC: $e', tag: 'INSCRIPCIONES');
    }
    return {'valido': true, 'codigo': 'LOCAL_PASS'};
  }

  /// Registra al aspirante en alumnos + inscripciones de forma atómica con validación de cupos.
  Future<InscripcionResultado> registrarAspirante(
    RegistroAspiranteRequest request,
  ) async {
    final cleanCedula =
        request.cedula.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');

    // Validación mediante regla de negocio remota en PostgreSQL
    final rpcValidacion = await validarInscripcionRemota(
      cursoId: request.cursoId,
      cedula: cleanCedula,
    );
    if (rpcValidacion['valido'] == false) {
      throw Exception(rpcValidacion['motivo'] ?? 'Validación de inscripción rechazada por el sistema.');
    }

    final check = await verificarCedulaEnCurso(
      cedula: cleanCedula,
      cursoId: request.cursoId,
    );
    if (check.yaInscritoEnCurso) {
      throw Exception(
        'La cédula ${request.cedula.trim()} ya cuenta con una inscripción activa en el curso seleccionado.',
      );
    }

    final res = await _supabase.rpc<dynamic>(
      'registrar_inscripcion_aspirante',
      params: {
        'p_curso_id': request.cursoId,
        'p_cedula': cleanCedula,
        'p_nombres': request.nombres.trim(),
        'p_apellidos': request.apellidos.trim(),
        'p_telefono': request.telefono.trim(),
        'p_correo': request.correo.trim().toLowerCase(),
      },
    );

    if (res is Map) {
      return InscripcionResultado.fromJson(Map<String, dynamic>.from(res));
    }
    throw Exception('Respuesta inesperada al procesar la inscripción.');
  }

  /// Lista las inscripciones activas recientes (opcionalmente filtradas por curso).
  Future<List<InscripcionRecienteItem>> getInscripcionesRecientes({
    String? cursoId,
    int limit = 20,
  }) async {
    var query = _supabase
        .from('inscripciones')
        .select('''
          id,
          curso_id,
          origen,
          created_at,
          cursos:curso_id ( nombre ),
          alumnos:alumno_id ( nombre_completo, cedula, telefono, correo )
        ''')
        .eq('estado', 'activo')
        .isFilter('deleted_at', null);

    if (cursoId != null && cursoId.isNotEmpty) {
      query = query.eq('curso_id', cursoId);
    }

    final data = await query.order('created_at', ascending: false).limit(limit);
    return (data as List).map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final curso = map['cursos'] as Map<String, dynamic>?;
      final alumno = map['alumnos'] as Map<String, dynamic>?;
      return InscripcionRecienteItem(
        id: map['id'] as String,
        cursoId: (map['curso_id'] ?? '') as String,
        cursoNombre: (curso?['nombre'] ?? 'Curso') as String,
        alumnoNombre: (alumno?['nombre_completo'] ?? 'Aspirante') as String,
        cedula: (alumno?['cedula'] ?? '') as String,
        telefono: alumno?['telefono'] as String?,
        correo: alumno?['correo'] as String?,
        origen: (map['origen'] ?? 'historico') as String,
        createdAt: DateTime.tryParse('${map['created_at']}')?.toLocal(),
      );
    }).toList();
  }

  // ─── Controles de Super Admin ─────────────────────────────────────────────

  Future<void> setInscripcionesActivas(bool activas) async {
    try {
      await _supabase.rpc(
        'admin_set_inscripciones_activas',
        params: {'p_activas': activas},
      );
      return;
    } catch (e) {
      AppLogger.warning(
        'Fallback upsert en admin_set_inscripciones_activas: $e',
        tag: 'INSCRIPCIONES_ADMIN',
      );
    }

    await _supabase.from('configuracion_general').upsert(
      {
        'clave': 'inscripciones_activas',
        'valor': activas,
        'descripcion':
            'Habilita o deshabilita el periodo de inscripciones y el acceso temporal de operadores de inscripción',
        'actualizado_en': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'clave',
    );
  }

  /// Actualiza el periodo de inscripciones (estado + fechas inicio/fin)
  Future<InscripcionesPeriodoConfig> setInscripcionesPeriodo({
    required bool activas,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    if (fechaInicio != null &&
        fechaFin != null &&
        fechaFin.isBefore(DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day))) {
      throw Exception('La fecha de cierre no puede ser anterior a la fecha de inicio.');
    }

    final inicioStr = _formatDateOnly(fechaInicio);
    final finStr = _formatDateOnly(fechaFin);

    try {
      final rpcRes = await _supabase.rpc<dynamic>(
        'admin_set_inscripciones_periodo',
        params: {
          'p_activas': activas,
          'p_fecha_inicio': inicioStr,
          'p_fecha_fin': finStr,
        },
      );
      if (rpcRes is Map) {
        return InscripcionesPeriodoConfig.fromJson(
          Map<String, dynamic>.from(rpcRes),
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Fallback en admin_set_inscripciones_periodo: $e',
        tag: 'INSCRIPCIONES_ADMIN',
      );
    }

    await setInscripcionesActivas(activas);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await _supabase.from('configuracion_general').upsert(
      [
        {
          'clave': 'inscripciones_fecha_inicio',
          'valor': inicioStr,
          'descripcion': 'Fecha de inicio (YYYY-MM-DD) del periodo de inscripciones',
          'actualizado_en': nowIso,
        },
        {
          'clave': 'inscripciones_fecha_fin',
          'valor': finStr,
          'descripcion': 'Fecha de cierre (YYYY-MM-DD) del periodo de inscripciones',
          'actualizado_en': nowIso,
        },
      ],
      onConflict: 'clave',
    );

    return getPeriodoConfig();
  }

  /// Actualiza cupo máximo y admisión abierta de un curso específico.
  Future<void> setCursoCupo({
    required String cursoId,
    required int cupoMaximo,
    bool? admisionAbierta,
  }) async {
    try {
      await _supabase.rpc(
        'admin_set_curso_cupo',
        params: {
          'p_curso_id': cursoId,
          'p_cupo_maximo': cupoMaximo,
          'p_admision_abierta': admisionAbierta,
        },
      );
      return;
    } catch (e) {
      AppLogger.warning(
        'Fallback update directo en setCursoCupo: $e',
        tag: 'INSCRIPCIONES_ADMIN',
      );
    }

    final payload = <String, dynamic>{
      'cupo_maximo': cupoMaximo,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (admisionAbierta != null) {
      payload['admision_abierta'] = admisionAbierta;
    }
    await _supabase.from('cursos').update(payload).eq('id', cursoId);
  }

  Future<List<OperadorTemporal>> getOperadoresTemporales() async {
    try {
      final rpcRes = await _supabase.rpc('obtener_operadores_inscripcion');
      if (rpcRes is List) {
        return rpcRes
            .map((e) => OperadorTemporal.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      AppLogger.warning(
        'Fallback en getOperadoresTemporales: $e',
        tag: 'INSCRIPCIONES_ADMIN',
      );
    }

    final rows = await _supabase
        .from('perfiles')
        .select(
          'id, user_id, nombre_completo, cedula, telefono, correo, email, acceso_activo, created_at',
        )
        .eq('rol', 'operador_inscripcion')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => OperadorTemporal.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> crearOperadorTemporal({
    required String email,
    required String password,
    required String nombreCompleto,
    String? cedula,
    String? telefono,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'manage-operadores',
        body: {
          'action': 'create',
          'email': email.trim().toLowerCase(),
          'password': password.trim(),
          'nombre_completo': nombreCompleto.trim(),
          'cedula': cedula?.trim(),
          'telefono': telefono?.trim(),
        },
      );
      if (response.status >= 200 && response.status < 300) {
        return;
      }
    } catch (e) {
      AppLogger.info(
        'Edge function manage-operadores no disponible, usando RPC SQL: $e',
        tag: 'INSCRIPCIONES_ADMIN',
      );
    }

    await _supabase.rpc(
      'admin_create_operador_inscripcion',
      params: {
        'p_email': email.trim().toLowerCase(),
        'p_password': password.trim(),
        'p_nombre_completo': nombreCompleto.trim(),
        'p_cedula': cedula?.trim().isNotEmpty == true ? cedula!.trim() : null,
        'p_telefono':
            telefono?.trim().isNotEmpty == true ? telefono!.trim() : null,
      },
    );
  }

  Future<void> toggleOperadorAcceso({
    required String userId,
    required bool activo,
  }) async {
    try {
      await _supabase.rpc(
        'admin_toggle_operador_acceso',
        params: {'p_user_id': userId, 'p_activo': activo},
      );
      return;
    } catch (e) {
      AppLogger.warning(
        'Fallback en toggleOperadorAcceso: $e',
        tag: 'INSCRIPCIONES_ADMIN',
      );
    }

    await _supabase
        .from('perfiles')
        .update({
          'acceso_activo': activo,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }

  Future<void> eliminarOperadorTemporal(String userId) async {
    try {
      await _supabase.rpc('admin_delete_user', params: {'p_user_id': userId});
      return;
    } catch (_) {}

    try {
      final response = await _supabase.functions.invoke(
        'manage-operadores',
        body: {'action': 'delete', 'user_id': userId},
      );
      if (response.status >= 200 && response.status < 300) {
        return;
      }
    } catch (_) {}

    await _supabase.from('perfiles').delete().eq('id', userId);
  }
}
