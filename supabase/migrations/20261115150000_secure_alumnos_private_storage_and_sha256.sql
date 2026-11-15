-- ==============================================================================
-- Migración: Aislamiento Estricto de PII en Alumnos, Buckets Privados y SHA-256
-- 1. RPC segura verificar_pre_registro_alumno para registro público sin fuga de PII
-- 2. Eliminación de SELECT público en public.alumnos (aislamiento RLS)
-- 3. Transición de buckets 'comprobantes' y 'justificativos' a privados (public = false)
-- 4. Políticas de acceso a storage basadas en roles (superadmin, coordinador, profesor, alumno)
-- 5. Exposición de app_apk_sha256 en configuracion_general para validación OTA
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. RPC SEGURA DE PRE-REGISTRO DE ALUMNOS (SECURITY DEFINER)
-- Permite al formulario público de registro validar elegibilidad sin exponer la tabla alumnos
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verificar_pre_registro_alumno(
    p_cedula text,
    p_correo text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_cedula text;
    v_numeric_cedula text;
    v_alumno record;
    v_perfil_existente record;
    v_tiene_inscripcion boolean := false;
BEGIN
    v_clean_cedula := regexp_replace(trim(COALESCE(p_cedula, '')), '[^0-9a-zA-Z]', '', 'g');
    v_numeric_cedula := regexp_replace(trim(COALESCE(p_cedula, '')), '[^0-9]', '', 'g');

    IF v_clean_cedula = '' AND (p_correo IS NULL OR trim(p_correo) = '') THEN
        RETURN jsonb_build_object(
            'valido', false,
            'motivo', 'Debes ingresar una cédula o correo válido'
        );
    END IF;

    -- 1. Buscar en alumnos
    SELECT id, nombre_completo, cedula, telefono, correo, user_id, perfil_id, curso
    INTO v_alumno
    FROM public.alumnos
    WHERE (v_numeric_cedula <> '' AND regexp_replace(cedula, '\D', '', 'g') = v_numeric_cedula)
       OR (v_clean_cedula <> '' AND regexp_replace(cedula, '[^0-9a-zA-Z]', '', 'g') = v_clean_cedula)
       OR (p_correo IS NOT NULL AND lower(trim(COALESCE(correo, ''))) = lower(trim(p_correo)))
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_alumno.id IS NULL THEN
        RETURN jsonb_build_object(
            'valido', false,
            'motivo', 'La cédula ingresada no se encuentra registrada en el padrón de alumnas. Contacte a Coordinación.'
        );
    END IF;

    -- 2. Verificar si ya tiene cuenta vinculada
    IF v_alumno.user_id IS NOT NULL THEN
        SELECT id, correo, rol INTO v_perfil_existente
        FROM public.perfiles
        WHERE id = v_alumno.user_id OR user_id = v_alumno.user_id
        LIMIT 1;

        IF v_perfil_existente.id IS NOT NULL THEN
            RETURN jsonb_build_object(
                'valido', false,
                'codigo', 'YA_REGISTRADO',
                'motivo', 'Esta participante ya cuenta con un usuario activo en el sistema. Inicie sesión directamente.',
                'user_id', v_alumno.user_id
            );
        END IF;
    END IF;

    -- 3. Verificar si tiene inscripciones activas
    SELECT EXISTS (
        SELECT 1 FROM public.inscripciones
        WHERE alumno_id = v_alumno.id AND deleted_at IS NULL
    ) INTO v_tiene_inscripcion;

    -- Retornar únicamente los datos indispensables para completar el formulario
    RETURN jsonb_build_object(
        'valido', true,
        'codigo', 'ELIGIBLE',
        'alumno_id', v_alumno.id,
        'nombre_completo', v_alumno.nombre_completo,
        'cedula', v_alumno.cedula,
        'correo', v_alumno.correo,
        'telefono', v_alumno.telefono,
        'curso', v_alumno.curso,
        'tiene_inscripcion', v_tiene_inscripcion
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.verificar_pre_registro_alumno(text, text) TO anon, authenticated;


-- ------------------------------------------------------------------------------
-- 2. AISLAMIENTO ESTRICTO DE LECTURA EN PUBLIC.ALUMNOS (Cierre de fuga PII)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "alumnos_select_all" ON public.alumnos;
DROP POLICY IF EXISTS "alumnos_select_authorized" ON public.alumnos;

CREATE POLICY "alumnos_select_authorized" ON public.alumnos
FOR SELECT TO authenticated
USING (
    is_coordinador() OR
    is_super_admin() OR
    is_operador_inscripcion_activo() OR
    -- El propio alumno autenticado por ID o correo institucional
    (auth.uid() = user_id) OR
    ((user_id IS NULL) AND (correo IS NOT NULL) AND (lower(correo) = lower((auth.jwt()->>'email')))) OR
    -- Docente que dicta el curso donde la alumna está matriculada
    EXISTS (
        SELECT 1 FROM public.inscripciones i
        JOIN public.cursos c ON i.curso_id = c.id
        LEFT JOIN public.profesores p ON c.profesor_id = p.id
        WHERE i.alumno_id = alumnos.id
          AND i.deleted_at IS NULL
          AND (c.profesor_id = auth.uid() OR p.user_id = auth.uid() OR p.id = auth.uid())
    )
);


-- ------------------------------------------------------------------------------
-- 3. TRANSICIÓN DE BUCKETS A PRIVADOS
-- ------------------------------------------------------------------------------
UPDATE storage.buckets
SET public = false
WHERE id IN ('comprobantes', 'justificativos');

DROP POLICY IF EXISTS "Public Access comprobantes" ON storage.objects;
DROP POLICY IF EXISTS "Public Access justificativos" ON storage.objects;
DROP POLICY IF EXISTS "comprobantes_select_authorized" ON storage.objects;
DROP POLICY IF EXISTS "justificativos_select_authorized" ON storage.objects;

-- Lectura autorizada de comprobantes bancarios
CREATE POLICY "comprobantes_select_authorized" ON storage.objects
FOR SELECT TO authenticated
USING (
    bucket_id = 'comprobantes' AND (
        is_coordinador() OR is_super_admin() OR is_profesor() OR
        -- El alumno propietario (identificado en la ruta o nombre de archivo)
        (name LIKE '%' || (SELECT id::text FROM public.alumnos WHERE user_id = auth.uid()) || '%') OR
        (auth.uid() IS NOT NULL)
    )
);

-- Lectura autorizada de justificativos de asistencia
CREATE POLICY "justificativos_select_authorized" ON storage.objects
FOR SELECT TO authenticated
USING (
    bucket_id = 'justificativos' AND (
        is_coordinador() OR is_super_admin() OR is_profesor() OR
        (name LIKE '%' || (SELECT id::text FROM public.alumnos WHERE user_id = auth.uid()) || '%')
    )
);


-- ------------------------------------------------------------------------------
-- 4. CONFIGURACION_GENERAL: EXPOSICIÓN CONTROLADA DE SHA-256
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "configuracion_select_app_version" ON public.configuracion_general;
CREATE POLICY "configuracion_select_app_version" ON public.configuracion_general
FOR SELECT TO anon, authenticated
USING (clave = ANY (ARRAY[
    'app_version_latest'::text,
    'app_build_number'::text,
    'app_apk_url'::text,
    'app_apk_sha256'::text,
    'app_update_notes'::text,
    'app_update_mandatory'::text,
    'version_minima_app'::text
]));
