-- ============================================================================
-- MIGRACIÓN: Vistas SQL Consolidadas para Reportes Académicos y de Asistencia
-- Archivo: 20261105013000_create_reportes_views.sql
-- ============================================================================

-- 1. Vista de Alumnos Inscritos por Curso
CREATE OR REPLACE VIEW public.view_reporte_alumnos_curso AS
SELECT 
  c.id AS curso_id,
  c.nombre AS curso_nombre,
  c.horario,
  COALESCE(pf.nombre_completo, 'Sin asignar') AS profesor_nombre,
  a.id AS alumno_id,
  a.cedula,
  a.nombre_completo,
  a.correo,
  a.telefono,
  i.estado AS estado_inscripcion,
  i.created_at AS fecha_inscripcion
FROM public.inscripciones i
JOIN public.cursos c ON i.curso_id = c.id
JOIN public.alumnos a ON i.alumno_id = a.id
LEFT JOIN public.perfiles pf ON c.profesor_id = pf.id;

-- 2. Vista de Profesores Asignados por Curso
CREATE OR REPLACE VIEW public.view_reporte_profesores_cursos AS
SELECT 
  c.id AS curso_id,
  c.nombre AS curso_nombre,
  c.horario,
  pf.id AS profesor_id,
  COALESCE(pf.nombre_completo, 'Sin asignar') AS profesor_nombre,
  pf.cedula,
  pf.telefono,
  pf.correo,
  COUNT(i.id) AS total_alumnos
FROM public.cursos c
LEFT JOIN public.perfiles pf ON c.profesor_id = pf.id
LEFT JOIN public.inscripciones i ON c.id = i.curso_id
GROUP BY c.id, c.nombre, c.horario, pf.id, pf.nombre_completo, pf.cedula, pf.telefono, pf.correo;

-- 3. Vista de Temas y Módulos Impartidos por Curso
CREATE OR REPLACE VIEW public.view_reporte_temas_curso AS
SELECT 
  c.id AS curso_id,
  c.nombre AS curso_nombre,
  t.id AS tema_id,
  t.orden,
  t.modulo,
  t.titulo,
  t.descripcion
FROM public.temas_curso t
JOIN public.cursos c ON t.curso_id = c.id;

-- 4. Vista de Comportamiento de Asistencia Resumida por Curso y Día
CREATE OR REPLACE VIEW public.view_reporte_asistencia_resumen AS
SELECT 
  c.id AS curso_id,
  c.nombre AS curso_nombre,
  a.fecha,
  COUNT(a.id) AS total_alumnos,
  COUNT(a.id) FILTER (WHERE a.estado = 'Presente') AS total_presentes,
  COUNT(a.id) FILTER (WHERE a.estado = 'Ausente') AS total_ausentes,
  ROUND((COUNT(a.id) FILTER (WHERE a.estado = 'Presente')::numeric / NULLIF(COUNT(a.id), 0)) * 100, 2) AS porcentaje_asistencia
FROM public.asistencia a
JOIN public.cursos c ON a.curso_id = c.id
GROUP BY c.id, c.nombre, a.fecha;

-- 5. Vista de Detalle de Asistencia por Alumno y Curso (Sábana de Asistencia)
CREATE OR REPLACE VIEW public.view_reporte_asistencia_detallada AS
SELECT 
  c.id AS curso_id,
  c.nombre AS curso_nombre,
  al.id AS alumno_id,
  al.cedula,
  al.nombre_completo,
  a.fecha,
  a.estado
FROM public.asistencia a
JOIN public.cursos c ON a.curso_id = c.id
JOIN public.alumnos al ON a.alumno_id = al.id;

-- Conceder permisos de lectura
GRANT SELECT ON public.view_reporte_alumnos_curso TO anon, authenticated, service_role;
GRANT SELECT ON public.view_reporte_profesores_cursos TO anon, authenticated, service_role;
GRANT SELECT ON public.view_reporte_temas_curso TO anon, authenticated, service_role;
GRANT SELECT ON public.view_reporte_asistencia_resumen TO anon, authenticated, service_role;
GRANT SELECT ON public.view_reporte_asistencia_detallada TO anon, authenticated, service_role;
