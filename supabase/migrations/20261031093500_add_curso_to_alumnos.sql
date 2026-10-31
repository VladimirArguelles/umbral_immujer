-- Migración: Añadir columna 'curso' a la tabla alumnos y asignar 'Reposteria Basica'
ALTER TABLE public.alumnos 
ADD COLUMN IF NOT EXISTS curso TEXT;

CREATE INDEX IF NOT EXISTS idx_alumnos_curso 
ON public.alumnos (curso);

UPDATE public.alumnos 
SET curso = 'Reposteria Basica' 
WHERE curso IS NULL;
