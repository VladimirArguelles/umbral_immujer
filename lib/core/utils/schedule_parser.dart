/// Representa el rango de tiempo de una clase en minutos desde las 00:00 (0 a 1439).
class ScheduleTimeRange {
  final int startMinutes;
  final int endMinutes;

  const ScheduleTimeRange({
    required this.startMinutes,
    required this.endMinutes,
  });

  bool containsMinutes(int minutes) => minutes >= startMinutes && minutes <= endMinutes;
}

/// Estado temporal de un curso respecto a la hora y día de consulta en tiempo real.
enum CourseTimeStatus {
  activeNow,
  endedToday,
  upcomingToday,
  notToday,
}

/// Analizador y evaluador de horarios de cursos en lenguaje natural y formatos estándar.
class ScheduleParser {
  static const Map<int, List<String>> _diasMap = {
    1: ['lunes', 'lun'],
    2: ['martes', 'mar'],
    3: ['miercoles', 'miércoles', 'mie', 'mié'],
    4: ['jueves', 'jue'],
    5: ['viernes', 'vie'],
    6: ['sabado', 'sábado', 'sab', 'sáb'],
    7: ['domingo', 'dom'],
  };

  /// Determina si el horario incluye el día de la fecha de referencia (por defecto hoy).
  static bool isCourseActiveToday(String? horario, {DateTime? now}) {
    if (horario == null || horario.trim().isEmpty) return false;
    final current = now ?? DateTime.now();
    final hLower = horario.toLowerCase();

    // Lunes a Viernes (días 1 al 5)
    if ((hLower.contains('lunes a viernes') || hLower.contains('lun a vie')) &&
        current.weekday >= 1 &&
        current.weekday <= 5) {
      return true;
    }

    // Lunes a Sábado (días 1 al 6)
    if ((hLower.contains('lunes a sábado') || hLower.contains('lunes a sabado')) &&
        current.weekday >= 1 &&
        current.weekday <= 6) {
      return true;
    }

    // Fines de semana (Sábado y Domingo)
    if (hLower.contains('fin de semana') || hLower.contains('fines de semana')) {
      if (current.weekday == 6 || current.weekday == 7) return true;
    }

    final todayTokens = _diasMap[current.weekday] ?? [];
    return todayTokens.any((t) {
      final pattern = RegExp('(^|[\\s,;/-])${RegExp.escape(t)}([\\s,;/-]|\$)', caseSensitive: false);
      return pattern.hasMatch(hLower) || hLower.contains(t);
    });
  }

  /// Extrae el rango de inicio y fin en minutos de un horario en texto.
  /// Ejemplos: "8:00 a 12:00 pm", "1:00 a 5:00pm", "8:00 AM - 12:00 PM", "13:00 - 17:00"
  static ScheduleTimeRange? parseTimeRange(String? horario) {
    if (horario == null || horario.trim().isEmpty) return null;

    final regex = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?',
      caseSensitive: false,
    );

    final matches = regex.allMatches(horario).toList();
    if (matches.length < 2) return null;

    final match1 = matches[0];
    final match2 = matches[1];

    final hour1 = int.tryParse(match1.group(1) ?? '') ?? 0;
    final min1 = int.tryParse(match1.group(2) ?? '0') ?? 0;
    final period1 = match1.group(3);

    final hour2 = int.tryParse(match2.group(1) ?? '') ?? 0;
    final min2 = int.tryParse(match2.group(2) ?? '0') ?? 0;
    final period2 = match2.group(3);

    final startMinutes = _toMinutes(
      hour: hour1,
      minute: min1,
      period: period1,
      isStart: true,
      otherHour: hour2,
      otherPeriod: period2,
    );

    final endMinutes = _toMinutes(
      hour: hour2,
      minute: min2,
      period: period2,
      isStart: false,
      otherHour: hour1,
      otherPeriod: period1,
    );

    if (startMinutes >= endMinutes) return null;

    return ScheduleTimeRange(startMinutes: startMinutes, endMinutes: endMinutes);
  }

  /// Convierte una hora a minutos del día (0 a 1439) con inferencia inteligente de AM/PM.
  static int _toMinutes({
    required int hour,
    required int minute,
    String? period,
    required bool isStart,
    int? otherHour,
    String? otherPeriod,
  }) {
    final cleanPeriod = period?.toLowerCase().replaceAll('.', '');
    final cleanOtherPeriod = otherPeriod?.toLowerCase().replaceAll('.', '');

    int h = hour;
    final int m = minute.clamp(0, 59);

    if (cleanPeriod == 'pm') {
      if (h < 12) h += 12;
    } else if (cleanPeriod == 'am') {
      if (h == 12) h = 0;
    } else {
      // Sin indicador am/pm: inferir por el contexto educativo de IMMUJER
      if (h >= 13) {
        // Formato 24h explícito
      } else if (cleanOtherPeriod == 'am') {
        if (h == 12) h = 0;
      } else if (cleanOtherPeriod == 'pm') {
        if (isStart) {
          // Si el inicio es de 1 a 6 y el fin es PM (ej. 1:00 a 5:00 pm), es turno tarde (13:00)
          if (h >= 1 && h <= 6) {
            h += 12;
          }
          // Si el inicio es de 7 a 11 (ej. 8:00 a 12:00 pm o 8:00 a 1:00 pm), es mañana
        } else {
          if (h < 12) h += 12;
        }
      } else {
        // Ninguno tiene am/pm: horario diurno estándar (1-6 es tarde, 7-12 es mañana)
        if (h >= 1 && h <= 6) {
          h += 12;
        }
      }
    }

    return (h.clamp(0, 23) * 60) + m;
  }

  /// Retorna el estado temporal preciso del curso en el momento actual.
  static CourseTimeStatus getCourseStatus(String? horario, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (!isCourseActiveToday(horario, now: current)) {
      return CourseTimeStatus.notToday;
    }

    final range = parseTimeRange(horario);
    if (range == null) {
      // Si tiene día programado para hoy pero sin formato de hora detectable,
      // se considera activo durante la jornada de hoy
      return CourseTimeStatus.activeNow;
    }

    final currentMinutes = current.hour * 60 + current.minute;
    if (currentMinutes < range.startMinutes) {
      return CourseTimeStatus.upcomingToday;
    } else if (currentMinutes > range.endMinutes) {
      return CourseTimeStatus.endedToday;
    } else {
      return CourseTimeStatus.activeNow;
    }
  }

  /// Indica si el curso se encuentra en clase activa en este momento exacto.
  static bool isCourseActiveNow(String? horario, {DateTime? now}) {
    return getCourseStatus(horario, now: now) == CourseTimeStatus.activeNow;
  }
}
