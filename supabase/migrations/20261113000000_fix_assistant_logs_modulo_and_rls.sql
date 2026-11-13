-- ==============================================================================
-- MIGRACIÓN: Corrección de Restricción de Módulos y Políticas en assistant_logs
-- ==============================================================================

DO $$
BEGIN
    -- 1. Actualizar restricción de módulos en assistant_logs para admitir variantes canónicas y plurales
    ALTER TABLE public.assistant_logs DROP CONSTRAINT IF EXISTS chk_assistant_logs_modulo;
    ALTER TABLE public.assistant_logs 
    ADD CONSTRAINT chk_assistant_logs_modulo 
    CHECK (modulo_id IN (
        'general', 'superadmin', 'super_admin', 'coordinador', 'coordinacion', 
        'profesor', 'profesores', 'alumnos', 'alumno', 'inscripciones', 
        'reportes', 'asistencia', 'encuestas', 'configuracion', 'impresion'
    ));

    -- 2. Asegurar que las políticas RLS permitan inserción de auditoría
    DROP POLICY IF EXISTS "assistant_logs_insert" ON public.assistant_logs;
    CREATE POLICY "assistant_logs_insert"
    ON public.assistant_logs
    FOR INSERT
    TO public
    WITH CHECK (true);

    -- 3. Asegurar que Super Admin pueda leer todos los logs de auditoría
    DROP POLICY IF EXISTS "assistant_logs_super_admin_select" ON public.assistant_logs;
    CREATE POLICY "assistant_logs_super_admin_select"
    ON public.assistant_logs
    FOR SELECT
    TO authenticated
    USING (
        (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
    );
END $$;
