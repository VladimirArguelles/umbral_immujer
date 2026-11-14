-- Migración: Sincronización automática de assistant_logs con notificaciones (Super Admin)
-- Propósito: Garantizar que cada interacción o incidencia registrada en el Asistente IA (Umby)
--            genere su notificación en tiempo real para el Super Admin a nivel de base de datos,
--            independientemente de la versión cliente (Web o APK móvil).

-- 1. Función para replicar automáticamente las incidencias/consultas a notificaciones
CREATE OR REPLACE FUNCTION public.fn_sync_assistant_log_to_notificacion()
RETURNS TRIGGER AS $$
DECLARE
    v_user_nombre TEXT;
    v_user_rol TEXT;
    v_modulo TEXT;
BEGIN
    v_user_nombre := COALESCE(NEW.user_nombre, 'Usuario');
    v_user_rol := COALESCE(NEW.user_rol, 'usuario');
    v_modulo := COALESCE(NEW.modulo_id, 'general');

    -- Solo insertar si no existe ya una notificación para este log (idempotencia)
    IF NOT EXISTS (
        SELECT 1 FROM public.notificaciones 
        WHERE (datos->>'assistant_log_id') = NEW.id::text
    ) THEN
        INSERT INTO public.notificaciones (
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
            'Consulta IA Umby: ' || v_user_nombre || ' (' || UPPER(v_modulo) || ')',
            NEW.user_question,
            'incidencia_operacion',
            jsonb_build_object(
                'modulo', v_modulo,
                'usuario_nombre', v_user_nombre,
                'usuario_rol', v_user_rol,
                'donde_esta_el_problema', 'Consulta en Asistente Umby (' || v_modulo || ')',
                'que_debe_revisar', NEW.bot_answer,
                'assistant_log_id', NEW.id::text
            ),
            false,
            NEW.created_at,
            NEW.created_at
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger para insertar automáticamente al crearse un registro en assistant_logs
DROP TRIGGER IF EXISTS tr_sync_assistant_log_to_notificacion ON public.assistant_logs;
CREATE TRIGGER tr_sync_assistant_log_to_notificacion
AFTER INSERT ON public.assistant_logs
FOR EACH ROW
EXECUTE FUNCTION public.fn_sync_assistant_log_to_notificacion();

-- 3. Función para limpiar la notificación cuando se elimina el registro en assistant_logs
CREATE OR REPLACE FUNCTION public.fn_cleanup_notificacion_on_assistant_log_delete()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM public.notificaciones
    WHERE (datos->>'assistant_log_id') = OLD.id::text;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Trigger para eliminación coordinada
DROP TRIGGER IF EXISTS tr_cleanup_notificacion_on_assistant_log_delete ON public.assistant_logs;
CREATE TRIGGER tr_cleanup_notificacion_on_assistant_log_delete
AFTER DELETE ON public.assistant_logs
FOR EACH ROW
EXECUTE FUNCTION public.fn_cleanup_notificacion_on_assistant_log_delete();

-- 5. Backfill: Sincronizar las incidencias ya existentes en assistant_logs que falten en notificaciones
INSERT INTO public.notificaciones (
    usuario_origen_id,
    rol_destino,
    titulo,
    mensaje,
    tipo,
    datos,
    leido,
    created_at,
    updated_at
)
SELECT 
    al.user_id,
    'super_admin',
    'Consulta IA Umby: ' || COALESCE(al.user_nombre, 'Usuario') || ' (' || UPPER(COALESCE(al.modulo_id, 'general')) || ')',
    al.user_question,
    'incidencia_operacion',
    jsonb_build_object(
        'modulo', COALESCE(al.modulo_id, 'general'),
        'usuario_nombre', COALESCE(al.user_nombre, 'Usuario'),
        'usuario_rol', COALESCE(al.user_rol, 'usuario'),
        'donde_esta_el_problema', 'Consulta en Asistente Umby (' || COALESCE(al.modulo_id, 'general') || ')',
        'que_debe_revisar', al.bot_answer,
        'assistant_log_id', al.id::text
    ),
    false,
    al.created_at,
    al.created_at
FROM public.assistant_logs al
WHERE NOT EXISTS (
    SELECT 1 FROM public.notificaciones n
    WHERE (n.datos->>'assistant_log_id') = al.id::text
);
