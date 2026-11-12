-- ============================================================================
-- Migración: Fechas del periodo de inscripciones, control de cupos por curso
--            y vista oficial para el reporte de Inscripciones.
-- ============================================================================

-- 1. Registrar claves de fechas de periodo en configuracion_general
INSERT INTO public.configuracion_general (clave, valor, descripcion)
VALUES
  (
    'inscripciones_fecha_inicio',
    'null'::jsonb,
    'Fecha de inicio (YYYY-MM-DD) del periodo de inscripciones'
  ),
  (
    'inscripciones_fecha_fin',
    'null'::jsonb,
    'Fecha de cierre (YYYY-MM-DD) del periodo de inscripciones'
  )
ON CONFLICT (clave) DO NOTHING;

-- 2. Ampliar política de lectura en configuracion_general para las claves de periodo
DROP POLICY IF EXISTS configuracion_select_inscripciones_flag ON public.configuracion_general;
CREATE POLICY configuracion_select_inscripciones_flag
  ON public.configuracion_general
  FOR SELECT
  TO authenticated
  USING (
    clave = ANY (
      ARRAY[
        'inscripciones_activas'::text,
        'inscripciones_fecha_inicio'::text,
        'inscripciones_fecha_fin'::text
      ]
    )
  );

-- 3. Función auxiliar para leer toda la configuración del periodo de inscripciones
CREATE OR REPLACE FUNCTION public.get_inscripciones_periodo_config()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_flag_raw jsonb;
  v_inicio_raw jsonb;
  v_fin_raw jsonb;
  v_flag boolean := false;
  v_inicio_txt text;
  v_fin_txt text;
  v_inicio_date date;
  v_fin_date date;
  v_hoy date := timezone('America/Caracas', now())::date;
  v_en_rango boolean := true;
BEGIN
  SELECT valor INTO v_flag_raw
  FROM public.configuracion_general
  WHERE clave = 'inscripciones_activas'
  LIMIT 1;

  IF v_flag_raw IS NOT NULL THEN
    IF jsonb_typeof(v_flag_raw) = 'boolean' THEN
      v_flag := (v_flag_raw::text)::boolean;
    ELSE
      v_flag := lower(trim(both '"' from v_flag_raw::text)) IN ('true', '1', 'si', 'yes');
    END IF;
  END IF;

  SELECT valor INTO v_inicio_raw
  FROM public.configuracion_general
  WHERE clave = 'inscripciones_fecha_inicio'
  LIMIT 1;

  IF v_inicio_raw IS NOT NULL AND jsonb_typeof(v_inicio_raw) <> 'null' THEN
    v_inicio_txt := nullif(trim(both '"' from v_inicio_raw::text), '');
    IF v_inicio_txt IS NOT NULL AND v_inicio_txt ~ '^\d{4}-\d{2}-\d{2}$' THEN
      v_inicio_date := v_inicio_txt::date;
    END IF;
  END IF;

  SELECT valor INTO v_fin_raw
  FROM public.configuracion_general
  WHERE clave = 'inscripciones_fecha_fin'
  LIMIT 1;

  IF v_fin_raw IS NOT NULL AND jsonb_typeof(v_fin_raw) <> 'null' THEN
    v_fin_txt := nullif(trim(both '"' from v_fin_raw::text), '');
    IF v_fin_txt IS NOT NULL AND v_fin_txt ~ '^\d{4}-\d{2}-\d{2}$' THEN
      v_fin_date := v_fin_txt::date;
    END IF;
  END IF;

  IF v_inicio_date IS NOT NULL AND v_hoy < v_inicio_date THEN
    v_en_rango := false;
  END IF;

  IF v_fin_date IS NOT NULL AND v_hoy > v_fin_date THEN
    v_en_rango := false;
  END IF;

  RETURN jsonb_build_object(
    'activas_flag', v_flag,
    'activas_efectivo', (v_flag AND v_en_rango),
    'en_rango_fechas', v_en_rango,
    'fecha_inicio', to_char(v_inicio_date, 'YYYY-MM-DD'),
    'fecha_fin', to_char(v_fin_date, 'YYYY-MM-DD'),
    'fecha_actual', to_char(v_hoy, 'YYYY-MM-DD')
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_inscripciones_periodo_config() TO authenticated;

-- 4. Actualizar is_inscripciones_activas() para validar bandera + rango de fechas
CREATE OR REPLACE FUNCTION public.is_inscripciones_activas()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_cfg jsonb;
BEGIN
  v_cfg := public.get_inscripciones_periodo_config();
  RETURN COALESCE((v_cfg ->> 'activas_efectivo')::boolean, false);
END;
$function$;

-- 5. RPC Super Admin para configurar estado + fechas de inicio y cierre del periodo
CREATE OR REPLACE FUNCTION public.admin_set_inscripciones_periodo(
  p_activas boolean,
  p_fecha_inicio date DEFAULT NULL,
  p_fecha_fin date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Acceso denegado: solo Super Admin puede configurar el periodo de inscripciones.';
  END IF;

  IF p_fecha_inicio IS NOT NULL AND p_fecha_fin IS NOT NULL AND p_fecha_fin < p_fecha_inicio THEN
    RAISE EXCEPTION 'La fecha de cierre no puede ser anterior a la fecha de inicio.';
  END IF;

  INSERT INTO public.configuracion_general (clave, valor, descripcion, actualizado_en)
  VALUES (
    'inscripciones_activas',
    to_jsonb(p_activas),
    'Habilita o deshabilita el periodo de inscripciones y el acceso temporal de operadores de inscripción',
    now()
  )
  ON CONFLICT (clave) DO UPDATE
  SET valor = to_jsonb(p_activas),
      actualizado_en = now(),
      updated_at = now();

  INSERT INTO public.configuracion_general (clave, valor, descripcion, actualizado_en)
  VALUES (
    'inscripciones_fecha_inicio',
    CASE WHEN p_fecha_inicio IS NULL THEN 'null'::jsonb ELSE to_jsonb(to_char(p_fecha_inicio, 'YYYY-MM-DD')) END,
    'Fecha de inicio (YYYY-MM-DD) del periodo de inscripciones',
    now()
  )
  ON CONFLICT (clave) DO UPDATE
  SET valor = CASE WHEN p_fecha_inicio IS NULL THEN 'null'::jsonb ELSE to_jsonb(to_char(p_fecha_inicio, 'YYYY-MM-DD')) END,
      actualizado_en = now(),
      updated_at = now();

  INSERT INTO public.configuracion_general (clave, valor, descripcion, actualizado_en)
  VALUES (
    'inscripciones_fecha_fin',
    CASE WHEN p_fecha_fin IS NULL THEN 'null'::jsonb ELSE to_jsonb(to_char(p_fecha_fin, 'YYYY-MM-DD')) END,
    'Fecha de cierre (YYYY-MM-DD) del periodo de inscripciones',
    now()
  )
  ON CONFLICT (clave) DO UPDATE
  SET valor = CASE WHEN p_fecha_fin IS NULL THEN 'null'::jsonb ELSE to_jsonb(to_char(p_fecha_fin, 'YYYY-MM-DD')) END,
      actualizado_en = now(),
      updated_at = now();

  RETURN public.get_inscripciones_periodo_config();
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_set_inscripciones_periodo(boolean, date, date) TO authenticated;

-- 6. RPC para establecer cantidad de cupos (y estado de admisión) por curso
CREATE OR REPLACE FUNCTION public.admin_set_curso_cupo(
  p_curso_id uuid,
  p_cupo_maximo integer,
  p_admision_abierta boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_updated public.cursos%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR (NOT public.is_super_admin() AND NOT public.is_coordinador()) THEN
    RAISE EXCEPTION 'Acceso denegado: no tienes permisos para modificar los cupos de los cursos.';
  END IF;

  IF p_cupo_maximo IS NULL OR p_cupo_maximo < 1 OR p_cupo_maximo > 1000 THEN
    RAISE EXCEPTION 'La cantidad de cupos debe estar entre 1 y 1000.';
  END IF;

  UPDATE public.cursos
  SET cupo_maximo = p_cupo_maximo,
      admision_abierta = COALESCE(p_admision_abierta, admision_abierta),
      updated_at = now()
  WHERE id = p_curso_id
  RETURNING * INTO v_updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El curso seleccionado no existe.';
  END IF;

  RETURN jsonb_build_object(
    'id', v_updated.id,
    'nombre', v_updated.nombre,
    'cupo_maximo', v_updated.cupo_maximo,
    'admision_abierta', v_updated.admision_abierta
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_set_curso_cupo(uuid, integer, boolean) TO authenticated;

-- 7. Vista oficial de Inscripciones para el Centro de Reportes
CREATE OR REPLACE VIEW public.view_reporte_inscripciones AS
SELECT
  i.id AS inscripcion_id,
  c.id AS curso_id,
  c.nombre AS curso_nombre,
  COALESCE(c.horario, 'Por definir') AS horario,
  COALESCE(c.cupo_maximo, 30) AS cupo_maximo,
  COALESCE(pf.nombre_completo, 'Sin asignar') AS profesor_nombre,
  a.id AS alumno_id,
  a.cedula,
  a.nombre_completo,
  COALESCE(a.correo, '') AS correo,
  COALESCE(a.telefono, '') AS telefono,
  i.estado AS estado_inscripcion,
  COALESCE(i.origen, 'formulario') AS origen,
  i.observaciones,
  i.created_at AS fecha_inscripcion
FROM public.inscripciones i
JOIN public.cursos c ON i.curso_id = c.id
JOIN public.alumnos a ON i.alumno_id = a.id
LEFT JOIN public.perfiles pf ON c.profesor_id = pf.id
WHERE i.deleted_at IS NULL;

GRANT SELECT ON public.view_reporte_inscripciones TO authenticated;
