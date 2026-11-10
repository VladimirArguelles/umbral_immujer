import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/src/core/services/app_update_service.dart';
import 'package:umbral_immujer/src/core/utils/app_logger.dart';

import '../domain/user_profile.dart';

class AlumnoValidationResult {
  final bool foundInAlumnos;
  final bool hasActiveInscripcion;
  final bool isLinked;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  const AlumnoValidationResult({
    required this.foundInAlumnos,
    required this.hasActiveInscripcion,
    this.isLinked = false,
    this.data,
    this.errorMessage,
  });

  bool get isValid => foundInAlumnos && hasActiveInscripcion && !isLinked;
}

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  User? get currentUser => _supabase.auth.currentUser;

  /// Valida si el alumno existe en el padrón institucional y si posee inscripción activa.
  Future<AlumnoValidationResult> validateAlumnoEligibility({
    required String cedula,
    String? email,
  }) async {
    final cleanCedula = cedula.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    final numericCedula = cedula.trim().replaceAll(RegExp(r'[^0-9]'), '');

    try {
      final alumnoData = await _findAlumnoRecord(
        cleanCedula: cleanCedula,
        numericCedula: numericCedula,
        email: email,
      );

      if (alumnoData == null) {
        AppLogger.warning(
          'Validación fallida: Cédula $cedula no encontrada en el padrón de alumnos',
          tag: 'AUTH_VALIDATION',
        );
        return AlumnoValidationResult(
          foundInAlumnos: false,
          hasActiveInscripcion: false,
          errorMessage:
              'Acceso denegado: El documento $cedula no se encuentra registrado en el padrón de alumnos de IMMUJER.',
        );
      }

      if (alumnoData['user_id'] != null) {
        return AlumnoValidationResult(
          foundInAlumnos: true,
          hasActiveInscripcion: false,
          isLinked: true,
          data: alumnoData,
          errorMessage:
              'Este registro ya está vinculado a una cuenta. Inicia sesión o recupera el acceso existente.',
        );
      }

      final alumnoId = alumnoData['id'] as String;
      final hasActiveEnrollment = await _hasActiveInscripcion(alumnoId);

      if (!hasActiveEnrollment) {
        return AlumnoValidationResult(
          foundInAlumnos: true,
          hasActiveInscripcion: false,
          data: alumnoData,
          errorMessage:
              'Acceso denegado: El alumno figura en el padrón, pero no cuenta con una inscripción activa en ningún curso. Debe formalizar su inscripción primero.',
        );
      }

      return AlumnoValidationResult(
        foundInAlumnos: true,
        hasActiveInscripcion: true,
        data: alumnoData,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error durante validación de elegibilidad de alumno ($cedula)',
        tag: 'AUTH_VALIDATION',
        error: e,
        stackTrace: stackTrace,
      );
      return AlumnoValidationResult(
        foundInAlumnos: false,
        hasActiveInscripcion: false,
        errorMessage: 'Error de conexión al verificar el padrón de alumnos: $e',
      );
    }
  }

  /// Búsqueda modular de registro de alumno en base de datos
  Future<Map<String, dynamic>?> _findAlumnoRecord({
    required String cleanCedula,
    required String numericCedula,
    String? email,
  }) async {
    Map<String, dynamic>? alumnoData;

    if (numericCedula.isNotEmpty) {
      alumnoData = await _supabase
          .from('alumnos')
          .select()
          .eq('cedula', numericCedula)
          .maybeSingle();
    }

    alumnoData ??= await _supabase
        .from('alumnos')
        .select()
        .eq('cedula', cleanCedula)
        .maybeSingle();

    if (alumnoData == null && numericCedula.isNotEmpty) {
      alumnoData = await _supabase
          .from('alumnos')
          .select()
          .ilike('cedula', '%$numericCedula%')
          .maybeSingle();
    }

    if (alumnoData == null && email != null && email.trim().isNotEmpty) {
      alumnoData = await _supabase
          .from('alumnos')
          .select()
          .ilike('correo', email.trim())
          .maybeSingle();
    }

    return alumnoData;
  }

  /// Verifica si el alumno cuenta con inscripción activa no eliminada
  Future<bool> _hasActiveInscripcion(String alumnoId) async {
    final List<dynamic> inscripciones = await _supabase
        .from('inscripciones')
        .select('id, curso_id, estado')
        .eq('alumno_id', alumnoId)
        .filter('deleted_at', 'is', null);

    return inscripciones.isNotEmpty;
  }

  /// Método compatible con código anterior: retorna los datos si es elegible
  Future<Map<String, dynamic>?> checkAlumnoPreRegistered({
    required String cedula,
    String? email,
  }) async {
    final result = await validateAlumnoEligibility(
      cedula: cedula,
      email: email,
    );
    if (!result.isValid) {
      return null;
    }
    return result.data;
  }

  /// Valida si el docente existe en el padrón de Profesores autorizados (perfiles o profesores)
  Future<Map<String, dynamic>?> checkProfesorPreRegistered({
    required String cedula,
    String? email,
    String? telefono,
  }) async {
    final cleanCedula = cedula.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    final numericCedula = cedula.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final cleanPhone =
        telefono?.trim().replaceAll(RegExp(r'[^0-9]'), '') ?? '';

    try {
      // 1. Buscar en perfiles (profesores pre-registrados en perfiles)
      final profile = await _findProfesorInPerfiles(
        cleanCedula: cleanCedula,
        numericCedula: numericCedula,
        cleanPhone: cleanPhone,
        email: email,
      );

      if (profile != null) {
        final isAlreadyLinked = profile['user_id'] != null;
        if (!isAlreadyLinked ||
            profile['correo'] == null ||
            (profile['correo'] as String).isEmpty) {
          return profile;
        }
        return null;
      }

      // 2. Retrocompatibilidad: buscar en la tabla 'profesores'
      return await _findProfesorInLegacyTable(
        cleanCedula: cleanCedula,
        numericCedula: numericCedula,
        cleanPhone: cleanPhone,
        email: email,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al buscar profesor pre-registrado ($cedula)',
        tag: 'AUTH_PROFESOR',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> _findProfesorInPerfiles({
    required String cleanCedula,
    required String numericCedula,
    required String cleanPhone,
    String? email,
  }) async {
    Map<String, dynamic>? profile;

    if (numericCedula.isNotEmpty) {
      profile = await _supabase
          .from('perfiles')
          .select()
          .inFilter('rol', ['profesor', 'teacher'])
          .eq('cedula', numericCedula)
          .maybeSingle();
    }

    profile ??= await _supabase
        .from('perfiles')
        .select()
        .inFilter('rol', ['profesor', 'teacher'])
        .eq('cedula', cleanCedula)
        .maybeSingle();

    if (profile == null && numericCedula.isNotEmpty) {
      profile = await _supabase
          .from('perfiles')
          .select()
          .inFilter('rol', ['profesor', 'teacher'])
          .ilike('cedula', '%$numericCedula%')
          .maybeSingle();
    }

    if (profile == null && cleanPhone.length >= 7) {
      profile = await _supabase
          .from('perfiles')
          .select()
          .inFilter('rol', ['profesor', 'teacher'])
          .ilike('telefono', '%$cleanPhone%')
          .maybeSingle();
    }

    if (profile == null && email != null && email.trim().isNotEmpty) {
      profile = await _supabase
          .from('perfiles')
          .select()
          .inFilter('rol', ['profesor', 'teacher'])
          .ilike('correo', email.trim())
          .maybeSingle();
    }

    return profile;
  }

  Future<Map<String, dynamic>?> _findProfesorInLegacyTable({
    required String cleanCedula,
    required String numericCedula,
    required String cleanPhone,
    String? email,
  }) async {
    Map<String, dynamic>? res;

    if (numericCedula.isNotEmpty) {
      res = await _supabase
          .from('profesores')
          .select()
          .eq('cedula', numericCedula)
          .maybeSingle();
    }

    res ??= await _supabase
        .from('profesores')
        .select()
        .eq('cedula', cleanCedula)
        .maybeSingle();

    if (res == null && numericCedula.isNotEmpty) {
      res = await _supabase
          .from('profesores')
          .select()
          .ilike('cedula', '%$numericCedula%')
          .maybeSingle();
    }

    if (res == null && cleanPhone.length >= 7) {
      res = await _supabase
          .from('profesores')
          .select()
          .ilike('telefono', '%$cleanPhone%')
          .maybeSingle();
    }

    if (res != null && res['user_id'] == null) return res;

    if (email != null && email.isNotEmpty) {
      final resEmail = await _supabase
          .from('profesores')
          .select()
          .ilike('correo', email.trim())
          .maybeSingle();
      if (resEmail != null && resEmail['user_id'] == null) return resEmail;
    }

    return null;
  }

  /// Registro de usuario con validación estricta y vinculación atómica
  Future<UserProfile> registerUser({
    required String email,
    required String password,
    required String cedula,
    required String nombreCompleto,
    required String telefono,
    required UserRole role,
  }) async {
    final cleanCedula = cedula.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    Object? rosterId;

    if (role == UserRole.alumno) {
      final alumnoCheck = await validateAlumnoEligibility(
        cedula: cleanCedula,
        email: email,
      );
      if (!alumnoCheck.isValid) {
        throw Exception(
          alumnoCheck.errorMessage ??
              'Acceso denegado: Solo alumnos registrados e inscritos en IMMUJER pueden registrarse.',
        );
      }
      rosterId = alumnoCheck.data?['id'];
    } else if (role == UserRole.profesor) {
      final profesorData = await checkProfesorPreRegistered(
        cedula: cleanCedula,
        email: email,
        telefono: telefono,
      );
      if (profesorData == null) {
        throw Exception(
          'Acceso denegado: El docente no figura en el registro oficial de profesores de IMMUJER.',
        );
      }
      rosterId = profesorData['id'];
    }

    try {
      // 1. Registro en Supabase Auth
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'nombre_completo': nombreCompleto.trim(),
          'cedula': cleanCedula,
          'telefono': telefono.trim(),
          'rol': role.toDbString(),
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('No se pudo completar el registro.');
      }

      // 2. Sincronización del perfil principal
      await _syncUserProfile(
        userId: user.id,
        email: email,
        nombreCompleto: nombreCompleto,
        cedula: cleanCedula,
        telefono: telefono,
        role: role,
      );

      // 3. Vinculación complementaria de resguardo
      await _linkAuxiliaryTables(
        userId: user.id,
        email: email,
        role: role,
        rosterId: rosterId,
      );

      AppLogger.info(
        'Usuario registrado exitosamente: ${user.id} ($email) con rol ${role.name}',
        tag: 'AUTH_REGISTER',
      );

      return UserProfile(
        id: user.id,
        email: email,
        fullName: nombreCompleto,
        cedula: cleanCedula,
        telefono: telefono,
        role: role,
      );
    } on AuthException catch (e) {
      AppLogger.warning('Error de autenticación en signUp: ${e.message}', tag: 'AUTH_SIGNUP', error: e);
      throw Exception(e.message);
    } catch (e, stackTrace) {
      AppLogger.error('Fallo general en registerUser', tag: 'AUTH_REGISTER', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _syncUserProfile({
    required String userId,
    required String email,
    required String nombreCompleto,
    required String cedula,
    required String telefono,
    required UserRole role,
  }) async {
    try {
      await _supabase.from('perfiles').update({
        'user_id': userId,
        'nombre_completo': nombreCompleto.trim(),
        'cedula': cedula,
        'telefono': telefono.trim(),
        'correo': email.trim(),
        'email': email.trim(),
        'rol': role.toDbString(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      AppLogger.warning(
        'Aviso: Sincronización de perfil atendida por trigger institucional: $e',
        tag: 'AUTH_SYNC_PROFILE',
      );
    }
  }

  Future<void> _linkAuxiliaryTables({
    required String userId,
    required String email,
    required UserRole role,
    required Object? rosterId,
  }) async {
    if (rosterId is! String) return;
    try {
      if (role == UserRole.alumno) {
        await _supabase
            .from('alumnos')
            .update({'user_id': userId, 'correo': email.trim()})
            .eq('id', rosterId)
            .isFilter('user_id', null);
      } else if (role == UserRole.profesor) {
        await _supabase
            .from('profesores')
            .update({'user_id': userId, 'correo': email.trim()})
            .eq('id', rosterId)
            .isFilter('user_id', null);
      }
    } catch (e) {
      AppLogger.warning(
        'Aviso: Vinculación auxiliar atendida previamente por triggers: $e',
        tag: 'AUTH_LINK_AUX',
      );
    }
  }

  /// Inicio de sesión estándar con captura segura de excepciones
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Credenciales incorrectas');
      }

      final profile = await getCurrentProfile();
      if (profile == null) {
        throw Exception('Perfil de usuario no encontrado en la base de datos.');
      }

      AppLogger.info('Inicio de sesión exitoso: ${profile.email} (${profile.rol.displayName})', tag: 'AUTH_SIGNIN');
      return profile;
    } on AuthException catch (e) {
      AppLogger.warning('Fallo en autenticación: ${e.message}', tag: 'AUTH_SIGNIN');
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        throw Exception('Correo o contraseña incorrectos. Verifica tus datos.');
      }
      throw Exception(e.message);
    } catch (e, stackTrace) {
      AppLogger.error('Excepción no controlada durante signIn', tag: 'AUTH_SIGNIN', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Obtener perfil actual desde la base de datos
  Future<UserProfile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    Map<String, dynamic>? data;
    try {
      data = await _supabase
          .from('perfiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
    } catch (e, stackTrace) {
      AppLogger.warning(
        'Aviso: Falla al consultar perfiles, recurriendo a userMetadata',
        tag: 'AUTH_PROFILE',
        error: e,
        stackTrace: stackTrace,
      );
    }

    if (data == null) {
      final meta = user.userMetadata ?? {};
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName:
            (meta['nombre_completo'] ?? user.email ?? 'Usuario') as String,
        cedula: meta['cedula'] as String?,
        telefono: meta['telefono'] as String?,
        role: UserRole.fromString(meta['rol'] as String?),
      );
    }

    return UserProfile.fromJson(data);
  }

  Future<void> signOut() async {
    try {
      AppUpdateService.resetSessionCheck();
      await _supabase.auth.signOut();
      AppLogger.info('Sesión cerrada correctamente', tag: 'AUTH_SIGNOUT');
    } catch (e, stackTrace) {
      AppLogger.error('Error al cerrar sesión', tag: 'AUTH_SIGNOUT', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
