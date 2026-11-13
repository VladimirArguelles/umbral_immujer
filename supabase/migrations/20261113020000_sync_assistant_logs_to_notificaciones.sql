-- ==============================================================================
-- MIGRACIÓN: Sincronización Automática de Consultas e Incidencias de Umby a Notificaciones
-- ==============================================================================

-- Función trigger para replicar consultas e incidencias de assistant_logs a notificaciones
CREATE OR REPLACE FUNCTION public.fn_sync_assistant_log_to_notificacion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_es_incidencia BOOLEAN;
    v_titulo TEXT;
    v_mensaje TEXT;
BEGIN
    -- Detectar si la pregunta o metadatos representan una falla, ticket o incidencia
    v_es_incidencia := (
        NEW.ticket_id IS NOT NULL 
        OR LOWER(NEW.user_question) ~* '(error|falla|problema|no funciona|no puedo|ayuda|bug|urgente)'
        OR (NEW.metadatos->>'ticket_generado')::boolean IS TRUE
    );

    IF NEW.ticket_id IS NOT NULL THEN
        v_titulo := 'Incidencia #' || SUBSTRING(NEW.ticket_id::text, 1, 8) || ' en Módulo ' || COALESCE(NEW.modulo_id, 'General');
    ELSIF v_es_incidencia THEN
        v_titulo := 'Incidencia reportada en Módulo ' || COALESCE(NEW.modulo_id, 'General');
    ELSE
        v_titulo := 'Consulta a Umby en Módulo ' || COALESCE(NEW.modulo_id, 'General');
    END IF;

    v_mensaje := 'El usuario ' || COALESCE(NEW.user_nombre, 'Usuario') || 
                 ' (' || COALESCE(NEW.user_rol, 'alumno') || ') consultó:\n"' || 
                 SUBSTRING(NEW.user_question, 1, 160) || '"';

    -- Insertar en notificaciones para que el Super Admin reciba la alerta de inmediato
    INSERT INTO public.notificaciones (
        rol_destino,
        usuario_origen_id,
        titulo,
        mensaje,
        tipo,
        leido,
        datos,
        created_at
    ) VALUES (
        'super_admin',
        NEW.user_id,
        v_titulo,
        v_mensaje,
        'incidencia_operacion',
        false,
        jsonb_build_object(
            'origen', 'assistant_logs',
            'assistant_log_id', NEW.id,
            'modulo', NEW.modulo_id,
            'usuario_nombre', NEW.user_nombre,
            'usuario_rol', NEW.user_rol,
            'ticket_id', NEW.ticket_id,
            'modelo_ia', NEW.modelo_ia,
            'donde_esta_el_problema', 'Módulo ' || COALESCE(NEW.modulo_id, 'General'),
            'que_debe_revisar', 'Consulta en Auditoría Umby'
        ),
        COALESCE(NEW.created_at, now())
    );

    RETURN NEW;
END;
$$;

-- Crear el trigger en assistant_logs (idempotente)
DROP TRIGGER IF EXISTS trg_sync_assistant_log_to_notificacion ON public.assistant_logs;
CREATE TRIGGER trg_sync_assistant_log_to_notificacion
AFTER INSERT ON public.assistant_logs
FOR EACH ROW
EXECUTE FUNCTION public.fn_sync_assistant_log_to_notificacion();

-- Sincronizar hacia atrás cualquier registro existente en assistant_logs que aún no esté en notificaciones
INSERT INTO public.notificaciones (
    rol_destino,
    usuario_origen_id,
    titulo,
    mensaje,
    tipo,
    leido,
    datos,
    created_at
)
SELECT 
    'super_admin',
    a.user_id,
    CASE 
        WHEN a.ticket_id IS NOT NULL THEN 'Incidencia #' || SUBSTRING(a.ticket_id::text, 1, 8) || ' en Módulo ' || COALESCE(a.modulo_id, 'General')
        WHEN LOWER(a.user_question) ~* '(error|falla|problema|no funciona|no puedo|ayuda|bug|urgente)' THEN 'Incidencia reportada en Módulo ' || COALESCE(a.modulo_id, 'General')
        ELSE 'Consulta a Umby en Módulo ' || COALESCE(a.modulo_id, 'General')
    END,
    'El usuario ' || COALESCE(a.user_nombre, 'Usuario') || ' (' || COALESCE(a.user_rol, 'alumno') || ') consultó:\n"' || SUBSTRING(a.user_question, 1, 160) || '"',
    'incidencia_operacion',
    false,
    jsonb_build_object(
        'origen', 'assistant_logs',
        'assistant_log_id', a.id,
        'modulo', a.modulo_id,
        'usuario_nombre', a.user_nombre,
        'usuario_rol', a.user_rol,
        'ticket_id', a.ticket_id,
        'modelo_ia', a.modelo_ia,
        'donde_esta_el_problema', 'Módulo ' || COALESCE(a.modulo_id, 'General'),
        'que_debe_revisar', 'Consulta en Auditoría Umby'
    ),
    a.created_at
FROM public.assistant_logs a
WHERE NOT EXISTS (
    SELECT 1 FROM public.notificaciones n 
    WHERE (n.datos->>'assistant_log_id') = a.id::text
);
