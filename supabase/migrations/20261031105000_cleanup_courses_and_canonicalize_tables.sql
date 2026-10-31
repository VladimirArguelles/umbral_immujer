-- ============================================================================
-- MIGRACIÓN: Depuración de Cursos Obsoletos y Canonización de Tablas de Asistencia y Encuestas
-- Archivo: 20261031105000_cleanup_courses_and_canonicalize_tables.sql
-- Proyecto: UMBRAL - IMMUJER
-- ============================================================================

-- 1. Eliminación de los 3 cursos obsoletos y su cascada relacional
DELETE FROM public.cursos 
WHERE nombre ILIKE '%Manualidades y Emprendimiento%' 
   OR nombre ILIKE '%Costura y Confecci%' 
   OR nombre ILIKE '%Panader% y Reposter% Artesanal%';

-- 2. Eliminación de las vistas redundantes que generaban colisiones de nombres
DROP VIEW IF EXISTS public.asistencias CASCADE;
DROP VIEW IF EXISTS public.encuestas CASCADE;

-- 3. Canonización de restricciones y claves foráneas en la tabla 'asistencia'
ALTER TABLE public.asistencia RENAME CONSTRAINT asistencias_pkey TO asistencia_pkey;
ALTER TABLE public.asistencia RENAME CONSTRAINT asistencias_curso_id_fkey TO asistencia_curso_id_fkey;
ALTER TABLE public.asistencia RENAME CONSTRAINT asistencias_alumno_id_fkey TO asistencia_alumno_id_fkey;
ALTER TABLE public.asistencia RENAME CONSTRAINT asistencias_recorded_by_fkey TO asistencia_recorded_by_fkey;
ALTER TABLE public.asistencia RENAME CONSTRAINT asistencias_estado_check TO asistencia_estado_check;

-- 4. Canonización de restricciones y claves foráneas en la tabla 'encuestas_participacion'
ALTER TABLE public.encuestas_participacion RENAME CONSTRAINT encuestas_pkey TO encuestas_participacion_pkey;
ALTER TABLE public.encuestas_participacion RENAME CONSTRAINT encuestas_curso_id_fkey TO encuestas_participacion_curso_id_fkey;
ALTER TABLE public.encuestas_participacion RENAME CONSTRAINT encuestas_creada_por_fkey TO encuestas_participacion_creada_por_fkey;
ALTER TABLE public.encuestas_participacion RENAME CONSTRAINT encuestas_estado_check TO encuestas_participacion_estado_check;
