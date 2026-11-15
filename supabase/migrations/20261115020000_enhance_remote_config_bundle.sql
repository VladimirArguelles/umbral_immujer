-- ==============================================================================
-- MIGRACIÓN: Consolidación Completa del Bundle de Configuración Remota (Zero-Rebuild)
-- Protocolo UMBRAL: Unificación de app_remote_config, feature_flags y configuracion_general
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.obtener_bundle_configuracion_remota()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_configs JSONB;
    v_flags JSONB;
    v_general JSONB;
BEGIN
    -- 1. Parámetros de Server-Driven UI y Reglas de Negocio
    SELECT jsonb_object_agg(key, jsonb_build_object('value', value, 'category', category, 'updated_at', updated_at))
    INTO v_configs
    FROM public.app_remote_config;

    -- 2. Feature Flags y Visibilidad por Rol
    SELECT jsonb_object_agg(flag_key, jsonb_build_object('is_enabled', is_enabled, 'target_roles', target_roles, 'updated_at', updated_at))
    INTO v_flags
    FROM public.feature_flags;

    -- 3. Configuración Institucional General
    SELECT jsonb_object_agg(clave, jsonb_build_object('value', valor, 'updated_at', actualizado_en))
    INTO v_general
    FROM public.configuracion_general;

    RETURN jsonb_build_object(
        'configs', COALESCE(v_configs, '{}'::jsonb),
        'flags', COALESCE(v_flags, '{}'::jsonb),
        'general', COALESCE(v_general, '{}'::jsonb),
        'server_timestamp', now()
    );
END;
$$;

-- Permisos de ejecución
GRANT EXECUTE ON FUNCTION public.obtener_bundle_configuracion_remota() TO authenticated, anon;

-- Asegurar publicación Realtime para las tres tablas clave
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'app_remote_config'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.app_remote_config;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'feature_flags'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.feature_flags;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'configuracion_general'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.configuracion_general;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;
