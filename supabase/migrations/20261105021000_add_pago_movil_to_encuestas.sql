-- Migración para añadir datos de Pago Móvil a encuestas_participacion
ALTER TABLE public.encuestas_participacion
ADD COLUMN IF NOT EXISTS pago_movil_cedula text,
ADD COLUMN IF NOT EXISTS pago_movil_telefono text,
ADD COLUMN IF NOT EXISTS pago_movil_banco text;
