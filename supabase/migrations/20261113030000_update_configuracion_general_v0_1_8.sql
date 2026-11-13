-- ============================================================================
-- MIGRACIÓN: Actualizar versión y build_number a 0.1.8+9 en configuracion_general
-- ============================================================================

INSERT INTO public.configuracion_general (clave, valor, descripcion)
VALUES (
  'app_build_number',
  '9'::jsonb,
  'Número entero de compilación (versionCode / buildNumber) de la última versión publicada'
)
ON CONFLICT (clave) DO UPDATE
SET valor = EXCLUDED.valor,
    descripcion = EXCLUDED.descripcion,
    updated_at = now();

INSERT INTO public.configuracion_general (clave, valor, descripcion)
VALUES (
  'app_version_latest',
  '"0.1.8"'::jsonb,
  'Versión semántica más reciente publicada (major.minor.patch)'
)
ON CONFLICT (clave) DO UPDATE
SET valor = EXCLUDED.valor,
    updated_at = now();

INSERT INTO public.configuracion_general (clave, valor, descripcion)
VALUES (
  'app_update_notes',
  '"Corrección responsiva integral en preguntas frecuentes de Umby, diálogos de Consola de Diagnóstico, scroll horizontal en chips de alerta y sincronización automática de incidencias con Notificaciones."'::jsonb,
  'Notas de la versión'
)
ON CONFLICT (clave) DO UPDATE
SET valor = EXCLUDED.valor,
    updated_at = now();
