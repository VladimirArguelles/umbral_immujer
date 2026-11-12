-- ============================================================================
-- MIGRACIÓN: Registrar app_build_number y habilitar lectura RLS para todos los roles
-- ============================================================================

-- Asegurar RLS habilitado en configuracion_general
ALTER TABLE public.configuracion_general ENABLE ROW LEVEL SECURITY;

-- 1. Registrar/actualizar el build_number entero correspondiente a pubspec.yaml (0.1.3+4 -> 4)
INSERT INTO public.configuracion_general (clave, valor, descripcion)
VALUES (
  'app_build_number',
  '4'::jsonb,
  'Número entero de compilación (versionCode / buildNumber) de la última versión publicada'
)
ON CONFLICT (clave) DO UPDATE
SET valor = EXCLUDED.valor,
    descripcion = EXCLUDED.descripcion,
    updated_at = now();

-- 2. Asegurar consistencia de app_version_latest
INSERT INTO public.configuracion_general (clave, valor, descripcion)
VALUES (
  'app_version_latest',
  '"0.1.3"'::jsonb,
  'Versión semántica más reciente publicada (major.minor.patch)'
)
ON CONFLICT (clave) DO UPDATE
SET valor = EXCLUDED.valor,
    updated_at = now();

-- 3. Ampliar la política RLS de lectura pública (anon y authenticated) para incluir 'app_build_number'
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'configuracion_general'
      AND policyname = 'configuracion_select_app_version'
  ) THEN
    ALTER POLICY configuracion_select_app_version
    ON public.configuracion_general
    USING (
      clave = ANY (ARRAY[
        'app_version_latest'::text,
        'app_build_number'::text,
        'app_apk_url'::text,
        'app_update_notes'::text,
        'app_update_mandatory'::text,
        'version_minima_app'::text
      ])
    );
  ELSE
    CREATE POLICY configuracion_select_app_version
    ON public.configuracion_general
    FOR SELECT
    TO anon, authenticated
    USING (
      clave = ANY (ARRAY[
        'app_version_latest'::text,
        'app_build_number'::text,
        'app_apk_url'::text,
        'app_update_notes'::text,
        'app_update_mandatory'::text,
        'version_minima_app'::text
      ])
    );
  END IF;
END $$;
