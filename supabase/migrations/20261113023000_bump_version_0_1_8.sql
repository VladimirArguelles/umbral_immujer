-- Actualización de versión para notificación y control de actualización remota
UPDATE configuracion_general
SET 
  app_version_latest = '0.1.8',
  app_build_number = 9,
  app_update_notes = 'Corrección de visualización en Consola de Diagnóstico (diálogo de eliminar auditoría y barra de estado), panel de Alertas & Diagnósticos (scroll horizontal en chips de filtro, centrado de estado vacío) y sincronización automática de auditorías Umby con la bandeja de Notificaciones.',
  updated_at = NOW();
