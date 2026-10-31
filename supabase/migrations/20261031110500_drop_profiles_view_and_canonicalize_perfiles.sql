-- ============================================================================
-- MIGRACIÓN: Eliminación de Vista profiles y Canonización de la Tabla perfiles
-- Archivo: 20261031110500_drop_profiles_view_and_canonicalize_perfiles.sql
-- Proyecto: UMBRAL - IMMUJER
-- ============================================================================

-- 1. Eliminación de la vista redundante 'profiles' y sus funciones de trigger
DROP VIEW IF EXISTS public.profiles CASCADE;
DROP FUNCTION IF EXISTS public.tr_profiles_view_insert() CASCADE;
DROP FUNCTION IF EXISTS public.tr_profiles_view_update() CASCADE;

-- 2. Canonización de nombres de restricciones y claves en 'perfiles'
ALTER TABLE public.perfiles RENAME CONSTRAINT profiles_pkey TO perfiles_pkey;
ALTER TABLE public.perfiles RENAME CONSTRAINT profiles_cedula_key TO perfiles_cedula_key;
ALTER TABLE public.perfiles RENAME CONSTRAINT profiles_correo_key TO perfiles_correo_key;
ALTER TABLE public.perfiles RENAME CONSTRAINT profiles_rol_check TO perfiles_rol_check;

-- 3. Canonización de nombres de políticas RLS en 'perfiles'
ALTER POLICY profiles_insert_own_or_admin ON public.perfiles RENAME TO perfiles_insert_own_or_admin;
ALTER POLICY profiles_select_all ON public.perfiles RENAME TO perfiles_select_all;
ALTER POLICY profiles_update_own ON public.perfiles RENAME TO perfiles_update_own;
