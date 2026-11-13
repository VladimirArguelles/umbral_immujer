-- Actualización de versión para notificación y control de actualización remota
UPDATE configuracion_general
SET 
  app_version_latest = '0.1.7',
  app_build_number = 8,
  app_update_notes = 'Optimización integral de responsividad móvil: botones flexibles sin desbordes, diálogos adaptativos, títulos protegidos contra solapamiento y auditoría en tiempo real en la consola de diagnóstico.',
  updated_at = NOW();
