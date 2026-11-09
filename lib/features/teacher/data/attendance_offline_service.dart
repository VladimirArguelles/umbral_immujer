import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/teacher_models.dart';

/// Servicio de persistencia local y sincronización en segundo plano de asistencias.
/// Utiliza Hive para almacenar alumnos y asistencias cuando no hay señal de red,
/// y sincroniza con Supabase tan pronto se recupera la conectividad.
class AttendanceOfflineService {
  AttendanceOfflineService._();
  static final AttendanceOfflineService instance = AttendanceOfflineService._();

  static const String _boxCache = 'umbral_attendance_cache';
  static const String _boxSyncQueue = 'umbral_attendance_sync_queue';

  Box? _cacheBox;
  Box? _queueBox;
  Timer? _autoSyncTimer;

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  /// Inicializa los boxes locales de Hive y activa el temporizador periódico de sincronización.
  Future<void> initialize() async {
    try {
      _cacheBox = await Hive.openBox(_boxCache);
      _queueBox = await Hive.openBox(_boxSyncQueue);
      _updatePendingCount();

      // Temporizador en segundo plano que intenta sincronizar cada 40 segundos si hay pendientes
      _autoSyncTimer?.cancel();
      _autoSyncTimer = Timer.periodic(const Duration(seconds: 40), (_) {
        if (pendingCountNotifier.value > 0) {
          syncPendingQueue(Supabase.instance.client);
        }
      });
    } catch (e) {
      debugPrint('[AttendanceOfflineService] Error al inicializar Hive: $e');
    }
  }

  void _updatePendingCount() {
    pendingCountNotifier.value = _queueBox?.length ?? 0;
  }

  /// Guarda en caché local la lista de alumnos de un curso.
  Future<void> cacheStudents(String courseId, List<StudentAttendanceItem> students) async {
    if (_cacheBox == null) return;
    try {
      final data = students.map((s) => s.toJson()).toList();
      await _cacheBox!.put('students_$courseId', data);
    } catch (e) {
      debugPrint('[AttendanceOfflineService] Error al cachear alumnos: $e');
    }
  }

  /// Recupera los alumnos cacheados de un curso si no hay internet.
  List<StudentAttendanceItem>? getCachedStudents(String courseId) {
    if (_cacheBox == null) return null;
    try {
      final raw = _cacheBox!.get('students_$courseId');
      if (raw is List) {
        return raw.map((item) {
          return StudentAttendanceItem.fromJson(Map<dynamic, dynamic>.from(item as Map));
        }).toList();
      }
    } catch (e) {
      debugPrint('[AttendanceOfflineService] Error al leer alumnos cacheados: $e');
    }
    return null;
  }

  /// Guarda en caché la asistencia de un curso en una fecha determinada.
  Future<void> cacheAttendanceRecord({
    required String courseId,
    required String date,
    required List<StudentAttendanceItem> students,
  }) async {
    if (_cacheBox == null) return;
    try {
      final key = 'attendance_${courseId}_$date';
      final data = students.map((s) => s.toJson()).toList();
      await _cacheBox!.put(key, data);
    } catch (e) {
      debugPrint('[AttendanceOfflineService] Error al cachear registro de asistencia: $e');
    }
  }

  /// Encola una lista de asistencia para ser sincronizada con Supabase cuando haya internet.
  Future<void> enqueueForSync({
    required String courseId,
    required String date,
    required List<StudentAttendanceItem> students,
    String? recordedBy,
  }) async {
    // Primero respaldar en el caché local inmediato
    await cacheAttendanceRecord(courseId: courseId, date: date, students: students);

    if (_queueBox == null) return;
    try {
      final queueKey = '${courseId}_$date';
      final payload = {
        'curso_id': courseId,
        'fecha': date,
        'recorded_by': recordedBy,
        'records': students.map((a) {
          return {
            'curso_id': courseId,
            'alumno_id': a.alumnoId,
            'fecha': date,
            'estado': a.estadoAsistencia,
            'recorded_by': recordedBy,
          };
        }).toList(),
        'queued_at': DateTime.now().toIso8601String(),
      };

      await _queueBox!.put(queueKey, payload);
      _updatePendingCount();
    } catch (e) {
      debugPrint('[AttendanceOfflineService] Error al encolar para sincronización: $e');
    }
  }

  /// Elimina de la cola una asistencia ya sincronizada
  Future<void> removePending(String courseId, String date) async {
    if (_queueBox == null) return;
    final queueKey = '${courseId}_$date';
    await _queueBox!.delete(queueKey);
    _updatePendingCount();
  }

  /// Sincroniza todas las asistencias encoladas con Supabase en segundo plano.
  Future<bool> syncPendingQueue(SupabaseClient supabase) async {
    if (_queueBox == null || _queueBox!.isEmpty) {
      _updatePendingCount();
      return true;
    }

    if (isSyncingNotifier.value) return false;

    isSyncingNotifier.value = true;
    int syncedCount = 0;

    try {
      final keys = List.from(_queueBox!.keys);
      for (final key in keys) {
        final itemRaw = _queueBox!.get(key);
        if (itemRaw is! Map) continue;

        final item = Map<String, dynamic>.from(itemRaw);
        final recordsRaw = item['records'];
        if (recordsRaw is! List) continue;

        final records = recordsRaw.map((r) => Map<String, dynamic>.from(r as Map)).toList();

        // Intento de upsert en Supabase
        await supabase
            .from('asistencia')
            .upsert(records, onConflict: 'curso_id, alumno_id, fecha');

        // Si tuvo éxito, eliminar de la cola de pendientes
        await _queueBox!.delete(key);
        syncedCount++;
      }
      debugPrint('[AttendanceOfflineService] Sincronización exitosa: $syncedCount registros enviados.');
      return true;
    } catch (e) {
      debugPrint('[AttendanceOfflineService] Sincronización en segundo plano pospuesta (sin señal): $e');
      return false;
    } finally {
      _updatePendingCount();
      isSyncingNotifier.value = false;
    }
  }

  void dispose() {
    _autoSyncTimer?.cancel();
  }
}
