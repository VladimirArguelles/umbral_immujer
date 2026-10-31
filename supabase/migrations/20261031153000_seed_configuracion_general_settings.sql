-- ============================================================================
-- MIGRACIÓN: Parámetros Clave-Valor de Configuración General
-- Archivo: 20261031153000_seed_configuracion_general_settings.sql
-- ============================================================================

INSERT INTO public.configuracion_general (clave, valor, descripcion) VALUES
  ('tolerancia_minutos_asistencia', '15'::jsonb, 'Minutos de tolerancia para considerar asistencia puntual'),
  ('porcentaje_minimo_asistencia_aprobacion', '75'::jsonb, 'Porcentaje mínimo de asistencia requerido para aprobar'),
  ('bloqueo_edicion_asistencia_dias', '3'::jsonb, 'Días tras los cuales se bloquea la edición de asistencia pasada'),
  ('n8n_webhook_notificaciones', '"https://n8n.umbral.gob/webhook/notify"'::jsonb, 'URL del webhook n8n para disparo de notificaciones WhatsApp'),
  ('recordatorio_pagos_dias_previos', '2'::jsonb, 'Días previos a la clase para enviar recordatorio de pago de insumos'),
  ('plantilla_mensaje_bienvenida', '"¡Bienvenida a UMBRAL IMMUJER! Tu registro ha sido procesado exitosamente."'::jsonb, 'Plantilla del mensaje de bienvenida por WhatsApp'),
  ('max_file_size_mb_comprobante', '5'::jsonb, 'Tamaño máximo permitido en MB para comprobantes de pago'),
  ('formatos_permitidos_comprobantes', '["jpg", "jpeg", "png", "pdf"]'::jsonb, 'Formatos y extensiones permitidas para comprobantes'),
  ('compresion_imagenes_activa', 'true'::jsonb, 'Compresión automática de imágenes antes de subirlas al bucket'),
  ('modo_mantenimiento', 'false'::jsonb, 'Estado del modo mantenimiento de la plataforma'),
  ('version_minima_app', '"1.0.0"'::jsonb, 'Versión mínima requerida de la aplicación móvil'),
  ('tasa_cambio_oficial', '36.50'::jsonb, 'Tasa de cambio oficial de referencia en bolívares'),
  ('dias_retencion_logs', '90'::jsonb, 'Días de retención para auditorías y logs del sistema'),
  ('limite_intentos_login', '5'::jsonb, 'Límite de intentos fallidos antes de bloquear temporalmente el acceso')
ON CONFLICT (clave) DO NOTHING;
