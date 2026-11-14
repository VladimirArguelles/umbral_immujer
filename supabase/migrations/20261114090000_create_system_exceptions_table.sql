-- ==============================================================================
-- MIGRACIÓN: Tabla de Captura y Diagnóstico Centralizado de Excepciones del Sistema
-- Protocolo UMBRAL: Monitoreo Técnico Exclusivo y Telemetría Segura
-- ==============================================================================

-- 1. TABLA: system_exceptions
CREATE TABLE IF NOT EXISTS public.system_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('error', 'warning', 'critical')),
    module VARCHAR(100) NOT NULL DEFAULT 'general',
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Asegurar columnas si la tabla ya existía parcialmente
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'system_exceptions' 
        AND column_name = 'metadata'
    ) THEN
        ALTER TABLE public.system_exceptions ADD COLUMN metadata JSONB NOT NULL DEFAULT '{}'::jsonb;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'system_exceptions' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.system_exceptions ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 2. ÍNDICES DE RENDIMIENTO Y CONSULTA TELEMÉTRICA
CREATE INDEX IF NOT EXISTS idx_system_exceptions_timestamp ON public.system_exceptions(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_system_exceptions_severity ON public.system_exceptions(severity);
CREATE INDEX IF NOT EXISTS idx_system_exceptions_module ON public.system_exceptions(module);

-- 3. TRIGGER AUDITABLE PARA updated_at
CREATE OR REPLACE FUNCTION public.fn_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_system_exceptions_updated_at ON public.system_exceptions;
CREATE TRIGGER trg_system_exceptions_updated_at
BEFORE UPDATE ON public.system_exceptions
FOR EACH ROW EXECUTE FUNCTION public.fn_touch_updated_at();

-- 4. POLÍTICAS DE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.system_exceptions ENABLE ROW LEVEL SECURITY;

-- Lectura exclusiva para Super Administradores
DROP POLICY IF EXISTS "system_exceptions_read_super_admin" ON public.system_exceptions;
CREATE POLICY "system_exceptions_read_super_admin"
ON public.system_exceptions
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE perfiles.id = auth.uid()
        AND perfiles.rol = 'super_admin'
    )
);

-- Eliminación y Gestión exclusiva para Super Administradores
DROP POLICY IF EXISTS "system_exceptions_delete_super_admin" ON public.system_exceptions;
CREATE POLICY "system_exceptions_delete_super_admin"
ON public.system_exceptions
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE perfiles.id = auth.uid()
        AND perfiles.rol = 'super_admin'
    )
);

DROP POLICY IF EXISTS "system_exceptions_update_super_admin" ON public.system_exceptions;
CREATE POLICY "system_exceptions_update_super_admin"
ON public.system_exceptions
FOR UPDATE
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

-- Inserción controlada para clientes authenticated y anon (captura de errores en runtime)
DROP POLICY IF EXISTS "system_exceptions_insert_authenticated" ON public.system_exceptions;
CREATE POLICY "system_exceptions_insert_authenticated"
ON public.system_exceptions
FOR INSERT
TO authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "system_exceptions_insert_anon" ON public.system_exceptions;
CREATE POLICY "system_exceptions_insert_anon"
ON public.system_exceptions
FOR INSERT
TO anon
WITH CHECK (true);

-- 5. FUNCIÓN RPC DE REGISTRO RÁPIDO CON DEFENDER SECURITY
CREATE OR REPLACE FUNCTION public.registrar_excepcion_sistema(
    p_error_message TEXT,
    p_severity VARCHAR DEFAULT 'error',
    p_module VARCHAR DEFAULT 'general',
    p_stack_trace TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_new_id UUID;
BEGIN
    INSERT INTO public.system_exceptions (
        severity,
        module,
        error_message,
        stack_trace,
        user_id,
        metadata
    )
    VALUES (
        p_severity,
        p_module,
        p_error_message,
        p_stack_trace,
        auth.uid(),
        p_metadata
    )
    RETURNING id INTO v_new_id;

    RETURN v_new_id;
EXCEPTION
    WHEN OTHERS THEN
        -- Protección para evitar que un fallo en telemetría bloquee la ejecución cliente
        RETURN NULL;
END;
$$;
