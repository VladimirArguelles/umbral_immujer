import 'package:flutter_test/flutter_test.dart';
import 'package:umbral_immujer/core/utils/schedule_parser.dart';

void main() {
  group('ScheduleParser Unit Tests', () {
    // Sábado 7 de Noviembre a las 3:58 PM (15:58)
    final sabadoTarde = DateTime(2026, 11, 7, 15, 58);

    test('Identifica correctamente el curso activo en tiempo real a las 3:58 PM', () {
      // Curso de 1:00 a 5:00 PM debe estar activo a las 3:58 PM
      const cursoCocina = 'Sábado 1:00 a 5:00pm';
      expect(
        ScheduleParser.isCourseActiveNow(cursoCocina, now: sabadoTarde),
        isTrue,
      );
      expect(
        ScheduleParser.getCourseStatus(cursoCocina, now: sabadoTarde),
        equals(CourseTimeStatus.activeNow),
      );
    });

    test('Identifica cursos finalizados antes de las 3:58 PM', () {
      // Curso de 8:00 a 12:00 PM ya finalizó
      const cursoTortas = 'Sábado 8:00 a 12:00 pm';
      expect(
        ScheduleParser.isCourseActiveNow(cursoTortas, now: sabadoTarde),
        isFalse,
      );
      expect(
        ScheduleParser.getCourseStatus(cursoTortas, now: sabadoTarde),
        equals(CourseTimeStatus.endedToday),
      );

      // Curso de 8:00 a 10:00 AM ya finalizó
      const cursoBartender = 'Sábado 8:00 a 10:00am';
      expect(
        ScheduleParser.isCourseActiveNow(cursoBartender, now: sabadoTarde),
        isFalse,
      );
      expect(
        ScheduleParser.getCourseStatus(cursoBartender, now: sabadoTarde),
        equals(CourseTimeStatus.endedToday),
      );
    });

    test('Identifica cursos programados para más tarde en el mismo día', () {
      // Sábado en la mañana a las 9:00 AM
      final sabadoManana = DateTime(2026, 11, 7, 9, 0);
      const cursoTarde = 'Sábado 1:00 a 5:00pm';

      expect(
        ScheduleParser.isCourseActiveNow(cursoTarde, now: sabadoManana),
        isFalse,
      );
      expect(
        ScheduleParser.getCourseStatus(cursoTarde, now: sabadoManana),
        equals(CourseTimeStatus.upcomingToday),
      );
    });

    test('Identifica cursos de otros días como notToday', () {
      // El sábado, cursos de Lunes o Viernes deben ser notToday
      const cursoLunes = 'Lunes 8:00 AM - 12:00 PM';
      expect(
        ScheduleParser.isCourseActiveToday(cursoLunes, now: sabadoTarde),
        isFalse,
      );
      expect(
        ScheduleParser.getCourseStatus(cursoLunes, now: sabadoTarde),
        equals(CourseTimeStatus.notToday),
      );
    });

    test('Maneja correctamente rangos multiodía como Lunes a Viernes', () {
      // Miércoles a las 3:00 PM (15:00)
      final miercolesTarde = DateTime(2026, 11, 4, 15, 0);
      const cursoLv = 'Lunes a Viernes 2:00 PM - 5:00 PM';

      expect(
        ScheduleParser.isCourseActiveNow(cursoLv, now: miercolesTarde),
        isTrue,
      );
      expect(
        ScheduleParser.getCourseStatus(cursoLv, now: miercolesTarde),
        equals(CourseTimeStatus.activeNow),
      );

      // El sábado este curso no debe estar activo
      expect(
        ScheduleParser.isCourseActiveToday(cursoLv, now: sabadoTarde),
        isFalse,
      );
    });

    test('Parsea minutos con precisión de minutos', () {
      final range = ScheduleParser.parseTimeRange('Sábado 8:30 a 11:45 am');
      expect(range, isNotNull);
      expect(range!.startMinutes, equals(8 * 60 + 30)); // 510
      expect(range.endMinutes, equals(11 * 60 + 45));   // 705
    });
  });
}
