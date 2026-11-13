-- Migración: Sincronización automática de Auditoría IA (assistant_logs) con Notificaciones del Super Admin
-- Fecha: 2026-11-13

CREATE OR REPLACE FUNCTION trg_sync_assistant_log_to_notificaciones_fn()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notificaciones (
    usuario_origen_id,
    rol_destino,
    titulo,
    mensaje,
    tipo,
    datos,
    leido,
    created_at,
    updated_at
  ) VALUES (
    NEW.user_id,
    'super_admin',
    'Consulta IA Umby: ' || COALESCE(NEW.user_nombre, 'Usuario') || ' (' || UPPER(COALESCE(NEW.modulo_id, 'GENERAL')) || ')',
    NEW.user_question,
    'incidencia_operacion',
    jsonb_build_object(
      'assistant_log_id', NEW.id,
      'usuario_nombre', COALESCE(NEW.user_nombre, 'Usuario'),
      'usuario_rol', COALESCE(NEW.user_rol, 'GENERAL'),
      'modulo', NEW.modulo_id,
      'donde_esta_el_problema', 'Consulta registrada en el Asistente Umby (' || COALESCE(NEW.modulo_id, 'general') || ')',
      'que_debe_revisar', COALESCE(NEW.bot_answer, 'Sin respuesta')
    ),
    false,
    COALESCE(NEW.created_at, NOW()),
    NOW()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_assistant_log_to_notificaciones ON assistant_logs;

CREATE TRIGGER trg_sync_assistant_log_to_notificaciones
AFTER INSERT ON assistant_logs
FOR EACH ROW
EXECUTE FUNCTION trg_sync_assistant_log_to_notificaciones_fn();
