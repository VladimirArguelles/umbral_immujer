-- ==============================================================================
-- MIGRACIÓN BASE CANÓNICA DEL ESQUEMA UMBRAL IMMUJER (Zero-Dependency Baseline)
-- Archivo: 20261001000000_schema_baseline_umbral.sql
-- Objetivo: Garantizar que cualquier réplica, entorno CI/CD o despliegue en limpio
--           pueda levantar la estructura relacional completa desde el repositorio.
-- ==============================================================================

-- 1. Extensiones requeridas
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Función de utilidad para actualizar columnas updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- 2. Tabla Canónica de Perfiles de Usuario (public.perfiles)
CREATE TABLE IF NOT EXISTS public.perfiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    nombre_completo TEXT NOT NULL,
    cedula TEXT UNIQUE,
    telefono TEXT,
    correo TEXT UNIQUE,
    rol TEXT NOT NULL DEFAULT 'alumno' CHECK (rol IN ('alumno', 'profesor', 'coordinador', 'super_admin', 'operador_inscripcion')),
    avatar_url TEXT,
    acceso_activo BOOLEAN NOT NULL DEFAULT true,
    fcm_token TEXT,
    fcm_updated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_perfiles_user_id ON public.perfiles(user_id);
CREATE INDEX IF NOT EXISTS idx_perfiles_rol ON public.perfiles(rol);
CREATE INDEX IF NOT EXISTS idx_perfiles_cedula ON public.perfiles(cedula);

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;

-- 3. Tabla de Profesores (public.profesores)
CREATE TABLE IF NOT EXISTS public.profesores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    perfil_id UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    nombre_completo TEXT NOT NULL,
    cedula TEXT UNIQUE,
    telefono TEXT,
    correo TEXT,
    especialidad TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profesores_perfil_id ON public.profesores(perfil_id);
ALTER TABLE public.profesores ENABLE ROW LEVEL SECURITY;

-- 4. Tabla de Cursos Formativos (public.cursos)
CREATE TABLE IF NOT EXISTS public.cursos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    profesor_id UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    horario TEXT,
    dia_semana INT CHECK (dia_semana BETWEEN 1 AND 7),
    aula TEXT,
    cupo_maximo INT NOT NULL DEFAULT 35,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cursos_profesor_id ON public.cursos(profesor_id);
ALTER TABLE public.cursos ENABLE ROW LEVEL SECURITY;

-- 5. Tabla de Temas Curriculares (public.temas_curso)
CREATE TABLE IF NOT EXISTS public.temas_curso (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    curso_id UUID REFERENCES public.cursos(id) ON DELETE CASCADE,
    numero_tema INT NOT NULL,
    titulo TEXT NOT NULL,
    descripcion TEXT,
    completado BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_curso_tema UNIQUE(curso_id, numero_tema)
);

CREATE INDEX IF NOT EXISTS idx_temas_curso_curso_id ON public.temas_curso(curso_id);
ALTER TABLE public.temas_curso ENABLE ROW LEVEL SECURITY;

-- 6. Tabla de Alumnas Matriculadas (public.alumnos)
CREATE TABLE IF NOT EXISTS public.alumnos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    perfil_id UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    nombre_completo TEXT NOT NULL,
    cedula TEXT NOT NULL UNIQUE,
    telefono TEXT,
    correo TEXT,
    curso TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_alumnos_cedula ON public.alumnos(cedula);
CREATE INDEX IF NOT EXISTS idx_alumnos_perfil_id ON public.alumnos(perfil_id);
ALTER TABLE public.alumnos ENABLE ROW LEVEL SECURITY;

-- 7. Tabla de Inscripciones a Cursos (public.inscripciones)
CREATE TABLE IF NOT EXISTS public.inscripciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES public.alumnos(id) ON DELETE CASCADE,
    curso_id UUID NOT NULL REFERENCES public.cursos(id) ON DELETE CASCADE,
    estado TEXT NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa', 'retirada', 'completada', 'suspendida')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_alumno_curso UNIQUE(alumno_id, curso_id)
);

CREATE INDEX IF NOT EXISTS idx_inscripciones_alumno_id ON public.inscripciones(alumno_id);
CREATE INDEX IF NOT EXISTS idx_inscripciones_curso_id ON public.inscripciones(curso_id);
ALTER TABLE public.inscripciones ENABLE ROW LEVEL SECURITY;

-- 8. Tabla de Control de Asistencia (public.asistencia)
CREATE TABLE IF NOT EXISTS public.asistencia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES public.alumnos(id) ON DELETE CASCADE,
    curso_id UUID NOT NULL REFERENCES public.cursos(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    estado TEXT NOT NULL DEFAULT 'presente' CHECK (estado IN ('presente', 'ausente', 'justificada', 'tardanza')),
    observacion TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_asistencia_alumno_curso_fecha UNIQUE(alumno_id, curso_id, fecha)
);

CREATE INDEX IF NOT EXISTS idx_asistencia_fecha ON public.asistencia(fecha);
CREATE INDEX IF NOT EXISTS idx_asistencia_alumno_curso ON public.asistencia(alumno_id, curso_id);
ALTER TABLE public.asistencia ENABLE ROW LEVEL SECURITY;

-- 9. Tabla de Configuración General Clave-Valor (public.configuracion_general)
CREATE TABLE IF NOT EXISTS public.configuracion_general (
    id BIGSERIAL PRIMARY KEY,
    clave TEXT NOT NULL UNIQUE,
    valor JSONB NOT NULL,
    descripcion TEXT,
    creado_en TIMESTAMPTZ DEFAULT now(),
    actualizado_en TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_configuracion_general_clave ON public.configuracion_general(clave);
ALTER TABLE public.configuracion_general ENABLE ROW LEVEL SECURITY;

-- 10. Tabla de Tickets de Soporte Técnico (public.tickets_soporte)
CREATE TABLE IF NOT EXISTS public.tickets_soporte (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    titulo TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    categoria TEXT NOT NULL DEFAULT 'general',
    prioridad TEXT NOT NULL DEFAULT 'media' CHECK (prioridad IN ('baja', 'media', 'alta', 'critica')),
    estado TEXT NOT NULL DEFAULT 'abierto' CHECK (estado IN ('abierto', 'en_proceso', 'resuelto', 'cerrado')),
    asignado_a UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tickets_soporte_usuario ON public.tickets_soporte(usuario_id);
CREATE INDEX IF NOT EXISTS idx_tickets_soporte_estado ON public.tickets_soporte(estado);
ALTER TABLE public.tickets_soporte ENABLE ROW LEVEL SECURITY;

-- 11. Tabla de Notificaciones del Sistema (public.notificaciones)
CREATE TABLE IF NOT EXISTS public.notificaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_origen_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    rol_destino TEXT NOT NULL DEFAULT 'todos',
    usuario_destino_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    titulo TEXT NOT NULL,
    mensaje TEXT NOT NULL,
    tipo TEXT NOT NULL DEFAULT 'general',
    leido BOOLEAN NOT NULL DEFAULT false,
    datos JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_rol_destino ON public.notificaciones(rol_destino);
CREATE INDEX IF NOT EXISTS idx_notificaciones_leido ON public.notificaciones(leido);
CREATE INDEX IF NOT EXISTS idx_notificaciones_created_at ON public.notificaciones(created_at DESC);
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

-- 12. Tabla de Auditoría IA (public.assistant_logs)
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

CREATE INDEX IF NOT EXISTS idx_assistant_logs_created_at ON public.assistant_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_assistant_logs_modulo ON public.assistant_logs(modulo_id);
ALTER TABLE public.assistant_logs ENABLE ROW LEVEL SECURITY;
