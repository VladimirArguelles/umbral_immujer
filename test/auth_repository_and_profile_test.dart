import 'package:flutter_test/flutter_test.dart';
import 'package:umbral_immujer/src/features/auth/data/auth_repository.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

void main() {
  group('UserRole & UserProfile Unit Tests', () {
    test('UserRole.fromString parses valid and canonical database values correctly', () {
      expect(UserRole.fromString('super_admin'), UserRole.superAdmin);
      expect(UserRole.fromString('superadmin'), UserRole.superAdmin);
      expect(UserRole.fromString('coordinador'), UserRole.coordinador);
      expect(UserRole.fromString('coordinator'), UserRole.coordinador);
      expect(UserRole.fromString('profesor'), UserRole.profesor);
      expect(UserRole.fromString('teacher'), UserRole.profesor);
      expect(UserRole.fromString('alumno'), UserRole.alumno);
      expect(UserRole.fromString('student'), UserRole.alumno);
      expect(UserRole.fromString('unknown_role'), UserRole.alumno);
      expect(UserRole.fromString(null), UserRole.alumno);
    });

    test('UserRole.toDbString produces correct postgres/supabase values', () {
      expect(UserRole.superAdmin.toDbString(), 'super_admin');
      expect(UserRole.coordinador.toDbString(), 'coordinador');
      expect(UserRole.profesor.toDbString(), 'profesor');
      expect(UserRole.alumno.toDbString(), 'alumno');
    });

    test('UserProfile parses from Supabase JSON properly', () {
      final json = {
        'id': 'usr-123-uuid',
        'email': 'superadmin@immujer.gob.ve',
        'correo': 'superadmin@immujer.gob.ve',
        'nombre_completo': 'Directora General',
        'cedula': 'V-12345678',
        'telefono': '04121234567',
        'rol': 'super_admin',
        'created_at': '2026-01-01T12:00:00Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'usr-123-uuid');
      expect(profile.email, 'superadmin@immujer.gob.ve');
      expect(profile.fullName, 'Directora General');
      expect(profile.cedula, 'V-12345678');
      expect(profile.telefono, '04121234567');
      expect(profile.role, UserRole.superAdmin);
      expect(profile.rol, UserRole.superAdmin);
      expect(profile.isSuperAdmin, isTrue);
    });

    test('UserProfile handles missing optional fields gracefully', () {
      final json = {
        'id': 'usr-456-uuid',
        'correo': 'alumno@test.com',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'usr-456-uuid');
      expect(profile.email, 'alumno@test.com');
      expect(profile.fullName, 'Usuario');
      expect(profile.role, UserRole.alumno);
      expect(profile.isSuperAdmin, isFalse);
    });
  });

  group('AlumnoValidationResult Unit Tests', () {
    test('isValid returns true only when found, active and not linked', () {
      const valid = AlumnoValidationResult(
        foundInAlumnos: true,
        hasActiveInscripcion: true,
        isLinked: false,
      );
      expect(valid.isValid, isTrue);

      const notFound = AlumnoValidationResult(
        foundInAlumnos: false,
        hasActiveInscripcion: true,
        isLinked: false,
      );
      expect(notFound.isValid, isFalse);

      const noInscripcion = AlumnoValidationResult(
        foundInAlumnos: true,
        hasActiveInscripcion: false,
        isLinked: false,
      );
      expect(noInscripcion.isValid, isFalse);

      const alreadyLinked = AlumnoValidationResult(
        foundInAlumnos: true,
        hasActiveInscripcion: true,
        isLinked: true,
      );
      expect(alreadyLinked.isValid, isFalse);
    });
  });
}
