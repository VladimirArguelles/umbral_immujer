-- ============================================================================
-- MIGRACIÓN: Estructura de Temas de Curso, Pre-registro Docente y Carga Académica
-- Archivo: 20261031102500_create_temas_and_populate_courses_and_teachers.sql
-- Proyecto: UMBRAL - IMMUJER
-- ============================================================================

-- 1. Añadir columna temas JSONB a la tabla cursos
ALTER TABLE public.cursos 
ADD COLUMN IF NOT EXISTS temas JSONB DEFAULT '[]'::jsonb;

-- 2. Crear tabla normalizada de temas de curso
CREATE TABLE IF NOT EXISTS public.temas_curso (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    curso_id UUID NOT NULL REFERENCES public.cursos(id) ON DELETE CASCADE,
    orden INT NOT NULL DEFAULT 1,
    modulo TEXT,
    titulo TEXT NOT NULL,
    descripcion TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_temas_curso_curso_id ON public.temas_curso(curso_id);
CREATE INDEX IF NOT EXISTS idx_temas_curso_orden ON public.temas_curso(curso_id, orden);

-- Habilitar RLS
ALTER TABLE public.temas_curso ENABLE ROW LEVEL SECURITY;

-- Políticas RLS
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'temas_curso' AND policyname = 'temas_curso_select_all'
    ) THEN
        CREATE POLICY "temas_curso_select_all" ON public.temas_curso
            FOR SELECT TO public USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'temas_curso' AND policyname = 'temas_curso_insert_admin'
    ) THEN
        CREATE POLICY "temas_curso_insert_admin" ON public.temas_curso
            FOR INSERT TO authenticated WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.perfiles
                    WHERE perfiles.id = auth.uid()
                    AND perfiles.rol IN ('coordinador', 'super_admin', 'profesor')
                )
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'temas_curso' AND policyname = 'temas_curso_update_admin'
    ) THEN
        CREATE POLICY "temas_curso_update_admin" ON public.temas_curso
            FOR UPDATE TO authenticated USING (
                EXISTS (
                    SELECT 1 FROM public.perfiles
                    WHERE perfiles.id = auth.uid()
                    AND perfiles.rol IN ('coordinador', 'super_admin', 'profesor')
                )
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'temas_curso' AND policyname = 'temas_curso_delete_admin'
    ) THEN
        CREATE POLICY "temas_curso_delete_admin" ON public.temas_curso
            FOR DELETE TO authenticated USING (
                EXISTS (
                    SELECT 1 FROM public.perfiles
                    WHERE perfiles.id = auth.uid()
                    AND perfiles.rol IN ('coordinador', 'super_admin')
                )
            );
    END IF;
END $$;

-- Trigger para updated_at en temas_curso
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'tr_temas_curso_updated_at'
    ) THEN
        CREATE TRIGGER tr_temas_curso_updated_at
        BEFORE UPDATE ON public.temas_curso
        FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;
END $$;
