-- ============================================================================
-- MIGRACIÓN: Pre-registro de Profesores y Vinculación Automática en Auth
-- Archivo: 20261030153000_teacher_preregistration_and_linking.sql
-- Proyecto: UMBRAL - IMMUJER
-- ============================================================================

-- 1. Ajuste estructural de la tabla 'perfiles':
--    - id con valor por defecto UUID (permite inserciones de pre-registro sin auth.users previo).
--    - correo y email permiten valores nulos (NULL) durante el pre-registro manual.
--    - user_id almacena la referencia explícita a auth.users(id).
ALTER TABLE public.perfiles ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.perfiles ALTER COLUMN correo DROP NOT NULL;
ALTER TABLE public.perfiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.perfiles ALTER COLUMN email DROP NOT NULL;
ALTER TABLE public.perfiles ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Sincronizar registros previos ya existentes
UPDATE public.perfiles 
SET user_id = id 
WHERE user_id IS NULL AND EXISTS (SELECT 1 FROM auth.users WHERE auth.users.id = perfiles.id);

UPDATE public.perfiles 
SET email = correo 
WHERE email IS NULL AND correo IS NOT NULL;

-- 2. Eliminar clave foránea rígida de perfiles.id hacia auth.users(id)
--    Esto permite pre-registrar docentes antes de que creen sus credenciales de acceso.
ALTER TABLE public.perfiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- 3. Habilitar actualización en cascada para cursos asignados a docentes
ALTER TABLE public.cursos DROP CONSTRAINT IF EXISTS cursos_profesor_id_fkey;
ALTER TABLE public.cursos 
  ADD CONSTRAINT cursos_profesor_id_fkey 
  FOREIGN KEY (profesor_id) REFERENCES public.perfiles(id) 
  ON UPDATE CASCADE 
  ON DELETE SET NULL;

-- 4. Ampliar restricción de roles para admitir 'teacher' además de 'profesor'
ALTER TABLE public.perfiles DROP CONSTRAINT IF EXISTS profiles_rol_check;
ALTER TABLE public.perfiles 
  ADD CONSTRAINT profiles_rol_check 
  CHECK (rol = ANY (ARRAY['alumno'::text, 'profesor'::text, 'teacher'::text, 'coordinador'::text, 'super_admin'::text]));

-- 5. Trigger para bidireccionalidad y sincronización automática entre email y correo
CREATE OR REPLACE FUNCTION public.sync_perfiles_email_correo()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.email IS NOT NULL AND (NEW.correo IS NULL OR NEW.correo = '') THEN
        NEW.correo := NEW.email;
    ELSIF NEW.correo IS NOT NULL AND (NEW.email IS NULL OR NEW.email = '') THEN
        NEW.email := NEW.correo;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_sync_perfiles_email_correo ON public.perfiles;
CREATE TRIGGER tr_sync_perfiles_email_correo
BEFORE INSERT OR UPDATE ON public.perfiles
FOR EACH ROW EXECUTE FUNCTION public.sync_perfiles_email_correo();

-- 6. Actualización de la vista 'profiles' y soporte INSTEAD OF
CREATE OR REPLACE VIEW public.profiles WITH (security_invoker = true) AS
SELECT 
    id,
    nombre_completo,
    cedula,
    telefono,
    correo,
    rol,
    created_at,
    updated_at,
    user_id,
    nombre_completo AS full_name,
    cedula AS dni,
    telefono AS phone,
    correo AS email,
    rol AS role
FROM public.perfiles;

CREATE OR REPLACE FUNCTION public.tr_profiles_view_insert()
RETURNS TRIGGER AS $$
DECLARE
    v_id UUID := COALESCE(NEW.id, gen_random_uuid());
    v_nombre TEXT := COALESCE(NEW.nombre_completo, NEW.full_name);
    v_cedula TEXT := COALESCE(NEW.cedula, NEW.dni);
    v_telefono TEXT := COALESCE(NEW.telefono, NEW.phone);
    v_email TEXT := COALESCE(NEW.correo, NEW.email);
    v_rol TEXT := COALESCE(NEW.rol, NEW.role, 'profesor');
BEGIN
    IF LOWER(v_rol) = 'teacher' THEN
        v_rol := 'profesor';
    END IF;

    INSERT INTO public.perfiles (
        id,
        user_id,
        nombre_completo,
        cedula,
        telefono,
        correo,
        email,
        rol
    ) VALUES (
        v_id,
        NEW.user_id,
        v_nombre,
        v_cedula,
        v_telefono,
        v_email,
        v_email,
        v_rol
    );
    
    NEW.id := v_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_profiles_insert ON public.profiles;
CREATE TRIGGER tr_profiles_insert
INSTEAD OF INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.tr_profiles_view_insert();

CREATE OR REPLACE FUNCTION public.tr_profiles_view_update()
RETURNS TRIGGER AS $$
DECLARE
    v_rol TEXT := COALESCE(NEW.rol, NEW.role);
BEGIN
    IF LOWER(v_rol) = 'teacher' THEN
        v_rol := 'profesor';
    END IF;

    UPDATE public.perfiles
    SET 
        nombre_completo = COALESCE(NEW.nombre_completo, NEW.full_name, nombre_completo),
        cedula = COALESCE(NEW.cedula, NEW.dni, cedula),
        telefono = COALESCE(NEW.telefono, NEW.phone, telefono),
        correo = COALESCE(NEW.correo, NEW.email, correo),
        email = COALESCE(NEW.email, NEW.correo, email),
        user_id = COALESCE(NEW.user_id, user_id),
        rol = COALESCE(v_rol, rol),
        updated_at = now()
    WHERE id = OLD.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_profiles_update ON public.profiles;
CREATE TRIGGER tr_profiles_update
INSTEAD OF UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.tr_profiles_view_update();

-- 7. Trigger institucional handle_new_user() en auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
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

    -- Clasificación y verificación según rol
    IF v_meta_rol IN ('super_admin', 'superadmin', 'admin') 
       OR (v_meta_rol IS NULL AND v_is_db_admin) THEN
        v_rol := 'super_admin';
        v_nombre := COALESCE(v_nombre, 'Super Administrador');

    ELSIF v_meta_rol = 'coordinador' THEN
        v_rol := 'coordinador';

    ELSIF v_meta_rol IN ('profesor', 'teacher') THEN
        v_rol := 'profesor';

        -- Buscar registro pre-registrado en 'perfiles' por cédula, teléfono o correo
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

        -- Buscar en padrón auxiliar retrocompatible de profesores
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

        -- Enlace automático atómico del pre-registro con auth.users(id)
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

    -- Inserción / sincronización de perfiles
    INSERT INTO public.perfiles (id, user_id, nombre_completo, cedula, telefono, correo, email, rol)
    VALUES (NEW.id, NEW.id, v_nombre, v_cedula, v_telefono, NEW.email, NEW.email, v_rol)
    ON CONFLICT (id) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        nombre_completo = EXCLUDED.nombre_completo,
        cedula = EXCLUDED.cedula,
        telefono = EXCLUDED.telefono,
        correo = EXCLUDED.correo,
        email = EXCLUDED.email,
        rol = EXCLUDED.rol,
        updated_at = now();

    RETURN NEW;
END;
$$;
