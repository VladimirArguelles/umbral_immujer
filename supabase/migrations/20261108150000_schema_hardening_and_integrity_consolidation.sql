-- ============================================================================
-- MIGRACIÓN: Hardening Integral, Unicidad y Consistencia del Esquema Relacional
-- Archivo: 20261108150000_schema_hardening_and_integrity_consolidation.sql
-- Proyecto: UMBRAL - IMMUJER
-- ============================================================================

-- 1. Función reutilizable para actualización automática de updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Asegurar campos de trazabilidad updated_at
ALTER TABLE public.tasa_cambiaria ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.configuracion_general ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- 3. Triggers de actualización de updated_at
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_tasa_cambiaria_updated_at') THEN
        CREATE TRIGGER tr_tasa_cambiaria_updated_at
            BEFORE UPDATE ON public.tasa_cambiaria
            FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at_column();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_configuracion_general_updated_at') THEN
        CREATE TRIGGER tr_configuracion_general_updated_at
            BEFORE UPDATE ON public.configuracion_general
            FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at_column();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_tickets_soporte_updated_at') THEN
        CREATE TRIGGER tr_tickets_soporte_updated_at
            BEFORE UPDATE ON public.tickets_soporte
            FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at_column();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_soporte_conocimiento_updated_at') THEN
        CREATE TRIGGER tr_soporte_conocimiento_updated_at
            BEFORE UPDATE ON public.soporte_conocimiento
            FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at_column();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_configuraciones_impresora_updated_at') THEN
        CREATE TRIGGER tr_configuraciones_impresora_updated_at
            BEFORE UPDATE ON public.configuraciones_impresora
            FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at_column();
    END IF;
END $$;

-- 4. Unicidad compuesta en justificativos_asistencia
CREATE UNIQUE INDEX IF NOT EXISTS unique_justificativo_dia 
ON public.justificativos_asistencia (curso_id, alumno_id, fecha);

-- 5. Índices para claves foráneas y búsquedas recurrentes
CREATE INDEX IF NOT EXISTS idx_alumnos_user_id ON public.alumnos(user_id);
CREATE INDEX IF NOT EXISTS idx_profesores_user_id ON public.profesores(user_id);
CREATE INDEX IF NOT EXISTS idx_perfiles_user_id ON public.perfiles(user_id);
CREATE INDEX IF NOT EXISTS idx_encuestas_participacion_creada_por ON public.encuestas_participacion(creada_por);
CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario_origen ON public.notificaciones(usuario_origen_id);

-- 6. Enlace canónico de alumnos y profesores hacia perfiles
ALTER TABLE public.alumnos ADD COLUMN IF NOT EXISTS perfil_id UUID REFERENCES public.perfiles(id) ON DELETE SET NULL;
ALTER TABLE public.profesores ADD COLUMN IF NOT EXISTS perfil_id UUID REFERENCES public.perfiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_alumnos_perfil_id ON public.alumnos(perfil_id);
CREATE INDEX IF NOT EXISTS idx_profesores_perfil_id ON public.profesores(perfil_id);

CREATE OR REPLACE FUNCTION public.sync_perfil_id_from_user_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_id IS NOT NULL AND NEW.perfil_id IS NULL THEN
        NEW.perfil_id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_alumnos_sync_perfil_id') THEN
        CREATE TRIGGER tr_alumnos_sync_perfil_id
            BEFORE INSERT OR UPDATE OF user_id ON public.alumnos
            FOR EACH ROW EXECUTE FUNCTION public.sync_perfil_id_from_user_id();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_profesores_sync_perfil_id') THEN
        CREATE TRIGGER tr_profesores_sync_perfil_id
            BEFORE INSERT OR UPDATE OF user_id ON public.profesores
            FOR EACH ROW EXECUTE FUNCTION public.sync_perfil_id_from_user_id();
    END IF;
END $$;

-- 7. Constraints CHECK para catálogos y estados
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_tickets_soporte_estado') THEN
        ALTER TABLE public.tickets_soporte 
        ADD CONSTRAINT chk_tickets_soporte_estado 
        CHECK (estado IN ('abierto', 'en_proceso', 'resuelto', 'cerrado'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_tickets_soporte_severidad') THEN
        ALTER TABLE public.tickets_soporte 
        ADD CONSTRAINT chk_tickets_soporte_severidad 
        CHECK (severidad IN ('baja', 'media', 'alta', 'critica'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_soporte_conocimiento_severidad') THEN
        ALTER TABLE public.soporte_conocimiento 
        ADD CONSTRAINT chk_soporte_conocimiento_severidad 
        CHECK (severidad IN ('baja', 'media', 'alta', 'critica'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_configuraciones_impresora_tipo') THEN
        ALTER TABLE public.configuraciones_impresora 
        ADD CONSTRAINT chk_configuraciones_impresora_tipo 
        CHECK (tipo_conexion IN ('bluetooth', 'usb', 'red', 'wifi'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_assistant_logs_modulo') THEN
        ALTER TABLE public.assistant_logs 
        ADD CONSTRAINT chk_assistant_logs_modulo 
        CHECK (modulo_id IN ('general', 'superadmin', 'coordinador', 'profesor', 'alumnos', 'reportes', 'asistencia', 'encuestas', 'configuracion', 'impresion'));
    END IF;

    -- Roles canónicos en perfiles
    ALTER TABLE public.perfiles DROP CONSTRAINT IF EXISTS perfiles_rol_check;
    ALTER TABLE public.perfiles 
    ADD CONSTRAINT perfiles_rol_check 
    CHECK (rol IN ('alumno', 'profesor', 'coordinador', 'super_admin'));

    -- Asistencia flexible case-insensitive
    ALTER TABLE public.asistencia DROP CONSTRAINT IF EXISTS asistencia_estado_check;
    ALTER TABLE public.asistencia 
    ADD CONSTRAINT asistencia_estado_check 
    CHECK (lower(estado) IN ('presente', 'ausente', 'justificado'));
END $$;

-- 8. Sincronización automática de temas_curso hacia cursos.temas (JSONB cache)
CREATE OR REPLACE FUNCTION public.sync_temas_curso_to_cursos()
RETURNS TRIGGER AS $$
DECLARE
    v_curso_id UUID;
    v_temas JSONB;
BEGIN
    v_curso_id := COALESCE(NEW.curso_id, OLD.curso_id);
    
    SELECT jsonb_agg(titulo ORDER BY orden ASC)
    INTO v_temas
    FROM public.temas_curso
    WHERE curso_id = v_curso_id;

    UPDATE public.cursos
    SET temas = COALESCE(v_temas, '[]'::jsonb),
        updated_at = now()
    WHERE id = v_curso_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_sync_temas_curso_to_cursos') THEN
        CREATE TRIGGER tr_sync_temas_curso_to_cursos
            AFTER INSERT OR UPDATE OR DELETE ON public.temas_curso
            FOR EACH ROW EXECUTE FUNCTION public.sync_temas_curso_to_cursos();
    END IF;
END $$;
