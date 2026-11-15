-- Migración: 20261115163000_drop_zero_rebuild_remote_config_and_feature_flags.sql
-- Descripción: Eliminar estructuras obsoletas de configuración remota en caliente y feature flags dinámicos,
-- simplificando la arquitectura para mantener exclusivamente el gestor de versiones APK.

DO $$
BEGIN
  -- 1. Remover tablas de supabase_realtime si existen en la publicación
  IF EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'app_remote_config'
  ) THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.app_remote_config;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'feature_flags'
  ) THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.feature_flags;
  END IF;
END $$;

-- 2. Eliminar funciones dependientes obsoletas
DROP FUNCTION IF EXISTS public.obtener_bundle_configuracion_remota();

-- 3. Eliminar tablas obsoletas
DROP TABLE IF EXISTS public.app_remote_config CASCADE;
DROP TABLE IF EXISTS public.feature_flags CASCADE;
