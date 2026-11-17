-- ==============================================================================
-- MIGRACIÓN: Permitir lectura pública y anónima de app_apk_sha256
-- Garantiza la verificación de integridad criptográfica en descargas OTA
-- ==============================================================================

ALTER POLICY "configuracion_select_app_version" ON public.configuracion_general
USING (clave = ANY (ARRAY[
    'app_version_latest'::text,
    'app_build_number'::text,
    'app_apk_url'::text,
    'app_apk_sha256'::text,
    'app_update_notes'::text,
    'app_update_mandatory'::text,
    'version_minima_app'::text
]));
