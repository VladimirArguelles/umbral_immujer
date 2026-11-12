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

  /// Consulta si la ventana de inscripciones está activa.
  Future<bool> isInscripcionesActivas() async {
    try {
      final row = await _supabase
          .from('configuracion_general')
          .select('valor')
          .eq('clave', 'inscripciones_activas')
          .maybeSingle();

      if (row != null) {
        final val = row['valor'];
        if (val is bool) return val;
        if (val is String) {
          return val.toLowerCase().trim() == 'true' || val.trim() == '1';
        }
        if (val is num) return val != 0;
      }
    } catch (e) {
      AppLogger.warning(
        'Aviso al leer inscripciones_activas: $e',
        tag: 'INSCRIPCIONES_REPO',
      );
    }

    try {
      final res = await _supabase.rpc<bool>('is_inscripciones_activas');
      return res;
    } catch (_) {
      return false;
    }
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

  /// Registra al aspirante en alumnos + inscripciones de forma atómica con validación de cupos.
  Future<InscripcionResultado> registrarAspirante(
    RegistroAspiranteRequest request,
  ) async {
    final cleanCedula =
        request.cedula.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');

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
