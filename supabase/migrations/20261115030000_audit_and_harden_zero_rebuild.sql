-- ==============================================================================
-- MIGRACIÓN: Auditoría y Fortalecimiento de Zero-Rebuild y Server-Driven UI
-- Protocolo UMBRAL: Sincronización en Caliente Multiplataforma (Web y Móvil)
-- ==============================================================================

-- 1. ASEGURAR REPLICA IDENTITY FULL
-- Permite que Supabase Realtime transmita registros completos (old y new) en eventos UPDATE y DELETE
ALTER TABLE public.app_remote_config REPLICA IDENTITY FULL;
ALTER TABLE public.feature_flags REPLICA IDENTITY FULL;
ALTER TABLE public.configuracion_general REPLICA IDENTITY FULL;

-- 2. ASEGURAR PUBLICACIÓN EN SUPABASE_REALTIME
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

-- 3. POLÍTICAS ROW LEVEL SECURITY (RLS) ESTRICTAS
ALTER TABLE public.app_remote_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracion_general ENABLE ROW LEVEL SECURITY;

-- Lectura abierta a todo cliente (público / anónimo / autenticado) para bootstrap inmediato
DROP POLICY IF EXISTS "remote_config_read_public" ON public.app_remote_config;
CREATE POLICY "remote_config_read_public"
ON public.app_remote_config FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "feature_flags_read_public" ON public.feature_flags;
CREATE POLICY "feature_flags_read_public"
ON public.feature_flags FOR SELECT TO public USING (true);

-- Escritura reservada exclusivamente para rol super_admin
DROP POLICY IF EXISTS "remote_config_admin_write" ON public.app_remote_config;
CREATE POLICY "remote_config_admin_write"
ON public.app_remote_config FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE perfiles.id = auth.uid()
        AND perfiles.rol = 'super_admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE perfiles.id = auth.uid()
        AND perfiles.rol = 'super_admin'
    )
);

DROP POLICY IF EXISTS "feature_flags_admin_write" ON public.feature_flags;
CREATE POLICY "feature_flags_admin_write"
ON public.feature_flags FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE perfiles.id = auth.uid()
        AND perfiles.rol = 'super_admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE perfiles.id = auth.uid()
        AND perfiles.rol = 'super_admin'
    )
);

-- 4. PARÁMETROS SEMILLA SERVER-DRIVEN UI PARA CONTROL DINÁMICO DE COMPONENTES
INSERT INTO public.app_remote_config (key, value, category, description)
VALUES
    ('coordinator_reports_icon', '"folder"'::jsonb, 'ui', 'Icono del botón Centro de Reportes en Coordinación (folder, visibility, document)'),
    ('coordinator_reports_label', '"Centro de Reportes y Documentos Oficiales"'::jsonb, 'copy', 'Etiqueta o tooltip del botón de reportes en Coordinación')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value, category = EXCLUDED.category, description = EXCLUDED.description;
