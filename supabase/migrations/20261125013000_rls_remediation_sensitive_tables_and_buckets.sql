-- =============================================================================
-- Remediación de Brechas de Exposición RLS y Storage
--   1. Restringir perfiles_select_all, profesores_select_all y respuestas_select_all
--      a usuarios autenticados con alcance por rol/propiedad (eliminando USING (true))
--   2. Privatizar bucket heredado 'updates' (public = false)
--   3. Excluir 'app-updates' (OTA público intencional) de auditar_exposicion_seguridad()
-- =============================================================================

ALTER POLICY perfiles_select_all
  ON public.perfiles
  TO authenticated
  USING (
    auth.uid() = id
    OR auth.uid() = user_id
    OR public.is_coordinador()
    OR public.is_super_admin()
    OR public.is_profesor()
  );

ALTER POLICY profesores_select_all
  ON public.profesores
  TO authenticated
  USING (
    user_id = auth.uid()
    OR perfil_id = auth.uid()
    OR public.is_coordinador()
    OR public.is_super_admin()
    OR public.is_profesor()
    OR EXISTS (
      SELECT 1
      FROM public.inscripciones i
      JOIN public.alumnos a ON a.id = i.alumno_id
      JOIN public.cursos c ON c.id = i.curso_id
      WHERE a.user_id = auth.uid()
        AND i.deleted_at IS NULL
        AND (c.profesor_id = profesores.id OR c.profesor_id = profesores.user_id)
    )
  );

ALTER POLICY respuestas_select_all
  ON public.respuestas_encuesta
  TO authenticated
  USING (
    public.is_coordinador()
    OR public.is_super_admin()
    OR public.is_profesor()
    OR EXISTS (
      SELECT 1
      FROM public.alumnos a
      WHERE a.id = respuestas_encuesta.alumno_id
        AND a.user_id = auth.uid()
    )
  );

UPDATE storage.buckets
SET public = false
WHERE id = 'updates';

CREATE OR REPLACE FUNCTION public.auditar_exposicion_seguridad()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rec RECORD;
  v_findings JSONB := '[]'::jsonb;
  v_count INTEGER := 0;
  v_sensitive_tables TEXT[] := ARRAY[
    'alumnos',
    'profesores',
    'perfiles',
    'respuestas_encuesta',
    'justificativos_asistencia'
  ];
  v_exposed_cols TEXT;
BEGIN
  IF NOT public.is_super_admin()
     AND current_user NOT IN ('postgres', 'service_role', 'supabase_admin') THEN
    PERFORM public.registrar_alerta_seguridad(
      'RPC auditar_exposicion_seguridad()',
      'Intento no autorizado de ejecutar la auditoría de exposición de seguridad.',
      jsonb_build_object('accion', 'BLOQUEADO'),
      auth.uid()
    );
    RAISE EXCEPTION 'Acceso denegado: Solo Super Admin puede ejecutar la auditoría de seguridad.';
  END IF;

  FOR v_rec IN
    SELECT c.relname AS table_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relrowsecurity = false
    ORDER BY c.relname
  LOOP
    v_count := v_count + 1;
    v_findings := v_findings || jsonb_build_array(jsonb_build_object(
      'tipo', 'RLS_DESACTIVADO',
      'objetivo', 'public.' || v_rec.table_name,
      'detalle', 'La tabla no tiene Row Level Security habilitado.'
    ));

    PERFORM public.registrar_alerta_seguridad(
      'public.' || v_rec.table_name || ' (RLS desactivado)',
      format('Brecha crítica: La tabla "public.%s" tiene RLS desactivado (relrowsecurity = false), exponiendo todos sus registros.', v_rec.table_name),
      jsonb_build_object(
        'tipo_brecha', 'RLS_DESACTIVADO',
        'tabla', 'public.' || v_rec.table_name,
        'info_expuesta', 'Todos los registros y columnas de public.' || v_rec.table_name
      ),
      auth.uid()
    );
  END LOOP;

  FOR v_rec IN
    SELECT
      p.tablename,
      p.policyname,
      p.cmd,
      p.roles
    FROM pg_policies p
    WHERE p.schemaname = 'public'
      AND p.tablename = ANY(v_sensitive_tables)
      AND (
        lower(regexp_replace(COALESCE(p.qual, ''), '\s+', '', 'g')) IN ('true', '(true)')
      )
    ORDER BY p.tablename, p.policyname
  LOOP
    SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
    INTO v_exposed_cols
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = v_rec.tablename;

    v_count := v_count + 1;
    v_findings := v_findings || jsonb_build_array(jsonb_build_object(
      'tipo', 'POLITICA_ABIERTA_USING_TRUE',
      'objetivo', 'public.' || v_rec.tablename,
      'politica', v_rec.policyname,
      'comando', v_rec.cmd,
      'columnas_expuestas', COALESCE(v_exposed_cols, 'todas')
    ));

    PERFORM public.registrar_alerta_seguridad(
      format('public.%s (Política "%s")', v_rec.tablename, v_rec.policyname),
      format('Brecha de exposición: Política %s con USING (true) en tabla sensible "public.%s". Columnas expuestas: %s.', v_rec.cmd, v_rec.tablename, COALESCE(v_exposed_cols, 'todas')),
      jsonb_build_object(
        'tipo_brecha', 'POLITICA_ABIERTA_USING_TRUE',
        'tabla', 'public.' || v_rec.tablename,
        'politica', v_rec.policyname,
        'comando', v_rec.cmd,
        'roles', v_rec.roles,
        'columnas_expuestas', COALESCE(v_exposed_cols, 'todas')
      ),
      auth.uid()
    );
  END LOOP;

  FOR v_rec IN
    SELECT id, name, public
    FROM storage.buckets
    WHERE id <> 'app-updates'
      AND (
        id ILIKE '%comprobante%'
        OR id ILIKE '%justificativo%'
        OR id ILIKE '%update%'
        OR id IN ('comprobantes', 'justificativos', 'updates', 'alumnos-private')
      )
      AND public = true
  LOOP
    v_count := v_count + 1;
    v_findings := v_findings || jsonb_build_array(jsonb_build_object(
      'tipo', 'BUCKET_PRIVADO_PUBLICO',
      'objetivo', 'storage.buckets/' || v_rec.id,
      'detalle', 'Bucket sensible configurado con public = true.'
    ));

    PERFORM public.registrar_alerta_seguridad(
      'storage.buckets/' || v_rec.id,
      format('Brecha en Storage: El bucket privado "%s" está configurado como public = true, exponiendo archivos sensibles.', v_rec.id),
      jsonb_build_object(
        'tipo_brecha', 'BUCKET_PRIVADO_PUBLICO',
        'bucket', v_rec.id,
        'info_expuesta', 'Archivos privados almacenados en ' || v_rec.id
      ),
      auth.uid()
    );
  END LOOP;

  RETURN jsonb_build_object(
    'status', CASE WHEN v_count = 0 THEN 'secure' ELSE 'vulnerabilities_detected' END,
    'findings_count', v_count,
    'findings', v_findings,
    'audited_at', now()
  );
END;
$function$;
