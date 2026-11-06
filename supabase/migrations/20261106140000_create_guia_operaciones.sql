-- Migración: Crear tabla guia_operaciones y políticas RLS para manual interactivo inteligente
CREATE TABLE IF NOT EXISTS public.guia_operaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rol_permitido TEXT[] NOT NULL DEFAULT ARRAY['coordinador', 'super_admin'],
  modulo TEXT NOT NULL,
  titulo_operacion TEXT NOT NULL,
  instrucciones_paso_a_paso TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger de updated_at
CREATE OR REPLACE FUNCTION public.handle_guia_operaciones_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_guia_operaciones_updated_at ON public.guia_operaciones;
CREATE TRIGGER trigger_guia_operaciones_updated_at
  BEFORE UPDATE ON public.guia_operaciones
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_guia_operaciones_updated_at();

-- Habilitar RLS
ALTER TABLE public.guia_operaciones ENABLE ROW LEVEL SECURITY;

-- Políticas RLS
DROP POLICY IF EXISTS "guia_operaciones_select_authenticated" ON public.guia_operaciones;
CREATE POLICY "guia_operaciones_select_authenticated" ON public.guia_operaciones
  FOR SELECT TO authenticated
  USING (
    rol_permitido @> ARRAY[(SELECT perfiles.rol FROM public.perfiles WHERE perfiles.id = auth.uid())]
    OR (SELECT perfiles.rol FROM public.perfiles WHERE perfiles.id = auth.uid()) = 'super_admin'
    OR rol_permitido @> ARRAY['todos']
  );

DROP POLICY IF EXISTS "guia_operaciones_admin_all" ON public.guia_operaciones;
CREATE POLICY "guia_operaciones_admin_all" ON public.guia_operaciones
  FOR ALL TO authenticated
  USING (
    (SELECT perfiles.rol FROM public.perfiles WHERE perfiles.id = auth.uid()) = 'super_admin'
  )
  WITH CHECK (
    (SELECT perfiles.rol FROM public.perfiles WHERE perfiles.id = auth.uid()) = 'super_admin'
  );
