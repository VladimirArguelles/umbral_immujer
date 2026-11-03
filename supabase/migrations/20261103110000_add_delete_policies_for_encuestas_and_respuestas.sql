-- ==============================================================================
-- Migración: Políticas RLS para DELETE en encuestas_participacion y respuestas_encuesta
-- Fecha: 2026-11-03
-- ==============================================================================

-- 1. Asegurar política de eliminación en encuestas_participacion
DROP POLICY IF EXISTS "encuestas_delete_policy" ON public.encuestas_participacion;

CREATE POLICY "encuestas_delete_policy" ON public.encuestas_participacion
FOR DELETE
TO public
USING (
  is_coordinador() 
  OR creada_por = auth.uid() 
  OR EXISTS (
    SELECT 1 FROM public.cursos 
    WHERE cursos.id = encuestas_participacion.curso_id 
      AND (
        cursos.profesor_id = auth.uid() 
        OR cursos.profesor_id IN (
          SELECT p.id FROM public.profesores p WHERE p.user_id = auth.uid()
        )
      )
  )
  OR EXISTS (
    SELECT 1 FROM public.perfiles
    WHERE perfiles.id = auth.uid()
      AND perfiles.rol IN ('profesor', 'coordinador', 'super_admin')
  )
);

-- 2. Asegurar política de eliminación en respuestas_encuesta
DROP POLICY IF EXISTS "respuestas_delete_policy" ON public.respuestas_encuesta;

CREATE POLICY "respuestas_delete_policy" ON public.respuestas_encuesta
FOR DELETE
TO public
USING (
  is_coordinador()
  OR EXISTS (
    SELECT 1 FROM public.encuestas_participacion ep
    WHERE ep.id = respuestas_encuesta.encuesta_id
      AND (
        ep.creada_por = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.cursos c
          WHERE c.id = ep.curso_id 
            AND (
              c.profesor_id = auth.uid() 
              OR c.profesor_id IN (
                SELECT p.id FROM public.profesores p WHERE p.user_id = auth.uid()
              )
            )
        )
      )
  )
  OR EXISTS (
    SELECT 1 FROM public.perfiles
    WHERE perfiles.id = auth.uid()
      AND perfiles.rol IN ('profesor', 'coordinador', 'super_admin')
  )
  OR alumno_id IN (
    SELECT a.id FROM public.alumnos a WHERE a.user_id = auth.uid()
  )
);
