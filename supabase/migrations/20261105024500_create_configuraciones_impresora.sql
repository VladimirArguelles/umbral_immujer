-- Tabla para persistencia de la configuración de impresora por usuario / dispositivo
CREATE TABLE IF NOT EXISTS public.configuraciones_impresora (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    tipo_conexion TEXT NOT NULL CHECK (tipo_conexion IN ('bluetooth', 'red', 'sistema')),
    identificador TEXT NOT NULL,
    nombre_impresora TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Trigger para updated_at automático
CREATE OR REPLACE TRIGGER trg_configuraciones_impresora_updated_at
BEFORE UPDATE ON public.configuraciones_impresora
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Índice para búsquedas rápidas por usuario
CREATE INDEX IF NOT EXISTS idx_config_impresora_user_id ON public.configuraciones_impresora(user_id);

-- Habilitar Row Level Security
ALTER TABLE public.configuraciones_impresora ENABLE ROW LEVEL SECURITY;

-- Políticas RLS: cada usuario gestiona su impresora, super_admin y coordinador tienen acceso administrativo
DROP POLICY IF EXISTS "Los usuarios pueden ver y gestionar su configuracion de impresora" ON public.configuraciones_impresora;
CREATE POLICY "Los usuarios pueden ver y gestionar su configuracion de impresora"
ON public.configuraciones_impresora
FOR ALL
TO authenticated
USING (
    auth.uid() = user_id
    OR (SELECT rol FROM public.perfiles WHERE id = auth.uid()) IN ('super_admin', 'coordinador', 'administrador')
)
WITH CHECK (
    auth.uid() = user_id
    OR (SELECT rol FROM public.perfiles WHERE id = auth.uid()) IN ('super_admin', 'coordinador', 'administrador')
);
