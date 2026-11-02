import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Obtener perfil actual refrescado desde la base de datos
  Future<UserProfile?> getCurrentProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final res = await _supabase
          .from('perfiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (res != null) {
        return UserProfile.fromJson(res);
      }
    } catch (_) {}

    return null;
  }

  /// Subir imagen de perfil a Supabase Storage (bucket: avatars)
  Future<String?> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    try {
      final safeExt = fileExtension.replaceAll('.', '').toLowerCase();
      final ext = safeExt.isEmpty ? 'jpg' : safeExt;
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'profiles/$fileName';

      await _supabase.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            ),
          );

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      return null;
    }
  }

  /// Actualizar datos del perfil en tablas de Supabase y notificar a roles
  Future<UserProfile> updateProfile({
    required String userId,
    required String fullName,
    required String email,
    required String telefono,
    String? avatarUrl,
    required UserRole role,
    String? cedula,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim();
    final cleanPhone = telefono.trim();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1. Actualización en tabla perfiles
    final profileUpdates = <String, dynamic>{
      'nombre_completo': cleanName,
      'correo': cleanEmail,
      'email': cleanEmail,
      'telefono': cleanPhone,
      'updated_at': nowIso,
    };
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      profileUpdates['avatar_url'] = avatarUrl;
    }
    if (cedula != null && cedula.isNotEmpty) {
      profileUpdates['cedula'] = cedula.trim();
    }

    await _supabase.from('perfiles').update(profileUpdates).eq('id', userId);

    // 2. Sincronización en tablas secundarias según rol
    try {
      if (role == UserRole.alumno) {
        final alumnoUpdates = <String, dynamic>{
          'nombre_completo': cleanName,
          'correo': cleanEmail,
          'telefono': cleanPhone,
          'updated_at': nowIso,
        };
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          alumnoUpdates['avatar_url'] = avatarUrl;
        }
        await _supabase
            .from('alumnos')
            .update(alumnoUpdates)
            .eq('user_id', userId);
      } else if (role == UserRole.profesor) {
        final profUpdates = <String, dynamic>{
          'nombre_completo': cleanName,
          'correo': cleanEmail,
          'telefono': cleanPhone,
          'updated_at': nowIso,
        };
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          profUpdates['avatar_url'] = avatarUrl;
        }
        await _supabase
            .from('profesores')
            .update(profUpdates)
            .eq('user_id', userId);
      }
    } catch (_) {}

    // 3. Actualizar correo en auth.users si cambió
    final currentAuthUser = _supabase.auth.currentUser;
    if (currentAuthUser != null &&
        currentAuthUser.email != null &&
        currentAuthUser.email!.toLowerCase() != cleanEmail.toLowerCase()) {
      try {
        await _supabase.auth.updateUser(
          UserAttributes(email: cleanEmail),
        );
      } catch (_) {}
    }

    // 4. Notificar a Profesores, Coordinadores y Super Admin
    try {
      await _supabase.rpc('notificar_cambio_perfil', params: {
        'p_usuario_id': userId,
        'p_nombre': cleanName,
        'p_correo': cleanEmail,
        'p_telefono': cleanPhone,
        'p_rol': role.toDbString(),
      });
    } catch (_) {
      // Fallback: Inserción directa en tabla notificaciones
      for (final dest in ['coordinador', 'profesor', 'super_admin']) {
        try {
          await _supabase.from('notificaciones').insert({
            'usuario_origen_id': userId,
            'rol_destino': dest,
            'titulo': 'Perfil Actualizado: $cleanName',
            'mensaje':
                'El usuario $cleanName (${role.displayName}) ha actualizado sus datos personales (Correo: $cleanEmail, Teléfono: $cleanPhone).',
            'tipo': 'perfil_actualizado',
            'datos': {
              'usuario_id': userId,
              'nombre': cleanName,
              'correo': cleanEmail,
              'telefono': cleanPhone,
              'rol': role.toDbString(),
              'avatar_url': avatarUrl,
            },
          });
        } catch (_) {}
      }
    }

    return UserProfile(
      id: userId,
      email: cleanEmail,
      fullName: cleanName,
      cedula: cedula,
      telefono: cleanPhone,
      role: role,
      avatarUrl: avatarUrl,
    );
  }

  /// Cierre de sesión de Supabase
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
