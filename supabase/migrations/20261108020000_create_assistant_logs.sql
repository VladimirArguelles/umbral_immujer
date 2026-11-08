-- ==============================================================================
-- MIGRACIÓN: Tabla de Auditoría e Historial de Interacciones IA (assistant_logs)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.assistant_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    user_nombre TEXT,
    user_rol TEXT,
    modulo_id TEXT NOT NULL,
    user_question TEXT NOT NULL,
    bot_answer TEXT NOT NULL,
    modelo_ia TEXT NOT NULL DEFAULT 'gemini-2.5-flash',
    ticket_id UUID REFERENCES public.tickets_soporte(id) ON DELETE SET NULL,
    metadatos JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices para búsquedas y ordenamiento en tiempo real
CREATE INDEX IF NOT EXISTS idx_assistant_logs_created_at ON public.assistant_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_assistant_logs_modulo ON public.assistant_logs(modulo_id);
CREATE INDEX IF NOT EXISTS idx_assistant_logs_user_id ON public.assistant_logs(user_id);

-- Habilitar Row Level Security (RLS) de forma obligatoria
ALTER TABLE public.assistant_logs ENABLE ROW LEVEL SECURITY;

-- 1. Política de Lectura para Super Admin (Auditoría Global)
DROP POLICY IF EXISTS "assistant_logs_super_admin_select" ON public.assistant_logs;
CREATE POLICY "assistant_logs_super_admin_select"
ON public.assistant_logs
FOR SELECT
TO authenticated
USING (
    (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
);

-- 2. Política de Lectura para Usuarios Propietarios
DROP POLICY IF EXISTS "assistant_logs_user_select" ON public.assistant_logs;
CREATE POLICY "assistant_logs_user_select"
ON public.assistant_logs
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
);

-- 3. Política de Inserción para Usuarios Autenticados
DROP POLICY IF EXISTS "assistant_logs_insert" ON public.assistant_logs;
CREATE POLICY "assistant_logs_insert"
ON public.assistant_logs
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id 
    OR user_id IS NULL 
    OR (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
);
