import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import '../domain/printer_models.dart';
import 'strategies/bluetooth_printer_strategy.dart';
import 'strategies/network_printer_strategy.dart';
import 'strategies/system_printer_strategy.dart';

class PrinterRepository {
  final SupabaseClient _supabase;
  static const _spKey = 'umbral_configuracion_impresora';

  PrinterRepository([SupabaseClient? client])
      : _supabase = client ?? SupabaseConfig.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Obtiene la configuración de impresora guardada (localmente o en Supabase)
  Future<ConfiguracionImpresora?> getConfiguracionImpresora() async {
    // 1. Intentar leer de SharedPreferences para acceso instantáneo
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_spKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final map = jsonDecode(cachedJson) as Map<String, dynamic>;
        return ConfiguracionImpresora.fromMap(map);
      }
    } catch (_) {}

    // 2. Si no hay cache local, consultar Supabase
    final uid = currentUserId;
    if (uid != null) {
      try {
        final row = await _supabase
            .from('configuraciones_impresora')
            .select()
            .eq('user_id', uid)
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (row != null) {
          final config = ConfiguracionImpresora.fromMap(row);
          // Actualizar cache local
          await _guardarCacheLocal(config);
          return config;
        }
      } catch (_) {}
    }

    return null;
  }

  /// Guarda la configuración de impresora tanto localmente como en Supabase
  Future<void> guardarConfiguracionImpresora(ConfiguracionImpresora config) async {
    // 1. Guardar en SharedPreferences
    await _guardarCacheLocal(config);

    // 2. Persistir en Supabase
    final uid = currentUserId ?? config.userId;
    if (uid != null) {
      try {
        final payload = config.toMap();
        payload['user_id'] = uid;

        // Upsert por user_id
        final existing = await _supabase
            .from('configuraciones_impresora')
            .select('id')
            .eq('user_id', uid)
            .limit(1)
            .maybeSingle();

        if (existing != null) {
          await _supabase
              .from('configuraciones_impresora')
              .update(payload)
              .eq('id', existing['id']);
        } else {
          await _supabase.from('configuraciones_impresora').insert(payload);
        }
      } catch (_) {
        // La configuración queda segura en SharedPreferences local si la tabla aún no se ha migrado
      }
    }
  }

  Future<void> _guardarCacheLocal(ConfiguracionImpresora config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_spKey, jsonEncode(config.toMap()));
    } catch (_) {}
  }

  /// Dispatcher Universal de Impresión (Patrón Strategy / Dispatcher)
  Future<bool> enviarAImprimirUniversal(
    TicketData datos, {
    ConfiguracionImpresora? customConfig,
  }) async {
    final config = customConfig ?? await getConfiguracionImpresora();

    // Si no hay configuración registrada, usar estrategia del Sistema por defecto
    if (config == null) {
      final defaultSystemConfig = ConfiguracionImpresora(
        id: 'default',
        tipoConexion: TipoConexionImpresora.sistema,
        identificador: 'default',
        nombreImpresora: 'Impresora Predeterminada del Sistema',
      );
      return SystemPrinterStrategy().printTicket(datos, defaultSystemConfig);
    }

    // Resolver estrategia correspondiente
    final PrinterStrategy strategy = switch (config.tipoConexion) {
      TipoConexionImpresora.bluetooth => BluetoothPrinterStrategy(),
      TipoConexionImpresora.red => NetworkPrinterStrategy(),
      TipoConexionImpresora.sistema => SystemPrinterStrategy(),
    };

    return await strategy.printTicket(datos, config);
  }
}
