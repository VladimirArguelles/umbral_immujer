-- ==============================================================================
-- MIGRACIÓN: Arquitectura de Configuración Remota y Feature Flags (OTA / Zero-Rebuild)
-- ==============================================================================

-- 1. TABLA: app_remote_config (Parámetros Dinámicos de UI, Copy y Reglas)
CREATE TABLE IF NOT EXISTS public.app_remote_config (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    category VARCHAR(30) NOT NULL CHECK (category IN ('ui', 'business_rule', 'copy', 'general')),
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. TABLA: feature_flags (Activación y Visibilidad de Módulos Remotos)
CREATE TABLE IF NOT EXISTS public.feature_flags (
    flag_key VARCHAR(100) PRIMARY KEY,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    target_roles TEXT[] NOT NULL DEFAULT ARRAY['todos'],
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_remote_config_category ON public.app_remote_config(category);
CREATE INDEX IF NOT EXISTS idx_feature_flags_enabled ON public.feature_flags(is_enabled);

-- Triggers para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION public.fn_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_app_remote_config_updated_at ON public.app_remote_config;
CREATE TRIGGER trg_app_remote_config_updated_at
BEFORE UPDATE ON public.app_remote_config
FOR EACH ROW EXECUTE FUNCTION public.fn_touch_updated_at();

DROP TRIGGER IF EXISTS trg_feature_flags_updated_at ON public.feature_flags;
CREATE TRIGGER trg_feature_flags_updated_at
BEFORE UPDATE ON public.feature_flags
FOR EACH ROW EXECUTE FUNCTION public.fn_touch_updated_at();

-- 3. POLÍTICAS ROW LEVEL SECURITY (RLS)
ALTER TABLE public.app_remote_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

-- Lectura abierta (Pública y Autenticada) para que el cliente cargue configs en arranque
DROP POLICY IF EXISTS "remote_config_read_public" ON public.app_remote_config;
CREATE POLICY "remote_config_read_public"
ON public.app_remote_config
FOR SELECT
TO public
USING (true);

DROP POLICY IF EXISTS "feature_flags_read_public" ON public.feature_flags;
CREATE POLICY "feature_flags_read_public"
ON public.feature_flags
FOR SELECT
TO public
USING (true);

-- Modificación restringida exclusivamente a Super Administradores
DROP POLICY IF EXISTS "remote_config_admin_write" ON public.app_remote_config;
CREATE POLICY "remote_config_admin_write"
ON public.app_remote_config
FOR ALL
TO authenticated
USING (
    (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
)
WITH CHECK (
    (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
);

DROP POLICY IF EXISTS "feature_flags_admin_write" ON public.feature_flags;
CREATE POLICY "feature_flags_admin_write"
ON public.feature_flags
FOR ALL
TO authenticated
USING (
    (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
)
WITH CHECK (
    (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
);

-- 4. VALORES SEMILLA INICIALES (SEED DATA)
INSERT INTO public.app_remote_config (key, value, category, description)
VALUES
    ('primary_color', '"#E0115F"'::jsonb, 'ui', 'Color primario institucional dinámico (Hexadecimal)'),
    ('background_color', '"#0D0714"'::jsonb, 'ui', 'Fondo base principal de la plataforma (Hexadecimal)'),
    ('card_background', '"#1E293B"'::jsonb, 'ui', 'Fondo principal de tarjetas modulares en modo oscuro'),
    ('accent_color', '"#0BD984"'::jsonb, 'ui', 'Color de acento y éxito neón institucional'),
    ('glassmorphism_blur', '14.0'::jsonb, 'ui', 'Nivel de desenfoque de fondo en tarjetas translúcidas (sigma)'),
    ('glassmorphism_opacity', '0.70'::jsonb, 'ui', 'Opacidad base para tarjetas glassmorphic'),
    ('welcome_title', '"Bienvenida a UMBRAL"'::jsonb, 'copy', 'Título principal del landing y bienvenida general'),
    ('welcome_subtitle', '"Plataforma Integral de Capacitación y Gestión Institucional IMMUJER"'::jsonb, 'copy', 'Subtítulo descriptivo institucional'),
    ('landing_headline', '"Empoderamiento, Formación y Autonomía para las Mujeres"'::jsonb, 'copy', 'Titular de la página principal'),
    ('maintenance_banner', '""'::jsonb, 'copy', 'Mensaje de aviso de mantenimiento global (vacío para desactivar)'),
    ('max_students_per_course', '35'::jsonb, 'business_rule', 'Límite máximo general de alumnas por aula/curso'),
    ('require_dni_verification', 'true'::jsonb, 'business_rule', 'Exigir validación estricta de cédula de identidad en inscripciones'),
    ('allow_late_attendance', 'false'::jsonb, 'business_rule', 'Permitir pases de lista fuera del horario del curso'),
    ('default_practical_contribution_usd', '2.0'::jsonb, 'business_rule', 'Monto sugerido en USD para aporte de clase práctica')
ON CONFLICT (key) DO UPDATE 
SET value = EXCLUDED.value, category = EXCLUDED.category, description = EXCLUDED.description;

INSERT INTO public.feature_flags (flag_key, is_enabled, target_roles, description)
VALUES
    ('enable_pdf_importer', true, ARRAY['super_admin', 'coordinador'], 'Módulo para importar participantes desde listas PDF'),
    ('enable_bcv_sync_banner', true, ARRAY['todos'], 'Banner en vivo con la tasa oficial BCV del día'),
    ('enable_surveys', true, ARRAY['todos'], 'Módulo de encuestas y evaluaciones estudiantiles'),
    ('enable_asistencia_bluetooth', true, ARRAY['profesor', 'coordinador', 'super_admin'], 'Impresión y vinculación Bluetooth para comprobantes'),
    ('enable_export_excel', true, ARRAY['coordinador', 'super_admin'], 'Exportación masiva de reportes en formato Excel'),
    ('enable_umby_floating_assistant', true, ARRAY['todos'], 'Botón flotante del asistente inteligente Umby'),
    ('enable_auto_enrollment_verification', true, ARRAY['operador_inscripcion', 'coordinador', 'super_admin'], 'Verificación en tiempo real de cupos y duplicados en inscripciones')
ON CONFLICT (flag_key) DO UPDATE 
SET is_enabled = EXCLUDED.is_enabled, target_roles = EXCLUDED.target_roles, description = EXCLUDED.description;

-- 5. REGLAS EN RPC: LÓGICA DE NEGOCIO ENCAPSULADA EN POSTGRESQL

-- A) Validación de inscripción de alumnas gobernada por parámetros remotos
CREATE OR REPLACE FUNCTION public.validar_inscripcion_alumna(
    p_curso_id UUID,
    p_cedula TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_max_cupos INT := 35;
    v_curso_cupo_max INT;
    v_admision_abierta BOOLEAN := true;
    v_require_dni BOOLEAN := true;
    v_inscritos_actuales INT := 0;
    v_ya_inscrita BOOLEAN := false;
    v_curso_nombre TEXT;
    v_config_val JSONB;
BEGIN
    SELECT value INTO v_config_val FROM public.app_remote_config WHERE key = 'max_students_per_course';
    IF v_config_val IS NOT NULL THEN
        v_max_cupos := (v_config_val #>> '{}')::INT;
    END IF;

    SELECT value INTO v_config_val FROM public.app_remote_config WHERE key = 'require_dni_verification';
    IF v_config_val IS NOT NULL THEN
        v_require_dni := (v_config_val #>> '{}')::BOOLEAN;
    END IF;

    IF v_require_dni THEN
        IF p_cedula IS NULL OR length(trim(p_cedula)) < 5 THEN
            RETURN jsonb_build_object(
                'valido', false,
                'codigo', 'CEDULA_INVALIDA',
                'motivo', 'La cédula de identidad es obligatoria y debe tener formato válido.'
            );
        END IF;
    END IF;

    SELECT nombre, cupo_maximo, admision_abierta 
    INTO v_curso_nombre, v_curso_cupo_max, v_admision_abierta
    FROM public.cursos 
    WHERE id = p_curso_id;

    IF v_curso_nombre IS NULL THEN
        RETURN jsonb_build_object(
            'valido', false,
            'codigo', 'CURSO_NO_EXISTE',
            'motivo', 'El curso especificado no existe o no se encuentra activo.'
        );
    END IF;

    IF v_admision_abierta IS FALSE THEN
        RETURN jsonb_build_object(
            'valido', false,
            'codigo', 'ADMISION_CERRADA',
            'motivo', format('Las inscripciones para el curso %s están cerradas administrativamente.', v_curso_nombre)
        );
    END IF;

    IF v_curso_cupo_max IS NOT NULL AND v_curso_cupo_max > 0 THEN
        v_max_cupos := v_curso_cupo_max;
    END IF;

    SELECT count(*) INTO v_inscritos_actuales 
    FROM public.inscripciones 
    WHERE curso_id = p_curso_id;

    IF v_inscritos_actuales >= v_max_cupos THEN
        RETURN jsonb_build_object(
            'valido', false,
            'codigo', 'CUPO_AGOTADO',
            'motivo', format('El curso %s ha alcanzado su límite máximo de %s participantes.', v_curso_nombre, v_max_cupos),
            'inscritos_actuales', v_inscritos_actuales,
            'cupo_maximo', v_max_cupos
        );
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.inscripciones i
        JOIN public.alumnos a ON i.alumno_id = a.id
        WHERE i.curso_id = p_curso_id AND trim(lower(a.cedula)) = trim(lower(p_cedula))
    ) INTO v_ya_inscrita;

    IF v_ya_inscrita THEN
        RETURN jsonb_build_object(
            'valido', false,
            'codigo', 'ALUMNA_YA_INSCRITA',
            'motivo', 'La participante con esta cédula ya se encuentra matriculada en este curso.'
        );
    END IF;

    RETURN jsonb_build_object(
        'valido', true,
        'codigo', 'OK',
        'motivo', 'Validación exitosa. Cupo disponible.',
        'curso_nombre', v_curso_nombre,
        'inscritos_actuales', v_inscritos_actuales,
        'cupo_maximo', v_max_cupos
    );
END;
$$;

-- B) RPC consolidado para carga ultra-rápida en el cliente Flutter
CREATE OR REPLACE FUNCTION public.obtener_bundle_configuracion_remota()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_configs JSONB;
    v_flags JSONB;
BEGIN
    SELECT jsonb_object_agg(key, jsonb_build_object('value', value, 'category', category, 'updated_at', updated_at))
    INTO v_configs
    FROM public.app_remote_config;

    SELECT jsonb_object_agg(flag_key, jsonb_build_object('is_enabled', is_enabled, 'target_roles', target_roles, 'updated_at', updated_at))
    INTO v_flags
    FROM public.feature_flags;

    RETURN jsonb_build_object(
        'configs', COALESCE(v_configs, '{}'::jsonb),
        'flags', COALESCE(v_flags, '{}'::jsonb),
        'server_timestamp', now()
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.validar_inscripcion_alumna(UUID, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.obtener_bundle_configuracion_remota() TO authenticated, anon;

-- 6. PUBLICACIÓN REALTIME PARA CAMBIOS EN TIEMPO REAL
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'app_remote_config'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.app_remote_config;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'feature_flags'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.feature_flags;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;
