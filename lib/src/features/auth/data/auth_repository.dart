import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Valida si el alumno existe en la tabla Alumnos Y si posee inscripción activa
  Future<AlumnoValidationResult> validateAlumnoEligibility({
    required String cedula,
    String? email,
  }) async {
    final cleanCedula = cedula.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    final numericCedula = cedula.trim().replaceAll(RegExp(r'[^0-9]'), '');

    // 1. Buscar en alumnos por cédula (numérica limpia o alfanumérica)
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

    if (alumnoData == null) {
      return AlumnoValidationResult(
        foundInAlumnos: false,
        hasActiveInscripcion: false,
        errorMessage:
            'Acceso denegado: El documento $cedula no se encuentra registrado en el padrón de alumnos de IMMUJER.',
      );
    }

    final alumnoId = alumnoData['id'] as String;
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

    // 2. Validar si está inscrito en al menos un curso
    final List<dynamic> inscripciones = await _supabase
        .from('inscripciones')
        .select('id, curso_id, estado')
        .eq('alumno_id', alumnoId)
        .filter('deleted_at', 'is', null);

    if (inscripciones.isEmpty) {
      return AlumnoValidationResult(
        foundInAlumnos: true,
        hasActiveInscripcion: false,
        data: alumnoData,
        errorMessage: 'Acceso denegado: El alumno figura en el padrón, pero no cuenta con una inscripción activa en ningún curso. Debe formalizar su inscripción primero.',
      );
    }

    return AlumnoValidationResult(
      foundInAlumnos: true,
      hasActiveInscripcion: true,
      data: alumnoData,
    );
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

  /// Valida si la cédula o correo existe en el padrón de Profesores autorizados
  Future<Map<String, dynamic>?> checkProfesorPreRegistered({
    required String cedula,
    String? email,
  }) async {
    final cleanCedula = cedula.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    final numericCedula = cedula.trim().replaceAll(RegExp(r'[^0-9]'), '');

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

  /// Registro de usuario con validación estricta de pertenencia al padrón
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
          alumnoCheck.errorMessage ?? 'Acceso denegado: Solo alumnos registrados e inscritos en IMMUJER pueden registrarse.',
        );
      }
      rosterId = alumnoCheck.data?['id'];
    } else if (role == UserRole.profesor) {
      final profesorData = await checkProfesorPreRegistered(
        cedula: cleanCedula,
        email: email,
      );
      if (profesorData == null) {
        throw Exception(
          'Acceso denegado: La cédula $cedula no figura en el registro de profesores autorizados de IMMUJER.',
        );
      }
      rosterId = profesorData['id'];
    }

    // Registro en Supabase Auth
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

    // El ID de Auth es la clave única del perfil, creado por el trigger de Auth.
    await _supabase.from('perfiles').upsert({
      'id': user.id,
      'nombre_completo': nombreCompleto.trim(),
      'cedula': cleanCedula,
      'telefono': telefono.trim(),
      'correo': email.trim(),
      'rol': role.toDbString(),
    }, onConflict: 'id');

    // Vincular user_id en la tabla respectiva
    if (role == UserRole.alumno) {
      if (rosterId is! String) {
        throw StateError('El padrón de alumnos no devolvió un ID válido.');
      }
      final linked = await _supabase
          .from('alumnos')
          .update({'user_id': user.id})
          .eq('id', rosterId)
          .isFilter('user_id', null)
          .select('id')
          .maybeSingle();
      if (linked == null) {
        throw StateError(
          'No se pudo vincular la cuenta con el padrón de alumnos.',
        );
      }
    } else if (role == UserRole.profesor) {
      if (rosterId is! String) {
        throw StateError('El padrón de profesores no devolvió un ID válido.');
      }
      final linked = await _supabase
          .from('profesores')
          .update({'user_id': user.id})
          .eq('id', rosterId)
          .isFilter('user_id', null)
          .select('id')
          .maybeSingle();
      if (linked == null) {
        throw StateError(
          'No se pudo vincular la cuenta con el padrón de profesores.',
        );
      }
    }

    return UserProfile(
      id: user.id,
      email: email,
      fullName: nombreCompleto,
      cedula: cleanCedula,
      telefono: telefono,
      role: role,
    );
  }

  /// Inicio de sesión estándar
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
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

    return profile;
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
    } catch (_) {
      // Si la consulta falla temporalmente, se procede con la metadata del usuario de Auth
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
    await _supabase.auth.signOut();
  }
}
