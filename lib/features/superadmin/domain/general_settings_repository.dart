/// Default institutional configuration keys and fallback values.
const Map<String, dynamic> defaultGeneralSettings = {
  'tolerancia_minutos_asistencia': 15,
  'porcentaje_minimo_asistencia_aprobacion': 75,
  'bloqueo_edicion_asistencia_dias': 3,
  'webhook_notificaciones': '',
  'recordatorio_pagos_dias_previos': 2,
  'plantilla_mensaje_bienvenida':
      '¡Bienvenida a UMBRAL IMMUJER! Tu registro ha sido procesado exitosamente.',
  'max_file_size_mb_comprobante': 5,
  'formatos_permitidos_comprobantes': ['jpg', 'jpeg', 'png', 'pdf'],
  'compresion_imagenes_activa': true,
  'modo_mantenimiento': false,
  'tasa_cambio_oficial': 36.50,
  'dias_retencion_logs': 90,
  'limite_intentos_login': 5,
};

/// Contract for loading and saving institutional general settings.
abstract class GeneralSettingsRepository {
  /// Returns key-value pairs loaded from persistence.
  Future<Map<String, dynamic>> fetchSettings();

  /// Persists modified configuration keys atomically.
  Future<void> saveSettings(Map<String, dynamic> updates);
}
