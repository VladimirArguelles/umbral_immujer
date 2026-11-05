-- ============================================================================
-- MIGRACIÓN: Corrección de Seguridad Linter Supabase (Security Invoker) y RLS Super Admin
-- Archivo: 20261105014500_fix_views_security_invoker_and_superadmin_rls.sql
-- ============================================================================

-- 1. Helper Functions de Seguridad con search_path explícito y reconocimiento de 'super_admin' y 'administrador'
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE id = auth.uid() 
          AND rol IN ('super_admin', 'administrador', 'admin')
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.is_coordinador()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE id = auth.uid() 
          AND rol IN ('coordinador', 'super_admin', 'administrador', 'admin')
    );
END;
$$;

-- 2. Configurar security_invoker = true en todas las vistas de reportes
ALTER VIEW public.view_reporte_alumnos_curso SET (security_invoker = true);
ALTER VIEW public.view_reporte_profesores_cursos SET (security_invoker = true);
ALTER VIEW public.view_reporte_temas_curso SET (security_invoker = true);
ALTER VIEW public.view_reporte_asistencia_resumen SET (security_invoker = true);
ALTER VIEW public.view_reporte_asistencia_detallada SET (security_invoker = true);

-- 3. Vistas sinónimas en singular con security_invoker = true
CREATE OR REPLACE VIEW public.view_reporte_profesores_curso 
WITH (security_invoker = true) AS
SELECT * FROM public.view_reporte_profesores_cursos;

CREATE OR REPLACE VIEW public.view_reporte_asistencia_detalle 
WITH (security_invoker = true) AS
SELECT * FROM public.view_reporte_asistencia_detallada;

-- 4. Permisos de lectura otorgados a anon, authenticated y service_role
GRANT SELECT ON public.view_reporte_alumnos_curso TO anon, authenticated, service_role;
GRANT SELECT ON public.view_reporte_profesores_cursos TO anon, authenticated, service_role;
GRANT SELECT ON public.view_reporte_profesores_curso TO anon, authenticated, service_role;
GRANT SELECT ON public.view_reporte_temas_curso TO anon, authenticated, service_role;
GRANT SELECT ON public.view_reporte_asistencia_resumen TO anon, authenticated, service_role;
GRANT SELECT ON public.view_reporte_asistencia_detallada TO anon, authenticated, service_role;
GRANT SELECT ON public.view_reporte_asistencia_detalle TO anon, authenticated, service_role;
