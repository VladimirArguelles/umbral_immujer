-- ============================================================================
-- MIGRACIÓN: Módulo de Inscripciones, Control de Cupos y Accesos Temporales
-- Archivo: 20261111213000_inscripciones_cupos_y_accesos_temporales.sql
-- Proyecto: UMBRAL - IMMUJER
-- ============================================================================

-- 1. Control de cupos y admisión en public.cursos
ALTER TABLE public.cursos
    ADD COLUMN IF NOT EXISTS cupo_maximo INTEGER NOT NULL DEFAULT 30,
    ADD COLUMN IF NOT EXISTS admision_abierta BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE public.cursos DROP CONSTRAINT IF EXISTS chk_cursos_cupo_maximo_positivo;
ALTER TABLE public.cursos
    ADD CONSTRAINT chk_cursos_cupo_maximo_positivo CHECK (cupo_maximo > 0);

CREATE INDEX IF NOT EXISTS idx_cursos_admision_abierta
    ON public.cursos (estado, admision_abierta);

-- 2. Trazabilidad e integridad híbrida en public.inscripciones
ALTER TABLE public.inscripciones
    ADD COLUMN IF NOT EXISTS origen TEXT NOT NULL DEFAULT 'historico',
    ADD COLUMN IF NOT EXISTS registrado_por UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS observaciones TEXT;

ALTER TABLE public.inscripciones DROP CONSTRAINT IF EXISTS chk_inscripciones_origen;
ALTER TABLE public.inscripciones
    ADD CONSTRAINT chk_inscripciones_origen
    CHECK (origen IN ('historico', 'formulario', 'coordinacion', 'admin'));

CREATE INDEX IF NOT EXISTS idx_inscripciones_registrado_por
    ON public.inscripciones (registrado_por);

CREATE INDEX IF NOT EXISTS idx_inscripciones_curso_activas
    ON public.inscripciones (curso_id)
    WHERE deleted_at IS NULL AND estado = 'activo';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_inscripciones_updated_at') THEN
        CREATE TRIGGER tr_inscripciones_updated_at
            BEFORE UPDATE ON public.inscripciones
            FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at_column();
    END IF;
END $$;

-- 3. Extensión de roles y control de acceso temporal en public.perfiles
ALTER TABLE public.perfiles
    ADD COLUMN IF NOT EXISTS acceso_activo BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE public.perfiles DROP CONSTRAINT IF EXISTS perfiles_rol_check;
ALTER TABLE public.perfiles
    ADD CONSTRAINT perfiles_rol_check
    CHECK (rol IN ('alumno', 'profesor', 'coordinador', 'super_admin', 'operador_inscripcion'));

CREATE INDEX IF NOT EXISTS idx_perfiles_rol_acceso_activo
    ON public.perfiles (rol, acceso_activo);

-- 4. Parámetro global inscripciones_activas en public.configuracion_general
INSERT INTO public.configuracion_general (clave, valor, descripcion)
VALUES (
    'inscripciones_activas',
    'true'::jsonb,
    'Habilita o deshabilita el periodo de inscripciones y el acceso temporal de operadores de inscripción'
)
ON CONFLICT (clave) DO NOTHING;

-- 5. Funciones auxiliares de seguridad y permisos
CREATE OR REPLACE FUNCTION public.is_profesor()
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE (id = auth.uid() OR user_id = auth.uid())
          AND rol IN ('profesor', 'teacher')
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.is_inscripciones_activas()
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_val JSONB;
BEGIN
    SELECT valor INTO v_val
    FROM public.configuracion_general
    WHERE clave = 'inscripciones_activas'
    LIMIT 1;

    IF v_val IS NULL THEN
        RETURN false;
    END IF;

    IF jsonb_typeof(v_val) = 'boolean' THEN
        RETURN (v_val::text)::boolean;
    END IF;

    RETURN lower(trim(both '"' from v_val::text)) IN ('true', '1', 'si', 'yes');
END;
$$;

CREATE OR REPLACE FUNCTION public.is_operador_inscripcion_activo()
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN false;
    END IF;

    IF NOT public.is_inscripciones_activas() THEN
        RETURN false;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE (id = auth.uid() OR user_id = auth.uid())
          AND rol = 'operador_inscripcion'
          AND acceso_activo = true
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.can_manage_inscripciones()
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN public.is_super_admin()
        OR public.is_coordinador()
        OR public.is_profesor()
        OR public.is_operador_inscripcion_activo();
END;
$$;

REVOKE ALL ON FUNCTION public.is_profesor() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_profesor() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_inscripciones_activas() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_inscripciones_activas() TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_operador_inscripcion_activo() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_operador_inscripcion_activo() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.can_manage_inscripciones() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_inscripciones() TO authenticated, service_role;

-- 6. Actualizar handle_new_user() para soportar operador_inscripcion creado por administración
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rol TEXT;
    v_nombre TEXT := COALESCE(NEW.raw_user_meta_data->>'nombre_completo', NEW.raw_user_meta_data->>'full_name', NEW.email);
    v_cedula TEXT := COALESCE(NEW.raw_user_meta_data->>'cedula', NEW.raw_user_meta_data->>'dni');
    v_telefono TEXT := COALESCE(NEW.raw_user_meta_data->>'telefono', NEW.raw_user_meta_data->>'phone');
    v_meta_rol TEXT := COALESCE(
        NEW.raw_user_meta_data->>'rol',
        NEW.raw_user_meta_data->>'role',
        NEW.raw_app_meta_data->>'rol',
        NEW.raw_app_meta_data->>'role'
    );
    v_clean_cedula TEXT := NULL;
    v_numeric_cedula TEXT := NULL;
    v_clean_telefono TEXT := NULL;
    v_existing_profile_id UUID := NULL;
    v_profesor_id UUID := NULL;
    v_alumno_id UUID := NULL;
    v_is_db_admin BOOLEAN := FALSE;
BEGIN
    IF auth.role() IS NULL OR auth.role() = 'service_role' OR current_user = 'postgres' OR current_user = 'supabase_admin' THEN
        v_is_db_admin := TRUE;
    END IF;

    IF v_cedula IS NOT NULL AND trim(v_cedula) <> '' THEN
        v_clean_cedula := regexp_replace(v_cedula, '[^0-9a-zA-Z]', '', 'g');
        v_numeric_cedula := regexp_replace(v_cedula, '[^0-9]', '', 'g');
    END IF;

    IF v_telefono IS NOT NULL AND trim(v_telefono) <> '' THEN
        v_clean_telefono := regexp_replace(v_telefono, '[^0-9]', '', 'g');
    END IF;

    IF v_meta_rol IN ('super_admin', 'superadmin', 'admin')
       OR (v_meta_rol IS NULL AND v_is_db_admin) THEN
        v_rol := 'super_admin';
        v_nombre := COALESCE(v_nombre, 'Super Administrador');

    ELSIF v_meta_rol = 'coordinador' THEN
        v_rol := 'coordinador';

    ELSIF v_meta_rol = 'operador_inscripcion' THEN
        IF NOT v_is_db_admin THEN
            RAISE EXCEPTION 'Registro denegado: Las credenciales temporales de Operador de Inscripción solo pueden ser emitidas por un Super Admin.';
        END IF;
        v_rol := 'operador_inscripcion';

    ELSIF v_meta_rol IN ('profesor', 'teacher') THEN
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
        ORDER BY
            CASE WHEN correo IS NOT NULL AND LOWER(correo) = LOWER(NEW.email) THEN 1
                 WHEN v_clean_cedula IS NOT NULL AND regexp_replace(cedula, '[^0-9a-zA-Z]', '', 'g') = v_clean_cedula THEN 2
                 ELSE 3 END
        LIMIT 1;

        SELECT id INTO v_profesor_id
        FROM public.profesores
        WHERE (correo IS NOT NULL AND LOWER(correo) = LOWER(NEW.email))
           OR (v_clean_cedula IS NOT NULL AND regexp_replace(cedula, '[^0-9a-zA-Z]', '', 'g') = v_clean_cedula)
           OR (v_numeric_cedula IS NOT NULL AND v_numeric_cedula <> '' AND regexp_replace(cedula, '[^0-9]', '', 'g') = v_numeric_cedula)
           OR (v_cedula IS NOT NULL AND cedula = v_cedula)
           OR (v_clean_telefono IS NOT NULL AND length(v_clean_telefono) >= 7 AND regexp_replace(telefono, '[^0-9]', '', 'g') = v_clean_telefono)
        LIMIT 1;

        IF v_existing_profile_id IS NULL AND v_profesor_id IS NULL THEN
            RAISE EXCEPTION 'Registro denegado: El docente no se encuentra en el registro oficial de profesores de IMMUJER.';
        END IF;

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
                cedula = COALESCE(NULLIF(v_cedula, ''), cedula),
                telefono = COALESCE(NULLIF(v_telefono, ''), telefono),
                rol = 'profesor',
                updated_at = now()
            WHERE id = v_existing_profile_id;

            RETURN NEW;
        END IF;

    ELSIF v_meta_rol = 'alumno' OR NOT v_is_db_admin THEN
        SELECT id INTO v_alumno_id
        FROM public.alumnos
        WHERE (correo IS NOT NULL AND LOWER(correo) = LOWER(NEW.email))
           OR (v_clean_cedula IS NOT NULL AND regexp_replace(cedula, '[^0-9a-zA-Z]', '', 'g') = v_clean_cedula)
           OR (v_numeric_cedula IS NOT NULL AND v_numeric_cedula <> '' AND regexp_replace(cedula, '[^0-9]', '', 'g') = v_numeric_cedula)
           OR (v_cedula IS NOT NULL AND cedula = v_cedula)
        LIMIT 1;

        IF v_alumno_id IS NULL THEN
            RAISE EXCEPTION 'Registro denegado: El alumno no se encuentra registrado en el padrón de alumnos de IMMUJER.';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM public.inscripciones
            WHERE alumno_id = v_alumno_id AND deleted_at IS NULL
        ) THEN
            RAISE EXCEPTION 'Registro denegado: El alumno está registrado pero no cuenta con una inscripción activa en ningún curso de IMMUJER.';
        END IF;

        v_rol := 'alumno';
        UPDATE public.alumnos
        SET user_id = NEW.id,
            correo = COALESCE(correo, NEW.email),
            updated_at = now()
        WHERE id = v_alumno_id;

    ELSE
        v_rol := 'alumno';
    END IF;

    INSERT INTO public.perfiles (id, user_id, nombre_completo, cedula, telefono, correo, email, rol, acceso_activo)
    VALUES (NEW.id, NEW.id, v_nombre, NULLIF(trim(v_cedula), ''), NULLIF(trim(v_telefono), ''), NEW.email, NEW.email, v_rol, true)
    ON CONFLICT (id) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        nombre_completo = EXCLUDED.nombre_completo,
        cedula = COALESCE(EXCLUDED.cedula, public.perfiles.cedula),
        telefono = COALESCE(EXCLUDED.telefono, public.perfiles.telefono),
        correo = EXCLUDED.correo,
        email = EXCLUDED.email,
        rol = EXCLUDED.rol,
        updated_at = now();

    RETURN NEW;
END;
$$;

-- 7. Trigger de validación de cupos para inserciones desde formulario (respeta carga histórica)
CREATE OR REPLACE FUNCTION public.validate_inscripcion_cupo()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cupo_maximo INTEGER;
    v_admision_abierta BOOLEAN;
    v_estado_curso TEXT;
    v_nombre_curso TEXT;
    v_inscritos INTEGER;
BEGIN
    IF NEW.deleted_at IS NOT NULL OR NEW.estado <> 'activo' THEN
        RETURN NEW;
    END IF;

    -- Las cargas históricas automatizadas mantienen compatibilidad sin bloqueo retroactivo
    IF COALESCE(NEW.origen, 'historico') = 'historico' THEN
        RETURN NEW;
    END IF;

    SELECT cupo_maximo, admision_abierta, estado, nombre
    INTO v_cupo_maximo, v_admision_abierta, v_estado_curso, v_nombre_curso
    FROM public.cursos
    WHERE id = NEW.curso_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El curso seleccionado no existe.';
    END IF;

    IF v_estado_curso <> 'activo' THEN
        RAISE EXCEPTION 'El curso "%" no se encuentra activo.', v_nombre_curso;
    END IF;

    IF NOT COALESCE(v_admision_abierta, true) THEN
        RAISE EXCEPTION 'La admisión para el curso "%" se encuentra cerrada.', v_nombre_curso;
    END IF;

    SELECT COUNT(*)::INTEGER
    INTO v_inscritos
    FROM public.inscripciones
    WHERE curso_id = NEW.curso_id
      AND deleted_at IS NULL
      AND estado = 'activo'
      AND id <> NEW.id;

    IF v_inscritos >= COALESCE(v_cupo_maximo, 30) THEN
        RAISE EXCEPTION 'Cupos agotados para el curso "%" (% / % inscritos).', v_nombre_curso, v_inscritos, COALESCE(v_cupo_maximo, 30);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_validate_inscripcion_cupo ON public.inscripciones;
CREATE TRIGGER tr_validate_inscripcion_cupo
    BEFORE INSERT OR UPDATE ON public.inscripciones
    FOR EACH ROW EXECUTE FUNCTION public.validate_inscripcion_cupo();

-- 8. RPCs operativas del módulo de Inscripciones y Super Admin
CREATE OR REPLACE FUNCTION public.obtener_cursos_con_cupos()
RETURNS TABLE (
    id UUID,
    nombre TEXT,
    descripcion TEXT,
    horario TEXT,
    estado TEXT,
    cupo_maximo INTEGER,
    admision_abierta BOOLEAN,
    inscritos_count INTEGER
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        c.id,
        c.nombre,
        c.descripcion,
        c.horario,
        c.estado,
        COALESCE(c.cupo_maximo, 30) AS cupo_maximo,
        COALESCE(c.admision_abierta, true) AS admision_abierta,
        COUNT(i.id) FILTER (WHERE i.deleted_at IS NULL AND i.estado = 'activo')::INTEGER AS inscritos_count
    FROM public.cursos c
    LEFT JOIN public.inscripciones i ON i.curso_id = c.id
    WHERE c.estado = 'activo'
    GROUP BY c.id, c.nombre, c.descripcion, c.horario, c.estado, c.cupo_maximo, c.admision_abierta
    ORDER BY c.nombre ASC;
$$;

REVOKE ALL ON FUNCTION public.obtener_cursos_con_cupos() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obtener_cursos_con_cupos() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.registrar_inscripcion_aspirante(
    p_curso_id UUID,
    p_cedula TEXT,
    p_nombres TEXT,
    p_apellidos TEXT,
    p_telefono TEXT,
    p_correo TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_clean_cedula TEXT;
    v_numeric_cedula TEXT;
    v_nombre_completo TEXT;
    v_clean_telefono TEXT;
    v_clean_correo TEXT;
    v_curso RECORD;
    v_inscritos_actuales INTEGER;
    v_alumno_id UUID;
    v_inscripcion_id UUID;
    v_existing_inscripcion RECORD;
BEGIN
    IF NOT public.can_manage_inscripciones() THEN
        RAISE EXCEPTION 'Acceso denegado: no tienes permisos activos para registrar inscripciones.';
    END IF;

    v_clean_cedula := regexp_replace(trim(COALESCE(p_cedula, '')), '[^0-9a-zA-Z]', '', 'g');
    v_numeric_cedula := regexp_replace(trim(COALESCE(p_cedula, '')), '[^0-9]', '', 'g');
    v_nombre_completo := regexp_replace(trim(COALESCE(p_nombres, '') || ' ' || COALESCE(p_apellidos, '')), '\s+', ' ', 'g');
    v_clean_telefono := trim(COALESCE(p_telefono, ''));
    v_clean_correo := lower(trim(COALESCE(p_correo, '')));

    IF v_clean_cedula = '' OR length(v_numeric_cedula) < 6 THEN
        RAISE EXCEPTION 'La cédula ingresada no es válida.';
    END IF;

    IF trim(COALESCE(p_nombres, '')) = '' OR trim(COALESCE(p_apellidos, '')) = '' THEN
        RAISE EXCEPTION 'Nombres y apellidos son obligatorios.';
    END IF;

    IF v_clean_correo = '' OR position('@' in v_clean_correo) = 0 THEN
        RAISE EXCEPTION 'El correo electrónico ingresado no es válido.';
    END IF;

    -- Bloquear fila del curso para garantizar control atómico de cupos
    SELECT id, nombre, estado, COALESCE(cupo_maximo, 30) AS cupo_maximo, COALESCE(admision_abierta, true) AS admision_abierta
    INTO v_curso
    FROM public.cursos
    WHERE id = p_curso_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El curso seleccionado no existe.';
    END IF;

    IF v_curso.estado <> 'activo' THEN
        RAISE EXCEPTION 'El curso "%" no está activo.', v_curso.nombre;
    END IF;

    IF NOT v_curso.admision_abierta THEN
        RAISE EXCEPTION 'La admisión para el curso "%" está cerrada.', v_curso.nombre;
    END IF;

    SELECT COUNT(*)::INTEGER
    INTO v_inscritos_actuales
    FROM public.inscripciones
    WHERE curso_id = p_curso_id
      AND deleted_at IS NULL
      AND estado = 'activo';

    IF v_inscritos_actuales >= v_curso.cupo_maximo THEN
        RAISE EXCEPTION 'Cupos agotados para "%": % / % inscritos.', v_curso.nombre, v_inscritos_actuales, v_curso.cupo_maximo;
    END IF;

    -- Buscar aspirante existente en public.alumnos por cédula normalizada
    SELECT id INTO v_alumno_id
    FROM public.alumnos
    WHERE regexp_replace(cedula, '[^0-9a-zA-Z]', '', 'g') = v_clean_cedula
       OR (v_numeric_cedula <> '' AND regexp_replace(cedula, '[^0-9]', '', 'g') = v_numeric_cedula)
    LIMIT 1;

    IF v_alumno_id IS NOT NULL THEN
        SELECT id, estado, deleted_at
        INTO v_existing_inscripcion
        FROM public.inscripciones
        WHERE curso_id = p_curso_id
          AND alumno_id = v_alumno_id
        LIMIT 1;

        IF FOUND AND v_existing_inscripcion.deleted_at IS NULL AND v_existing_inscripcion.estado = 'activo' THEN
            RAISE EXCEPTION 'La cédula % ya se encuentra inscrita en el curso "%".', p_cedula, v_curso.nombre;
        END IF;

        UPDATE public.alumnos
        SET nombre_completo = v_nombre_completo,
            telefono = COALESCE(NULLIF(v_clean_telefono, ''), telefono),
            correo = COALESCE(NULLIF(v_clean_correo, ''), correo),
            curso = COALESCE(curso, v_curso.nombre),
            updated_at = now()
        WHERE id = v_alumno_id;
    ELSE
        INSERT INTO public.alumnos (nombre_completo, cedula, telefono, correo, curso)
        VALUES (
            v_nombre_completo,
            v_clean_cedula,
            NULLIF(v_clean_telefono, ''),
            v_clean_correo,
            v_curso.nombre
        )
        RETURNING id INTO v_alumno_id;
    END IF;

    INSERT INTO public.inscripciones (curso_id, alumno_id, estado, deleted_at, origen, registrado_por)
    VALUES (p_curso_id, v_alumno_id, 'activo', NULL, 'formulario', auth.uid())
    ON CONFLICT (curso_id, alumno_id) DO UPDATE
    SET estado = 'activo',
        deleted_at = NULL,
        origen = 'formulario',
        registrado_por = auth.uid(),
        updated_at = now()
    RETURNING id INTO v_inscripcion_id;

    v_inscritos_actuales := v_inscritos_actuales + 1;

    RETURN jsonb_build_object(
        'inscripcion_id', v_inscripcion_id,
        'alumno_id', v_alumno_id,
        'curso_id', v_curso.id,
        'curso_nombre', v_curso.nombre,
        'nombre_completo', v_nombre_completo,
        'cedula', v_clean_cedula,
        'inscritos_actuales', v_inscritos_actuales,
        'cupo_maximo', v_curso.cupo_maximo,
        'cupos_restantes', GREATEST(v_curso.cupo_maximo - v_inscritos_actuales, 0)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.registrar_inscripcion_aspirante(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_inscripcion_aspirante(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.obtener_operadores_inscripcion()
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    nombre_completo TEXT,
    cedula TEXT,
    telefono TEXT,
    acceso_activo BOOLEAN,
    created_at TIMESTAMPTZ,
    last_sign_in_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    IF auth.uid() IS NOT NULL AND NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'Acceso denegado: solo Super Admin puede consultar operadores temporales.';
    END IF;

    RETURN QUERY
    SELECT
        p.id AS user_id,
        COALESCE(u.email::TEXT, p.correo, p.email, '')::TEXT AS email,
        COALESCE(p.nombre_completo, 'Operador Temporal')::TEXT AS nombre_completo,
        p.cedula::TEXT,
        p.telefono::TEXT,
        COALESCE(p.acceso_activo, true) AS acceso_activo,
        COALESCE(u.created_at, p.created_at) AS created_at,
        u.last_sign_in_at
    FROM public.perfiles p
    LEFT JOIN auth.users u ON u.id = p.id OR u.id = p.user_id
    WHERE p.rol = 'operador_inscripcion'
    ORDER BY COALESCE(u.created_at, p.created_at) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.obtener_operadores_inscripcion() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obtener_operadores_inscripcion() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_toggle_operador_acceso(
    p_user_id UUID,
    p_activo BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    IF auth.uid() IS NOT NULL AND NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'Acceso denegado: solo Super Admin puede modificar accesos temporales.';
    END IF;

    UPDATE public.perfiles
    SET acceso_activo = p_activo,
        updated_at = now()
    WHERE (id = p_user_id OR user_id = p_user_id)
      AND rol = 'operador_inscripcion';

    UPDATE auth.users
    SET banned_until = CASE WHEN p_activo THEN NULL ELSE '2099-12-31T23:59:59Z'::timestamptz END,
        updated_at = now()
    WHERE id = p_user_id;

    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_toggle_operador_acceso(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_toggle_operador_acceso(UUID, BOOLEAN) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_create_operador_inscripcion(
    p_email TEXT,
    p_password TEXT,
    p_nombre_completo TEXT,
    p_cedula TEXT DEFAULT NULL,
    p_telefono TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_email TEXT := lower(trim(COALESCE(p_email, '')));
    v_nombre TEXT := trim(COALESCE(p_nombre_completo, ''));
    v_cedula TEXT := NULLIF(trim(COALESCE(p_cedula, '')), '');
    v_telefono TEXT := NULLIF(trim(COALESCE(p_telefono, '')), '');
    v_user_id UUID := gen_random_uuid();
BEGIN
    IF auth.uid() IS NOT NULL AND NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'Acceso denegado: solo Super Admin puede crear operadores temporales.';
    END IF;

    IF v_email = '' OR position('@' in v_email) = 0 THEN
        RAISE EXCEPTION 'El correo electrónico ingresado no es válido.';
    END IF;

    IF length(trim(COALESCE(p_password, ''))) < 6 THEN
        RAISE EXCEPTION 'La contraseña temporal debe tener al menos 6 caracteres.';
    END IF;

    IF v_nombre = '' THEN
        RAISE EXCEPTION 'El nombre completo del operador es obligatorio.';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_email) THEN
        RAISE EXCEPTION 'Ya existe una cuenta registrada con el correo %.', v_email;
    END IF;

    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        email_change,
        email_change_token_new,
        recovery_token,
        is_sso_user,
        is_anonymous
    ) VALUES (
        '00000000-0000-0000-0000-000000000000'::uuid,
        v_user_id,
        'authenticated',
        'authenticated',
        v_email,
        extensions.crypt(p_password, extensions.gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object(
            'nombre_completo', v_nombre,
            'cedula', v_cedula,
            'telefono', v_telefono,
            'rol', 'operador_inscripcion'
        ),
        now(),
        now(),
        '',
        '',
        '',
        '',
        false,
        false
    );

    INSERT INTO auth.identities (
        id,
        user_id,
        provider_id,
        identity_data,
        provider,
        last_sign_in_at,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        v_user_id,
        v_user_id::text,
        jsonb_build_object(
            'sub', v_user_id::text,
            'email', v_email,
            'email_verified', true,
            'phone_verified', false
        ),
        'email',
        now(),
        now(),
        now()
    );

    INSERT INTO public.perfiles (
        id, user_id, nombre_completo, cedula, telefono, correo, email, rol, acceso_activo
    )
    VALUES (
        v_user_id, v_user_id, v_nombre, v_cedula, v_telefono, v_email, v_email, 'operador_inscripcion', true
    )
    ON CONFLICT (id) DO UPDATE
    SET nombre_completo = EXCLUDED.nombre_completo,
        cedula = EXCLUDED.cedula,
        telefono = EXCLUDED.telefono,
        correo = EXCLUDED.correo,
        email = EXCLUDED.email,
        rol = 'operador_inscripcion',
        acceso_activo = true,
        updated_at = now();

    RETURN v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_create_operador_inscripcion(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_create_operador_inscripcion(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_set_inscripciones_activas(p_activas BOOLEAN)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NOT NULL AND NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'Acceso denegado: solo Super Admin puede controlar el periodo de inscripciones.';
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

    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_inscripciones_activas(BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_inscripciones_activas(BOOLEAN) TO authenticated, service_role;

-- 9. Actualización de Políticas RLS (Row Level Security)
ALTER TABLE public.cursos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alumnos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inscripciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracion_general ENABLE ROW LEVEL SECURITY;

-- configuracion_general: permitir lectura de inscripciones_activas a usuarios autenticados
DROP POLICY IF EXISTS "configuracion_select_inscripciones_flag" ON public.configuracion_general;
CREATE POLICY "configuracion_select_inscripciones_flag" ON public.configuracion_general
FOR SELECT
TO authenticated
USING (clave = 'inscripciones_activas');

-- cursos: restringir INSERT únicamente a Coordinadores / Super Admin
DROP POLICY IF EXISTS "cursos_insert_admin" ON public.cursos;
CREATE POLICY "cursos_insert_admin" ON public.cursos
FOR INSERT
TO authenticated
WITH CHECK (public.is_coordinador());

-- alumnos: restringir INSERT/UPDATE a roles autorizados (y propio alumno al vincularse)
DROP POLICY IF EXISTS "alumnos_insert_coordinator" ON public.alumnos;
CREATE POLICY "alumnos_insert_authorized" ON public.alumnos
FOR INSERT
TO authenticated
WITH CHECK (
    public.is_coordinador()
    OR public.is_profesor()
    OR public.is_operador_inscripcion_activo()
);

DROP POLICY IF EXISTS "alumnos_update_coordinator" ON public.alumnos;
CREATE POLICY "alumnos_update_authorized" ON public.alumnos
FOR UPDATE
TO authenticated
USING (
    public.is_coordinador()
    OR public.is_profesor()
    OR public.is_operador_inscripcion_activo()
    OR auth.uid() = user_id
    OR (user_id IS NULL AND correo IS NOT NULL AND lower(correo) = lower(auth.jwt() ->> 'email'))
)
WITH CHECK (
    public.is_coordinador()
    OR public.is_profesor()
    OR public.is_operador_inscripcion_activo()
    OR auth.uid() = user_id
);

-- inscripciones: reemplazar política amplia por políticas granulares por acción
DROP POLICY IF EXISTS "inscripciones_all_teachers_admin" ON public.inscripciones;
DROP POLICY IF EXISTS "inscripciones_insert_authorized" ON public.inscripciones;
DROP POLICY IF EXISTS "inscripciones_update_authorized" ON public.inscripciones;
DROP POLICY IF EXISTS "inscripciones_delete_admin" ON public.inscripciones;

CREATE POLICY "inscripciones_insert_authorized" ON public.inscripciones
FOR INSERT
TO authenticated
WITH CHECK (
    public.is_coordinador()
    OR public.is_profesor()
    OR public.is_operador_inscripcion_activo()
);

CREATE POLICY "inscripciones_update_authorized" ON public.inscripciones
FOR UPDATE
TO authenticated
USING (
    public.is_coordinador()
    OR public.is_profesor()
    OR public.is_operador_inscripcion_activo()
)
WITH CHECK (
    public.is_coordinador()
    OR public.is_profesor()
    OR public.is_operador_inscripcion_activo()
);

CREATE POLICY "inscripciones_delete_admin" ON public.inscripciones
FOR DELETE
TO authenticated
USING (public.is_coordinador());
