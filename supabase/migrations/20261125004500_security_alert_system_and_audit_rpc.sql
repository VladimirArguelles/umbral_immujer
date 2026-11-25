-- =============================================================================
-- Sistema de Detección y Alerta Temprana de Violaciones de Seguridad
-- Blue Team / AppSec:
--   1. Función registrar_alerta_seguridad(...) -> system_exceptions + notificaciones
--   2. Sensores activos en triggers críticos (perfiles, respuestas_encuesta, inscripciones)
--   3. Función RPC auditar_exposicion_seguridad() para inspección bajo demanda
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Motor Central de Alertas de Seguridad
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.registrar_alerta_seguridad(
  p_punto_atacado TEXT,
  p_detalle_incidente TEXT,
  p_metadata JSONB DEFAULT '{}'::jsonb,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid UUID := COALESCE(p_user_id, auth.uid());
  v_user_name TEXT := 'Anónimo / Sistema';
  v_user_rol TEXT := 'desconocido';
  v_enriched_meta JSONB;
BEGIN
  IF v_uid IS NOT NULL THEN
    SELECT
      COALESCE(NULLIF(trim(nombre_completo), ''), correo, email, v_uid::text),
      COALESCE(NULLIF(trim(rol), ''), 'desconocido')
    INTO v_user_name, v_user_rol
    FROM public.perfiles
    WHERE id = v_uid OR user_id = v_uid
    LIMIT 1;
  END IF;

  v_enriched_meta := COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object(
    'punto_violado', p_punto_atacado,
    'info_comprometida', p_detalle_incidente,
    'usuario_origen_id', v_uid,
    'usuario_nombre', v_user_name,
    'usuario_rol', v_user_rol,
    'modulo', 'security_alert',
    'detectado_en', now()
  );

  -- 1. Persistir en Consola de Diagnóstico LIVE (public.system_exceptions)
  INSERT INTO public.system_exceptions (
    timestamp,
    severity,
    module,
    error_message,
    stack_trace,
    user_id,
    metadata
  ) VALUES (
    now(),
    'critical',
    'security_alert',
    format('[%s] %s', p_punto_atacado, p_detalle_incidente),
    NULL,
    v_uid,
    v_enriched_meta
  );

  -- 2. Notificar en tiempo real al Super Admin (public.notificaciones)
  INSERT INTO public.notificaciones (
    usuario_origen_id,
    rol_destino,
    titulo,
    mensaje,
    tipo,
    datos,
    leido
  ) VALUES (
    v_uid,
    'super_admin',
    format('🚨 ALERTA DE SEGURIDAD: %s', p_punto_atacado),
    format('%s | Origen: %s (%s)', p_detalle_incidente, v_user_name, v_user_rol),
    'security_alert',
    v_enriched_meta,
    false
  );
END;
$function$;

-- -----------------------------------------------------------------------------
-- 2. Sensores Activos en Triggers Críticos
--    (Usan RETURN NULL tras registrar la alerta para que la transacción
--     conserve la evidencia en system_exceptions y notificaciones mientras
--     bloquea/cancela la mutación maliciosa.)
-- -----------------------------------------------------------------------------

-- 2A. Sensor en public.perfiles (escalamiento de privilegios / cambio de rol)
CREATE OR REPLACE FUNCTION public.tr_fn_prevent_unauthorized_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF OLD.rol IS DISTINCT FROM NEW.rol THEN
    IF NOT public.is_super_admin()
       AND current_user NOT IN ('postgres', 'service_role', 'supabase_admin') THEN
      PERFORM public.registrar_alerta_seguridad(
        'public.perfiles (rol)',
        format('Intento no autorizado de escalamiento de rol de "%s" a "%s". Operación bloqueada.', OLD.rol, NEW.rol),
        jsonb_build_object(
          'tabla', 'public.perfiles',
          'columna', 'rol',
          'perfil_objetivo_id', OLD.id,
          'rol_anterior', OLD.rol,
          'rol_intentado', NEW.rol,
          'accion', 'BLOQUEADO'
        ),
        auth.uid()
      );
      RETURN NULL;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 2B. Sensor en public.respuestas_encuesta (manipulación de pagos o montos)
CREATE OR REPLACE FUNCTION public.fn_proteger_respuestas_encuesta()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rol TEXT := 'alumno';
  v_es_privilegiado BOOLEAN := FALSE;
  v_monto_real NUMERIC(12, 2) := 0.00;
  v_monto_esperado NUMERIC(12, 2) := 0.00;
BEGIN
  -- Permitir actualizaciones internas ejecutadas por funciones SECURITY DEFINER
  IF current_user IN ('postgres', 'supabase_admin')
     OR auth.role() = 'service_role'
     OR pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

  IF auth.uid() IS NOT NULL THEN
    SELECT lower(trim(rol))
    INTO v_rol
    FROM public.perfiles
    WHERE id = auth.uid() OR user_id = auth.uid()
    LIMIT 1;
  END IF;

  v_es_privilegiado := COALESCE(v_rol, 'alumno') IN ('profesor', 'coordinador', 'super_admin');

  IF NOT v_es_privilegiado THEN
    IF TG_OP = 'INSERT' THEN
      IF NEW.estado_pago IS DISTINCT FROM 'pendiente' THEN
        PERFORM public.registrar_alerta_seguridad(
          'public.respuestas_encuesta (estado_pago)',
          format('Intento de insertar respuesta con estado_pago="%s" sin privilegios. Forzado a "pendiente".', NEW.estado_pago),
          jsonb_build_object(
            'tabla', 'public.respuestas_encuesta',
            'columna', 'estado_pago',
            'encuesta_id', NEW.encuesta_id,
            'alumno_id', NEW.alumno_id,
            'valor_intentado', NEW.estado_pago,
            'accion', 'SANITIZADO_A_PENDIENTE'
          ),
          auth.uid()
        );
      END IF;
      NEW.estado_pago := 'pendiente';

    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.estado_pago IS DISTINCT FROM OLD.estado_pago THEN
        PERFORM public.registrar_alerta_seguridad(
          'public.respuestas_encuesta (estado_pago)',
          format('Intento no autorizado de alterar estado_pago de "%s" a "%s". Operación bloqueada.', OLD.estado_pago, NEW.estado_pago),
          jsonb_build_object(
            'tabla', 'public.respuestas_encuesta',
            'columna', 'estado_pago',
            'respuesta_id', OLD.id,
            'valor_anterior', OLD.estado_pago,
            'valor_intentado', NEW.estado_pago,
            'accion', 'BLOQUEADO'
          ),
          auth.uid()
        );
        RETURN NULL;
      END IF;

      IF NEW.monto_asignado IS DISTINCT FROM OLD.monto_asignado THEN
        PERFORM public.registrar_alerta_seguridad(
          'public.respuestas_encuesta (monto_asignado)',
          format('Intento no autorizado de alterar monto_asignado de "%s" a "%s". Operación bloqueada.', OLD.monto_asignado, NEW.monto_asignado),
          jsonb_build_object(
            'tabla', 'public.respuestas_encuesta',
            'columna', 'monto_asignado',
            'respuesta_id', OLD.id,
            'valor_anterior', OLD.monto_asignado,
            'valor_intentado', NEW.monto_asignado,
            'accion', 'BLOQUEADO'
          ),
          auth.uid()
        );
        RETURN NULL;
      END IF;
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    SELECT COALESCE(monto_individual_calculado, 0.00)
    INTO v_monto_real
    FROM public.encuestas_participacion
    WHERE id = NEW.encuesta_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'La encuesta especificada no existe.';
    END IF;

    v_monto_esperado := CASE
      WHEN COALESCE(NEW.asistira, false) THEN COALESCE(v_monto_real, 0.00)
      ELSE 0.00
    END;

    IF NOT v_es_privilegiado
       AND NEW.monto_asignado IS NOT NULL
       AND NEW.monto_asignado <> 0
       AND NEW.monto_asignado IS DISTINCT FROM v_monto_esperado THEN
      PERFORM public.registrar_alerta_seguridad(
        'public.respuestas_encuesta (monto_asignado)',
        format('Intento de manipular monto_asignado enviado ("%s" vs real "%s"). Sobrescrito con monto oficial.', NEW.monto_asignado, v_monto_esperado),
        jsonb_build_object(
          'tabla', 'public.respuestas_encuesta',
          'columna', 'monto_asignado',
          'encuesta_id', NEW.encuesta_id,
          'monto_intentado', NEW.monto_asignado,
          'monto_oficial', v_monto_esperado,
          'accion', 'SOBRESCRITO'
        ),
        auth.uid()
      );
    END IF;

    NEW.monto_asignado := v_monto_esperado;
  END IF;

  RETURN NEW;
END;
$function$;

-- 2C. Sensor en public.inscripciones (evasión de cupo_maximo)
CREATE OR REPLACE FUNCTION public.fn_validar_cupo_inscripcion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cupo_maximo INTEGER;
  v_nombre_curso TEXT;
  v_inscritos INTEGER;
BEGIN
  IF NEW.deleted_at IS NOT NULL OR NEW.estado <> 'activo' THEN
    RETURN NEW;
  END IF;

  SELECT cupo_maximo, nombre
  INTO v_cupo_maximo, v_nombre_curso
  FROM public.cursos
  WHERE id = NEW.curso_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El curso seleccionado no existe.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_inscritos
  FROM public.inscripciones
  WHERE curso_id = NEW.curso_id
    AND deleted_at IS NULL
    AND estado = 'activo';

  IF v_inscritos >= COALESCE(v_cupo_maximo, 30) THEN
    PERFORM public.registrar_alerta_seguridad(
      'public.inscripciones (cupo_maximo)',
      format('Intento de inscripción excediendo el cupo máximo del curso "%s" (%s / %s inscritos).', v_nombre_curso, v_inscritos, COALESCE(v_cupo_maximo, 30)),
      jsonb_build_object(
        'tabla', 'public.inscripciones',
        'columna', 'cupo_maximo',
        'curso_id', NEW.curso_id,
        'curso_nombre', v_nombre_curso,
        'alumno_id', NEW.alumno_id,
        'inscritos_actuales', v_inscritos,
        'cupo_maximo', COALESCE(v_cupo_maximo, 30),
        'accion', 'BLOQUEADO'
      ),
      auth.uid()
    );
    RETURN NULL;
  END IF;

  RETURN NEW;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 3. Función RPC de Auditoría de Exposición (auditar_exposicion_seguridad)
-- -----------------------------------------------------------------------------
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

  -- 1. Detectar tablas en public con RLS desactivado
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

  -- 2. Detectar políticas permisivas USING (true) en tablas con datos sensibles
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

  -- 3. Detectar buckets privados expuestos como públicos
  FOR v_rec IN
    SELECT id, name, public
    FROM storage.buckets
    WHERE (
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

REVOKE ALL ON FUNCTION public.registrar_alerta_seguridad(TEXT, TEXT, JSONB, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.auditar_exposicion_seguridad() TO authenticated;
