import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/utils/app_logger.dart';

/// Servicio de configuración remota reactivo "Over-The-Air" (Zero-Rebuild).
/// Gestiona parámetros visuales, textos, reglas de negocio y feature flags
/// con sincronización instantánea vía Supabase Realtime y resiliencia offline.
class RemoteConfigService extends ChangeNotifier {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  static const String _prefsKeyConfigs = 'umbral_remote_config_cache';
  static const String _prefsKeyFlags = 'umbral_feature_flags_cache';

  final Map<String, dynamic> _configs = {};
  final Map<String, Map<String, dynamic>> _flags = {};
  RealtimeChannel? _realtimeChannel;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Inicializa el servicio: carga la caché local para arranque instantáneo,
  /// descarga los valores frescos desde Supabase y activa la suscripción Realtime.
  Future<void> initialize([SupabaseClient? client]) async {
    if (_isInitialized) return;

    // 1. Cargar caché local desde SharedPreferences (Modo Offline / Arranque Inmediato)
    await _loadFromLocalCache();

    // 2. Sincronizar con Supabase en segundo plano o asíncrono
    final supabase = client ?? SupabaseConfig.client;
    await syncWithRemote(supabase);

    // 3. Suscribirse a cambios en tiempo real (Supabase Realtime)
    _subscribeToRealtime(supabase);

    _isInitialized = true;
    notifyListeners();
  }

  /// Carga la copia persistida en disco para disponibilidad sin internet
  Future<void> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsRaw = prefs.getString(_prefsKeyConfigs);
      if (configsRaw != null && configsRaw.isNotEmpty) {
        final decoded = jsonDecode(configsRaw);
        if (decoded is Map<String, dynamic>) {
          _configs.addAll(decoded);
        }
      }

      final flagsRaw = prefs.getString(_prefsKeyFlags);
      if (flagsRaw != null && flagsRaw.isNotEmpty) {
        final decoded = jsonDecode(flagsRaw);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            if (entry.value is Map) {
              _flags[entry.key] = Map<String, dynamic>.from(entry.value as Map);
            }
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Error al leer caché local de remote config: $e', tag: 'OTA');
    }
  }

  /// Guarda en SharedPreferences el estado actual de las configuraciones y flags
  Future<void> _saveToLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyConfigs, jsonEncode(_configs));
      await prefs.setString(_prefsKeyFlags, jsonEncode(_flags));
    } catch (e) {
      AppLogger.warning('Error al persistir caché local de remote config: $e', tag: 'OTA');
    }
  }

  /// Descarga el bundle completo desde Supabase utilizando el RPC optimizado
  Future<void> syncWithRemote([SupabaseClient? client]) async {
    final supabase = client ?? SupabaseConfig.client;
    try {
      // Intento 1: RPC consolidado en un solo viaje HTTP
      final response = await supabase.rpc('obtener_bundle_configuracion_remota');
      if (response is Map) {
        final configsMap = response['configs'];
        if (configsMap is Map) {
          configsMap.forEach((k, v) {
            if (v is Map && v.containsKey('value')) {
              _configs[k.toString()] = v['value'];
            }
          });
        }

        final flagsMap = response['flags'];
        if (flagsMap is Map) {
          flagsMap.forEach((k, v) {
            if (v is Map) {
              _flags[k.toString()] = Map<String, dynamic>.from(v);
            }
          });
        }

        await _saveToLocalCache();
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.info('RPC bundle no disponible o error, intentando consulta directa: $e', tag: 'OTA');
    }

    // Intento 2: Consulta directa a tablas con tolerancia a fallas
    try {
      final configRows = await supabase.from('app_remote_config').select('key, value');
      for (final row in (configRows as List)) {
        final k = row['key']?.toString();
        if (k != null) {
          _configs[k] = row['value'];
        }
      }

      final flagRows = await supabase.from('feature_flags').select();
      for (final row in (flagRows as List)) {
        final k = row['flag_key']?.toString();
        if (k != null) {
          _flags[k] = Map<String, dynamic>.from(row as Map);
        }
      }

      await _saveToLocalCache();
      notifyListeners();
    } catch (err) {
      AppLogger.warning('No se pudo sincronizar configuración remota (usando caché offline): $err', tag: 'OTA');
    }
  }

  /// Escucha eventos en tiempo real mediante Supabase Realtime
  void _subscribeToRealtime(SupabaseClient supabase) {
    try {
      _realtimeChannel?.unsubscribe();

      _realtimeChannel = supabase.channel('umbral_remote_config_channel')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_remote_config',
          callback: (payload) {
            final newRow = payload.newRecord;
            final k = newRow['key']?.toString();
            if (k != null) {
              if (payload.eventType == PostgresChangeEvent.delete) {
                _configs.remove(k);
              } else {
                _configs[k] = newRow['value'];
              }
              _saveToLocalCache();
              notifyListeners();
              AppLogger.info('⚡ Parámetro remoto actualizado en vivo: $k', tag: 'OTA');
            }
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'feature_flags',
          callback: (payload) {
            final newRow = payload.newRecord;
            final k = newRow['flag_key']?.toString();
            if (k != null) {
              if (payload.eventType == PostgresChangeEvent.delete) {
                _flags.remove(k);
              } else {
                _flags[k] = Map<String, dynamic>.from(newRow);
              }
              _saveToLocalCache();
              notifyListeners();
              AppLogger.info('⚡ Feature flag actualizado en vivo: $k', tag: 'OTA');
            }
          },
        )
        ..subscribe();
    } catch (e) {
      AppLogger.warning('Error al inicializar suscripción Realtime para OTA: $e', tag: 'OTA');
    }
  }

  // ===========================================================================
  // HELPERS TIPADOS PARA CONSUMO LIMPIO EN WIDGETS Y REGLAS
  // ===========================================================================

  /// Determina si un módulo o característica está habilitada, opcionalmente
  /// evaluando si el rol del usuario conectado tiene permiso sobre el flag.
  bool isFeatureEnabled(String flagKey, {String? userRole}) {
    final flag = _flags[flagKey];
    if (flag == null) {
      // Si el flag no está en remoto, por defecto es true si no se especifica lo contrario
      return true;
    }

    final isEnabled = flag['is_enabled'] == true;
    if (!isEnabled) return false;

    // Validación de roles de destino
    if (userRole != null && flag.containsKey('target_roles')) {
      final rolesRaw = flag['target_roles'];
      if (rolesRaw is List) {
        final roles = rolesRaw.map((e) => e.toString().toLowerCase().trim()).toList();
        if (roles.contains('todos') || roles.contains('all')) {
          return true;
        }
        final normalizedUserRole = userRole.toLowerCase().trim().replaceFirst('-', '_');
        return roles.contains(normalizedUserRole);
      }
    }

    return true;
  }

  /// Obtiene un color configurado remotamente en formato hexadecimal (ej. `#E0115F`),
  /// retornando el fallback de diseño si el valor es nulo o inválido.
  Color getRemoteColor(String key, Color fallback) {
    final val = _configs[key];
    if (val is String && val.trim().isNotEmpty) {
      try {
        String clean = val.replaceAll('#', '').trim();
        if (clean.length == 6) {
          clean = 'FF$clean';
        }
        if (clean.length == 8) {
          return Color(int.parse(clean, radix: 16));
        }
      } catch (_) {}
    }
    return fallback;
  }

  /// Obtiene un valor tipado genérico con fallback
  T getConfigValue<T>(String key, T fallback) {
    final val = _configs[key];
    if (val == null) return fallback;

    if (val is T) return val;

    // Conversiones numéricas seguras
    if (T == double && val is num) {
      return val.toDouble() as T;
    }
    if (T == int && val is num) {
      return val.toInt() as T;
    }
    if (T == String) {
      return val.toString() as T;
    }
    if (T == bool) {
      if (val is bool) return val as T;
      if (val is String) {
        return (val.toLowerCase() == 'true' || val == '1') as T;
      }
      if (val is num) return (val == 1) as T;
    }

    return fallback;
  }

  String getRemoteString(String key, String fallback) =>
      getConfigValue<String>(key, fallback);

  int getRemoteInt(String key, int fallback) =>
      getConfigValue<int>(key, fallback);

  double getRemoteDouble(String key, double fallback) =>
      getConfigValue<double>(key, fallback);

  bool getRemoteBool(String key, bool fallback) =>
      getConfigValue<bool>(key, fallback);

  /// Método administrativo para que el Super Admin actualice un valor al vuelo
  /// Enviando el valor Dart tipado directamente a la columna JSONB de Supabase
  Future<bool> setConfigValue(String key, dynamic value) async {
    try {
      await SupabaseConfig.client
          .from('app_remote_config')
          .update({'value': value})
          .eq('key', key);
      _configs[key] = value;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Error al actualizar parámetro remoto $key: $e', tag: 'OTA');
      return false;
    }
  }

  /// Método administrativo para alternar un feature flag en vivo
  Future<bool> toggleFeatureFlag(String flagKey, bool isEnabled) async {
    try {
      await SupabaseConfig.client
          .from('feature_flags')
          .update({'is_enabled': isEnabled})
          .eq('flag_key', flagKey);
      if (_flags.containsKey(flagKey)) {
        _flags[flagKey]!['is_enabled'] = isEnabled;
      } else {
        _flags[flagKey] = {'is_enabled': isEnabled, 'target_roles': ['todos']};
      }
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Error al alternar feature flag $flagKey: $e', tag: 'OTA');
      return false;
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
