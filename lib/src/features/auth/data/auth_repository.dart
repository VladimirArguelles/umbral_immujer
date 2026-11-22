import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// Validador centralizado de políticas de seguridad para contraseñas de producción
  static String? validatePasswordStrength(String password) {
    final trimmed = password.trim();
    if (trimmed.length < 8) {
      return 'La contraseña debe contener al menos 8 caracteres.';
    }
    final hasLetter = trimmed.contains(RegExp(r'[a-zA-Z]'));
    final hasNumber = trimmed.contains(RegExp(r'[0-9]'));
    if (!hasLetter || !hasNumber) {
      return 'La contraseña debe combinar letras y al menos un número.';
    }
    return null;
  }

  /// Valida si el alumno existe en el padrón institucional y si posee inscripción activa.
  /// Implementa consulta segura vía RPC verificar_pre_registro_alumno sin exponer la tabla alumnos.
  Future<AlumnoValidationResult> validateAlumnoEligibility({
    required String cedula,
    String? email,
  }) async {
    final cleanCedula = cedula.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    final numericCedula = cedula.trim().replaceAll(RegExp(r'[^0-9]'), '');

    try {
      // 1. Invocar RPC segura de pre-registro (sin exponer la tabla alumnos al público)
      try {
        final rpcRes = await _supabase.rpc('verificar_pre_registro_alumno', params: {
          'p_cedula': cleanCedula.isNotEmpty ? cleanCedula : numericCedula,
          'p_correo': email?.trim(),
        });

        if (rpcRes is Map) {
          final valido = rpcRes['valido'] == true;
          final codigo = rpcRes['codigo'] as String?;
          final motivo = rpcRes['motivo'] as String?;

          if (valido) {
            final tieneInscripcion = rpcRes['tiene_inscripcion'] == true;
            return AlumnoValidationResult(
              foundInAlumnos: true,
              hasActiveInscripcion: tieneInscripcion,
              data: Map<String, dynamic>.from(rpcRes),
              errorMessage: tieneInscripcion
                  ? null
                  : 'Acceso denegado: La participante figura en el padrón, pero no cuenta con inscripción activa en ningún curso.',
            );
          } else if (codigo == 'YA_REGISTRADO') {
            return AlumnoValidationResult(
              foundInAlumnos: true,
              hasActiveInscripcion: false,
              isLinked: true,
              errorMessage: motivo ?? 'Este registro ya está vinculado a una cuenta activa.',
            );
          } else {
            return AlumnoValidationResult(
              foundInAlumnos: false,
              hasActiveInscripcion: false,
              errorMessage: motivo ?? 'Acceso denegado: El documento $cedula no se encuentra registrado en el padrón.',
            );
          }
        }
      } catch (rpcErr) {
        AppLogger.warning(
          'RPC verificar_pre_registro_alumno no disponible o falló ($rpcErr). Intentando consulta directa...',
          tag: 'AUTH_VALIDATION',
        );
      }

      // 2. Fallback de consulta directa (en caso de que el usuario ya esté autenticado o desarrollo local)
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

    final passwordStrengthErr = validatePasswordStrength(password);
    if (passwordStrengthErr != null) {
      throw Exception(passwordStrengthErr);
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

      if (profile.role == UserRole.operadorInscripcion) {
        final accessIssue = await getOperadorAccessRestrictionReason(profile);
        if (accessIssue != null) {
          await _supabase.auth.signOut();
          throw Exception(accessIssue);
        }
      }

      AppLogger.info('Inicio de sesión exitoso: ${profile.email} (${profile.rol.displayName})', tag: 'AUTH_SIGNIN');
      return profile;
    } on AuthException catch (e) {
      AppLogger.warning('Fallo en autenticación: ${e.message}', tag: 'AUTH_SIGNIN');
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        throw Exception('Correo o contraseña incorrectos. Verifica tus datos.');
      }
      if (e.message.toLowerCase().contains('user is banned')) {
        throw Exception(
          'Tu acceso temporal ha sido revocado o suspendido por el Super Admin.',
        );
      }
      throw Exception(e.message);
    } catch (e, stackTrace) {
      AppLogger.error('Excepción no controlada durante signIn', tag: 'AUTH_SIGNIN', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Consulta el estado global del periodo de inscripciones en configuracion_general
  Future<bool> isInscripcionesActivas() async {
    try {
      final row = await _supabase
          .from('configuracion_general')
          .select('valor')
          .eq('clave', 'inscripciones_activas')
          .maybeSingle();
      if (row != null) {
        final raw = row['valor'];
        if (raw is bool) return raw;
        if (raw is String) {
          return raw.toLowerCase().trim() == 'true' || raw.trim() == '1';
        }
        if (raw is num) return raw != 0;
      }
    } catch (e) {
      AppLogger.warning(
        'Aviso al consultar inscripciones_activas en configuracion_general: $e',
        tag: 'AUTH_CONFIG',
      );
    }

    try {
      final res = await _supabase.rpc<bool>('is_inscripciones_activas');
      return res;
    } catch (_) {
      return false;
    }
  }

  /// Verifica si un Operador de Inscripción tiene permiso vigente; retorna motivo si está bloqueado.
  Future<String?> getOperadorAccessRestrictionReason(UserProfile profile) async {
    if (profile.role != UserRole.operadorInscripcion) return null;
    if (!profile.accesoActivo) {
      return 'Tu acceso temporal como Operador de Inscripción ha sido revocado por el Super Admin.';
    }
    final activeWindow = await isInscripcionesActivas();
    if (!activeWindow) {
      return 'El periodo de inscripciones se encuentra cerrado actualmente. Los accesos temporales están deshabilitados.';
    }
    return null;
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

  /// Envía un correo con enlace y código para restablecer la contraseña.
  /// Si el usuario ingresó su cédula o usuario en vez de un correo directo,
  /// busca en perfiles o en el padrón de alumnos para encontrar su correo electrónico registrado.
  Future<String> sendPasswordResetEmail(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) {
      throw Exception('Por favor ingresa tu correo electrónico o tu número de cédula.');
    }

    String targetEmail = cleanInput;

    // Si el usuario ingresó cédula o identificador en vez de un correo
    if (!cleanInput.contains('@')) {
      final safeCleanInput = cleanInput.replaceAll(RegExp(r'[^0-9a-zA-Z\-_]'), '');
      final cleanCedula = cleanInput.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
      final numericCedula = cleanInput.replaceAll(RegExp(r'[^0-9]'), '');

      // 1. Buscar en perfiles
      try {
        final perfil = await _supabase
            .from('perfiles')
            .select('email, correo')
            .or('cedula.eq.$safeCleanInput,cedula.eq.$cleanCedula,cedula.eq.$numericCedula')
            .limit(1)
            .maybeSingle();

        if (perfil != null) {
          final emailVal = perfil['email'] ?? perfil['correo'];
          if (emailVal != null && emailVal.toString().trim().isNotEmpty) {
            targetEmail = emailVal.toString().trim();
          }
        }
      } catch (e) {
        AppLogger.warning('No se pudo resolver cédula en perfiles: $e', tag: 'AUTH_RESET');
      }

      // 2. Si no se halló en perfiles, buscar en alumnos
      if (!targetEmail.contains('@')) {
        try {
          final alumno = await _supabase
              .from('alumnos')
              .select('email, correo')
              .or('cedula.eq.$safeCleanInput,cedula.eq.$cleanCedula,cedula.eq.$numericCedula')
              .limit(1)
              .maybeSingle();

          if (alumno != null) {
            final emailVal = alumno['email'] ?? alumno['correo'];
            if (emailVal != null && emailVal.toString().trim().isNotEmpty) {
              targetEmail = emailVal.toString().trim();
            }
          }
        } catch (e) {
          AppLogger.warning('No se pudo resolver cédula en alumnos: $e', tag: 'AUTH_RESET');
        }
      }

      if (!targetEmail.contains('@')) {
        throw Exception(
          'No se encontró ningún correo electrónico registrado asociado a "$cleanInput". Verifica tus datos o ingresa tu correo directamente.',
        );
      }
    }

    final String redirectUrl;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.contains('github.io')) {
        redirectUrl = '$origin/umbral_immujer/#/reset-password';
      } else {
        redirectUrl = '$origin/#/reset-password';
      }
    } else {
      // Esquema personalizado para Deep Link en Android / Móvil
      redirectUrl = 'com.example.umbral_immujer://reset-password';
    }

    try {
      await _supabase.auth.resetPasswordForEmail(
        targetEmail,
        redirectTo: redirectUrl,
      );
      AppLogger.info('Correo de recuperación solicitado para $targetEmail con redirect $redirectUrl', tag: 'AUTH_RESET');
      return targetEmail;
    } on AuthException catch (e) {
      AppLogger.warning('Fallo en Supabase resetPasswordForEmail: ${e.message}', tag: 'AUTH_RESET');
      if (e.message.toLowerCase().contains('rate limit')) {
        throw Exception('Has alcanzado el límite de intentos permitidos. Espera unos minutos antes de reintentar.');
      }
      throw Exception(e.message);
    } catch (e, stackTrace) {
      AppLogger.error('Excepción al enviar correo de recuperación', tag: 'AUTH_RESET', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Verifica el código OTP recibido por correo y actualiza la contraseña de inmediato.
  Future<void> verifyOtpAndResetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim();
    final cleanToken = token.trim();
    final cleanPassword = newPassword.trim();

    final passwordStrengthErr = validatePasswordStrength(cleanPassword);
    if (passwordStrengthErr != null) {
      throw Exception(passwordStrengthErr);
    }

    try {
      final res = await _supabase.auth.verifyOTP(
        email: cleanEmail,
        token: cleanToken,
        type: OtpType.recovery,
      );

      if (res.session == null) {
        throw Exception('El código de verificación no es válido o ya ha expirado.');
      }

      await _supabase.auth.updateUser(
        UserAttributes(password: cleanPassword),
      );

      AppLogger.info('Contraseña actualizada con éxito mediante código OTP para $cleanEmail', tag: 'AUTH_RESET_OTP');
    } on AuthException catch (e) {
      AppLogger.warning('Error al verificar OTP de recuperación: ${e.message}', tag: 'AUTH_RESET_OTP');
      if (e.message.toLowerCase().contains('expired') || e.message.toLowerCase().contains('invalid')) {
        throw Exception('El código de verificación es incorrecto o ha expirado.');
      }
      throw Exception(e.message);
    } catch (e, stackTrace) {
      AppLogger.error('Excepción al verificar OTP y actualizar contraseña', tag: 'AUTH_RESET_OTP', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Actualiza la contraseña del usuario actualmente autenticado (ej. durante flujo de recuperación por Deep Link).
  Future<void> updateUserPassword(String newPassword) async {
    final cleanPassword = newPassword.trim();
    final passwordStrengthErr = validatePasswordStrength(cleanPassword);
    if (passwordStrengthErr != null) {
      throw Exception(passwordStrengthErr);
    }

    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: cleanPassword),
      );
      AppLogger.info('Contraseña actualizada con éxito', tag: 'AUTH_UPDATE_PASSWORD');
    } on AuthException catch (e) {
      AppLogger.warning('Error al actualizar contraseña: ${e.message}', tag: 'AUTH_UPDATE_PASSWORD');
      throw Exception(e.message);
    } catch (e, stackTrace) {
      AppLogger.error('Excepción al actualizar contraseña', tag: 'AUTH_UPDATE_PASSWORD', error: e, stackTrace: stackTrace);
      rethrow;
    }
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
