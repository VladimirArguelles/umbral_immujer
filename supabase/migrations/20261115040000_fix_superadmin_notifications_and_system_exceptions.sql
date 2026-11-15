-- ==============================================================================
-- MIGRACIÓN: Corrección de RLS y Realtime para Notificaciones y system_exceptions
-- Permite eliminación de notificaciones e incidencias por Super Admin
-- Conecta observabilidad técnica en tiempo real con la Consola de Diagnóstico LIVE
-- ==============================================================================

-- 1. REPLICA IDENTITY FULL PARA TRANSMISIÓN REALTIME EXACTA DE DELETES
ALTER TABLE public.notificaciones REPLICA IDENTITY FULL;
ALTER TABLE public.tickets_soporte REPLICA IDENTITY FULL;
ALTER TABLE public.system_exceptions REPLICA IDENTITY FULL;

-- 2. PUBLICACIÓN EN SUPABASE_REALTIME
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'notificaciones'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notificaciones;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'tickets_soporte'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.tickets_soporte;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'system_exceptions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.system_exceptions;
    END IF;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- 3. POLÍTICAS RLS: public.notificaciones (DELETE)
DROP POLICY IF EXISTS "Super admin puede eliminar notificaciones" ON public.notificaciones;
DROP POLICY IF EXISTS "Users can delete relevant notifications" ON public.notificaciones;

CREATE POLICY "Super admin puede eliminar notificaciones"
ON public.notificaciones
FOR DELETE
USING (
    usuario_destino_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE (perfiles.id = auth.uid() OR perfiles.user_id = auth.uid())
        AND perfiles.rol IN ('super_admin', 'superadmin')
    )
);

-- 4. POLÍTICAS RLS: public.tickets_soporte (DELETE)
DROP POLICY IF EXISTS "Super admin puede eliminar tickets" ON public.tickets_soporte;
DROP POLICY IF EXISTS "tickets_delete_super_admin" ON public.tickets_soporte;

CREATE POLICY "Super admin puede eliminar tickets"
ON public.tickets_soporte
FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE (perfiles.id = auth.uid() OR perfiles.user_id = auth.uid())
        AND perfiles.rol IN ('super_admin', 'superadmin')
    )
);

-- 5. POLÍTICAS RLS: public.system_exceptions (INSERT, SELECT, DELETE)
ALTER TABLE public.system_exceptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuarios pueden registrar excepciones" ON public.system_exceptions;
DROP POLICY IF EXISTS "system_exceptions_insert_authenticated" ON public.system_exceptions;
DROP POLICY IF EXISTS "system_exceptions_insert_anon" ON public.system_exceptions;

CREATE POLICY "Usuarios pueden registrar excepciones"
ON public.system_exceptions
FOR INSERT
WITH CHECK (
    auth.role() IN ('authenticated', 'anon')
);

DROP POLICY IF EXISTS "Super admin lee y limpia excepciones" ON public.system_exceptions;
DROP POLICY IF EXISTS "system_exceptions_read_super_admin" ON public.system_exceptions;
DROP POLICY IF EXISTS "system_exceptions_delete_super_admin" ON public.system_exceptions;

CREATE POLICY "Super admin lee y limpia excepciones"
ON public.system_exceptions
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE (perfiles.id = auth.uid() OR perfiles.user_id = auth.uid())
        AND perfiles.rol IN ('super_admin', 'superadmin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE (perfiles.id = auth.uid() OR perfiles.user_id = auth.uid())
        AND perfiles.rol IN ('super_admin', 'superadmin')
    )
);
