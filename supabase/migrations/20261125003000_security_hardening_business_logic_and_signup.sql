-- =============================================================================
-- Migración de Blindaje de Seguridad (AppSec & PostgreSQL)
-- Puntos 4, 5, 6, 7 y 8:
--   - Restricciones CHECK de montos no negativos
--   - Prevención de duplicados y control estricto de cupos en inscripciones
--   - Protección de precios y estados de pago en respuestas_encuesta
--   - Blindaje de handle_new_user contra escalamiento de privilegios
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Validación de montos no negativos (Punto 5)
-- -----------------------------------------------------------------------------
ALTER TABLE public.encuestas_participacion
  DROP CONSTRAINT IF EXISTS chk_encuestas_costo_total_no_negativo,
  ADD CONSTRAINT chk_encuestas_costo_total_no_negativo
    CHECK (costo_total_insumos >= 0);

ALTER TABLE public.encuestas_participacion
  DROP CONSTRAINT IF EXISTS chk_encuestas_monto_individual_no_negativo,
  ADD CONSTRAINT chk_encuestas_monto_individual_no_negativo
    CHECK (monto_individual_calculado >= 0);

ALTER TABLE public.respuestas_encuesta
  DROP CONSTRAINT IF EXISTS chk_respuestas_monto_asignado_no_negativo,
  ADD CONSTRAINT chk_respuestas_monto_asignado_no_negativo
    CHECK (monto_asignado >= 0);

-- -----------------------------------------------------------------------------
-- 2. Prevención de duplicados y control de cupos (Punto 7)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.respuestas_encuesta'::regclass
      AND contype = 'u'
      AND conkey = ARRAY(
        SELECT attnum
        FROM pg_attribute
        WHERE attrelid = 'public.respuestas_encuesta'::regclass
          AND attname IN ('encuesta_id', 'alumno_id')
        ORDER BY attnum
      )
  ) THEN
    ALTER TABLE public.respuestas_encuesta
      ADD CONSTRAINT uq_respuestas_encuesta_encuesta_alumno
      UNIQUE (encuesta_id, alumno_id);
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_inscripcion_activa_unica
  ON public.inscripciones (curso_id, alumno_id)
  WHERE deleted_at IS NULL AND estado = 'activo';

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
    RAISE EXCEPTION 'Cupos agotados para el curso "%" (% / % inscritos).',
      v_nombre_curso, v_inscritos, COALESCE(v_cupo_maximo, 30);
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS tr_validar_cupo_inscripcion ON public.inscripciones;
CREATE TRIGGER tr_validar_cupo_inscripcion
  BEFORE INSERT ON public.inscripciones
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_validar_cupo_inscripcion();

-- -----------------------------------------------------------------------------
-- 3. Protección de precios y estados de pago (Puntos 4 y 6)
-- -----------------------------------------------------------------------------
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
BEGIN
  -- Permitir actualizaciones internas ejecutadas por funciones SECURITY DEFINER (ej. recalcular_monto_encuesta)
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
      NEW.estado_pago := 'pendiente';
    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.estado_pago IS DISTINCT FROM OLD.estado_pago THEN
        RAISE EXCEPTION 'Acceso denegado: No tiene permisos para modificar el estado de pago.';
      END IF;
      IF NEW.monto_asignado IS DISTINCT FROM OLD.monto_asignado THEN
        RAISE EXCEPTION 'Acceso denegado: No tiene permisos para modificar el monto asignado.';
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

    NEW.monto_asignado := CASE
      WHEN COALESCE(NEW.asistira, false) THEN COALESCE(v_monto_real, 0.00)
      ELSE 0.00
    END;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS tr_proteger_respuestas_encuesta ON public.respuestas_encuesta;
CREATE TRIGGER tr_proteger_respuestas_encuesta
  BEFORE INSERT OR UPDATE ON public.respuestas_encuesta
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_proteger_respuestas_encuesta();

-- -----------------------------------------------------------------------------
-- 4. Blindaje del Registro de Usuarios (Punto 8)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rol TEXT := 'alumno';
  v_nombre TEXT := COALESCE(
    NULLIF(trim(NEW.raw_user_meta_data->>'nombre_completo'), ''),
    NULLIF(trim(NEW.raw_user_meta_data->>'full_name'), ''),
    NEW.email
  );
  v_cedula TEXT := COALESCE(
    NEW.raw_user_meta_data->>'cedula',
    NEW.raw_user_meta_data->>'dni'
  );
  v_telefono TEXT := COALESCE(
    NEW.raw_user_meta_data->>'telefono',
    NEW.raw_user_meta_data->>'phone'
  );
  -- Solo se lee el rol desde raw_app_meta_data (exclusivo de Admin API / service_role).
  -- Cualquier campo 'rol' o 'role' en raw_user_meta_data es ignorado por completo.
  v_app_rol TEXT := lower(trim(COALESCE(
    NEW.raw_app_meta_data->>'rol',
    NEW.raw_app_meta_data->>'role',
    ''
  )));
  v_clean_cedula TEXT := NULL;
  v_numeric_cedula TEXT := NULL;
  v_clean_telefono TEXT := NULL;
  v_existing_profile_id UUID := NULL;
  v_profesor_id UUID := NULL;
  v_alumno_id UUID := NULL;
  v_is_db_admin BOOLEAN := FALSE;
BEGIN
  IF auth.role() = 'service_role'
     OR current_user IN ('postgres', 'supabase_admin') THEN
    v_is_db_admin := TRUE;
  END IF;

  IF v_cedula IS NOT NULL AND trim(v_cedula) <> '' THEN
    v_clean_cedula := regexp_replace(v_cedula, '[^0-9a-zA-Z]', '', 'g');
    v_numeric_cedula := regexp_replace(v_cedula, '[^0-9]', '', 'g');
  END IF;

  IF v_telefono IS NOT NULL AND trim(v_telefono) <> '' THEN
    v_clean_telefono := regexp_replace(v_telefono, '[^0-9]', '', 'g');
  END IF;

  -- Asignación privilegiada únicamente permitida vía backend/service_role (raw_app_meta_data)
  IF v_is_db_admin AND v_app_rol IN ('super_admin', 'superadmin', 'admin') THEN
    v_rol := 'super_admin';
    v_nombre := COALESCE(v_nombre, 'Super Administrador');

  ELSIF v_is_db_admin AND v_app_rol = 'coordinador' THEN
    v_rol := 'coordinador';

  ELSIF v_is_db_admin AND v_app_rol = 'operador_inscripcion' THEN
    v_rol := 'operador_inscripcion';

  ELSIF v_is_db_admin AND v_app_rol IN ('profesor', 'teacher') THEN
    v_rol := 'profesor';

    SELECT id INTO v_existing_profile_id
    FROM public.perfiles
    WHERE rol IN ('profesor', 'teacher')
      AND (
        (v_clean_cedula IS NOT NULL AND regexp_replace(cedula, '[^0-9a-zA-Z]', '', 'g') = v_clean_cedula)
        OR (v_numeric_cedula IS NOT NULL AND v_numeric_cedula <> '' AND regexp_replace(cedula, '[^0-9]', '', 'g') = v_numeric_cedula)
        OR (v_cedula IS NOT NULL AND cedula = v_cedula)
        OR (v_clean_telefono IS NOT NULL AND length(v_clean_telefono) >= 7 AND regexp_replace(telefono, '[^0-9]', '', 'g') = v_clean_telefono)
        OR (correo IS NOT NULL AND LOWER(correo) = LOWER(NEW.email))
      )
    LIMIT 1;

    SELECT id INTO v_profesor_id
    FROM public.profesores
    WHERE (correo IS NOT NULL AND LOWER(correo) = LOWER(NEW.email))
       OR (v_clean_cedula IS NOT NULL AND regexp_replace(cedula, '[^0-9a-zA-Z]', '', 'g') = v_clean_cedula)
       OR (v_numeric_cedula IS NOT NULL AND v_numeric_cedula <> '' AND regexp_replace(cedula, '[^0-9]', '', 'g') = v_numeric_cedula)
       OR (v_cedula IS NOT NULL AND cedula = v_cedula)
       OR (v_clean_telefono IS NOT NULL AND length(v_clean_telefono) >= 7 AND regexp_replace(telefono, '[^0-9]', '', 'g') = v_clean_telefono)
    LIMIT 1;

    IF v_profesor_id IS NOT NULL THEN
      UPDATE public.profesores
      SET user_id = NEW.id,
          correo = COALESCE(correo, NEW.email),
          updated_at = now()
      WHERE id = v_profesor_id;
    END IF;

    IF v_existing_profile_id IS NOT NULL THEN
      UPDATE public.perfiles
      SET id = NEW.id,
          user_id = NEW.id,
          correo = NEW.email,
          email = NEW.email,
          nombre_completo = COALESCE(NULLIF(v_nombre, ''), nombre_completo),
          cedula = COALESCE(NULLIF(trim(v_cedula), ''), cedula),
          telefono = COALESCE(NULLIF(trim(v_telefono), ''), telefono),
          rol = 'profesor',
          acceso_activo = true,
          updated_at = now()
      WHERE id = v_existing_profile_id;

      RETURN NEW;
    END IF;

  ELSE
    -- Registro público: se ignora cualquier rol enviado en raw_user_meta_data
    -- y se asigna forzosamente rol = 'alumno' y acceso_activo = true.
    v_rol := 'alumno';

    SELECT id INTO v_alumno_id
    FROM public.alumnos
    WHERE (correo IS NOT NULL AND LOWER(correo) = LOWER(NEW.email))
       OR (v_clean_cedula IS NOT NULL AND regexp_replace(cedula, '[^0-9a-zA-Z]', '', 'g') = v_clean_cedula)
       OR (v_numeric_cedula IS NOT NULL AND v_numeric_cedula <> '' AND regexp_replace(cedula, '[^0-9]', '', 'g') = v_numeric_cedula)
       OR (v_cedula IS NOT NULL AND cedula = v_cedula)
    LIMIT 1;

    IF v_alumno_id IS NOT NULL THEN
      UPDATE public.alumnos
      SET user_id = NEW.id,
          correo = COALESCE(correo, NEW.email),
          updated_at = now()
      WHERE id = v_alumno_id;
    END IF;
  END IF;

  INSERT INTO public.perfiles (
    id, user_id, nombre_completo, cedula, telefono, correo, email, rol, acceso_activo
  )
  VALUES (
    NEW.id,
    NEW.id,
    v_nombre,
    NULLIF(trim(v_cedula), ''),
    NULLIF(trim(v_telefono), ''),
    NEW.email,
    NEW.email,
    v_rol,
    true
  )
  ON CONFLICT (id) DO UPDATE
  SET user_id = EXCLUDED.user_id,
      nombre_completo = EXCLUDED.nombre_completo,
      cedula = COALESCE(EXCLUDED.cedula, public.perfiles.cedula),
      telefono = COALESCE(EXCLUDED.telefono, public.perfiles.telefono),
      correo = EXCLUDED.correo,
      email = EXCLUDED.email,
      rol = EXCLUDED.rol,
      acceso_activo = true,
      updated_at = now();

  RETURN NEW;
END;
$function$;
