-- Migración: Protección de Seguridad RLS para Super Admin y Configuración General
-- Fecha: 2026-11-03
-- Objetivo: Restringir acceso y modificación de parámetros administrativos y perfiles

-- 1. Función de seguridad: Verifica si el usuario actual autenticado es Super Admin
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE id = auth.uid() AND rol = 'super_admin'
    );
END;
$$;

-- 2. Asegurar que RLS esté activo en configuracion_general
ALTER TABLE public.configuracion_general ENABLE ROW LEVEL SECURITY;

-- 3. Políticas para configuracion_general
DROP POLICY IF EXISTS "configuracion_select_all" ON public.configuracion_general;
DROP POLICY IF EXISTS "configuracion_admin_modify" ON public.configuracion_general;
DROP POLICY IF EXISTS "configuracion_select_admin" ON public.configuracion_general;
DROP POLICY IF EXISTS "configuracion_superadmin_modify" ON public.configuracion_general;

-- Lectura: Solo usuarios autenticados con roles administrativos (coordinador o super_admin)
CREATE POLICY "configuracion_select_admin" ON public.configuracion_general
FOR SELECT
TO authenticated
USING (public.is_coordinador());

-- Modificación (INSERT, UPDATE, DELETE): Estrictamente restringido a super_admin
CREATE POLICY "configuracion_superadmin_modify" ON public.configuracion_general
FOR ALL
TO authenticated
USING (public.is_super_admin())
WITH CHECK (public.is_super_admin());
