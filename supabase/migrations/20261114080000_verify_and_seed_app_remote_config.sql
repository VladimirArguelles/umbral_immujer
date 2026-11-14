-- ==============================================================================
-- MIGRACIÓN: Verificación y Enriquecimiento de app_remote_config y Estados Visuales
-- Protocolo UMBRAL: Control Remoto y Server-Driven UI (Zero-Rebuild)
-- ==============================================================================

-- 1. ASEGURAR TABLA: app_remote_config
CREATE TABLE IF NOT EXISTS public.app_remote_config (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    category VARCHAR(30) NOT NULL CHECK (category IN ('ui', 'business_rule', 'copy', 'general')),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Asegurar columnas created_at y updated_at si la tabla ya existía
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'app_remote_config' 
        AND column_name = 'created_at'
    ) THEN
        ALTER TABLE public.app_remote_config ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT now();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'app_remote_config' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.app_remote_config ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
    END IF;
END $$;

-- 2. ÍNDICE DE BÚSQUEDA RÁPIDA POR CATEGORÍA
CREATE INDEX IF NOT EXISTS idx_remote_config_category ON public.app_remote_config(category);

-- 3. TRIGGER AUDITABLE PARA updated_at
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

-- 4. POLÍTICAS ROW LEVEL SECURITY (RLS)
ALTER TABLE public.app_remote_config ENABLE ROW LEVEL SECURITY;

-- Lectura abierta a todo público (anónimo y autenticado) para bootstrap de UI al abrir la app
DROP POLICY IF EXISTS "remote_config_read_public" ON public.app_remote_config;
CREATE POLICY "remote_config_read_public"
ON public.app_remote_config
FOR SELECT
TO public
USING (true);

-- Modificación restringida exclusivamente al Super Administrador
DROP POLICY IF EXISTS "remote_config_admin_write" ON public.app_remote_config;
CREATE POLICY "remote_config_admin_write"
ON public.app_remote_config
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE perfiles.id = auth.uid()
        AND perfiles.rol = 'super_admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE perfiles.id = auth.uid()
        AND perfiles.rol = 'super_admin'
    )
);

-- 5. SEMILLA INICIAL Y ACTUALIZACIÓN DE VALORES CLAVE DE UI Y CONTROL REMOTO
INSERT INTO public.app_remote_config (key, value, category, description)
VALUES
    -- Colores y Tokens UI
    ('primary_color', '"#E0115F"'::jsonb, 'ui', 'Color primario institucional dinámico (Hexadecimal)'),
    ('accent_color', '"#0BD984"'::jsonb, 'ui', 'Color de acento y éxito neón institucional UMBRAL'),
    ('accent_secondary', '"#3B82F6"'::jsonb, 'ui', 'Color de acento complementario azul tecnológico'),
    ('background_color', '"#0D0714"'::jsonb, 'ui', 'Fondo base principal de la plataforma en modo oscuro'),
    ('card_background', '"#1E293B"'::jsonb, 'ui', 'Fondo base de tarjetas modulares en modo oscuro'),
    
    -- Parámetros Glassmorphic Dinámicos
    ('glassmorphism_blur', '14.0'::jsonb, 'ui', 'Nivel de desenfoque de fondo en tarjetas translúcidas (sigma)'),
    ('glassmorphism_opacity', '0.70'::jsonb, 'ui', 'Opacidad base para tarjetas glassmorphic translúcidas'),
    ('glassmorphism_border_opacity', '0.20'::jsonb, 'ui', 'Opacidad para bordes luminosos de tarjetas glassmorphic'),
    
    -- Textos Clave Institucionales (Server-Driven Copy)
    ('welcome_title', '"Bienvenida a UMBRAL"'::jsonb, 'copy', 'Título principal del landing y bienvenida general'),
    ('welcome_subtitle', '"Plataforma Integral de Capacitación y Gestión Institucional IMMUJER"'::jsonb, 'copy', 'Subtítulo descriptivo institucional'),
    ('landing_headline', '"Empoderamiento, Formación y Autonomía para las Mujeres"'::jsonb, 'copy', 'Titular de la página principal'),
    
    -- Banners y Estados Visuales Reactivos
    ('maintenance_banner', '""'::jsonb, 'copy', 'Mensaje de aviso de mantenimiento global (vacío para desactivar)'),
    ('announcement_banner_enabled', 'false'::jsonb, 'ui', 'Interruptor global para activar el banner superior institucional'),
    ('announcement_banner_text', '"Sistema operativo en línea sincronizado con IMMUJER"'::jsonb, 'copy', 'Texto informativo mostrado en el banner superior reactivo'),
    ('announcement_banner_type', '"info"'::jsonb, 'ui', 'Tipo de banner visual: info, warning, success, maintenance'),
    
    -- Reglas de Negocio Remotas
    ('max_students_per_course', '35'::jsonb, 'business_rule', 'Límite máximo general de alumnas por aula/curso'),
    ('require_dni_verification', 'true'::jsonb, 'business_rule', 'Exigir validación estricta de cédula de identidad en inscripciones'),
    ('allow_late_attendance', 'false'::jsonb, 'business_rule', 'Permitir pases de lista fuera del horario del curso'),
    ('default_practical_contribution_usd', '2.0'::jsonb, 'business_rule', 'Monto sugerido en USD para aporte de clase práctica'),
    
    -- Parámetros de Actualización OTA y GitHub Releases
    ('github_repo_owner', '"VladimirArguelles"'::jsonb, 'general', 'Propietario u organización del repositorio GitHub de releases'),
    ('github_repo_name', '"umbral_immujer"'::jsonb, 'general', 'Nombre del repositorio GitHub para consulta de releases OTA')
ON CONFLICT (key) DO UPDATE 
SET 
    value = EXCLUDED.value, 
    category = EXCLUDED.category, 
    description = EXCLUDED.description,
    updated_at = now();
