-- ============================================================================
-- MIGRACIÓN: Sistema de Solicitudes y Aprobación de Profesores por Coordinación
-- Archivo: 20261101143000_create_solicitudes_aprobacion.sql
-- Proyecto: UMBRAL - IMMUJER
-- ============================================================================

-- 1. Crear tabla solicitudes_aprobacion
CREATE TABLE IF NOT EXISTS public.solicitudes_aprobacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profesor_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
    profesor_nombre TEXT,
    curso_id UUID NOT NULL REFERENCES public.cursos(id) ON DELETE CASCADE,
    curso_nombre TEXT,
    tipo_solicitud TEXT NOT NULL CHECK (
        tipo_solicitud IN (
            'crear_alumno',
            'editar_alumno',
            'eliminar_alumno',
            'crear_tema',
            'editar_tema',
            'eliminar_tema'
        )
    ),
    estado TEXT NOT NULL DEFAULT 'pendiente' CHECK (
        estado IN ('pendiente', 'aprobado', 'rechazado')
    ),
    datos_anteriores JSONB,
    datos_nuevos JSONB NOT NULL,
    motivo TEXT,
    revisado_por UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    fecha_revision TIMESTAMPTZ,
    observacion_revision TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_solicitudes_profesor_id ON public.solicitudes_aprobacion(profesor_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_curso_id ON public.solicitudes_aprobacion(curso_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_estado ON public.solicitudes_aprobacion(estado);
CREATE INDEX IF NOT EXISTS idx_solicitudes_created_at ON public.solicitudes_aprobacion(created_at DESC);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at_solicitudes()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_set_updated_at_solicitudes ON public.solicitudes_aprobacion;
CREATE TRIGGER tr_set_updated_at_solicitudes
    BEFORE UPDATE ON public.solicitudes_aprobacion
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at_solicitudes();

-- Habilitar RLS
ALTER TABLE public.solicitudes_aprobacion ENABLE ROW LEVEL SECURITY;

-- Políticas RLS
DROP POLICY IF EXISTS "solicitudes_select_policy" ON public.solicitudes_aprobacion;
CREATE POLICY "solicitudes_select_policy" ON public.solicitudes_aprobacion
    FOR SELECT TO authenticated
    USING (
        profesor_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.perfiles
            WHERE perfiles.id = auth.uid()
            AND perfiles.rol IN ('coordinador', 'super_admin')
        )
    );

DROP POLICY IF EXISTS "solicitudes_insert_policy" ON public.solicitudes_aprobacion;
CREATE POLICY "solicitudes_insert_policy" ON public.solicitudes_aprobacion
    FOR INSERT TO authenticated
    WITH CHECK (
        profesor_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.perfiles
            WHERE perfiles.id = auth.uid()
            AND perfiles.rol IN ('coordinador', 'super_admin')
        )
    );

DROP POLICY IF EXISTS "solicitudes_update_policy" ON public.solicitudes_aprobacion;
CREATE POLICY "solicitudes_update_policy" ON public.solicitudes_aprobacion
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.perfiles
            WHERE perfiles.id = auth.uid()
            AND perfiles.rol IN ('coordinador', 'super_admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.perfiles
            WHERE perfiles.id = auth.uid()
            AND perfiles.rol IN ('coordinador', 'super_admin')
        )
    );

-- 2. Función RPC para APROBAR solicitud y aplicar cambios atómicamente
CREATE OR REPLACE FUNCTION public.aprobar_solicitud(
    p_solicitud_id UUID,
    p_revisor_id UUID,
    p_observacion TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_solicitud RECORD;
    v_alumno_id UUID;
    v_nombre TEXT;
    v_cedula TEXT;
    v_telefono TEXT;
    v_correo TEXT;
    v_tema TEXT;
    v_tema_viejo TEXT;
    v_curso_id UUID;
    v_temas_arr JSONB;
BEGIN
    SELECT * INTO v_solicitud
    FROM public.solicitudes_aprobacion
    WHERE id = p_solicitud_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Solicitud no encontrada');
    END IF;

    IF v_solicitud.estado <> 'pendiente' THEN
        RETURN jsonb_build_object('success', false, 'message', 'La solicitud ya fue procesada anteriormente');
    END IF;

    v_curso_id := v_solicitud.curso_id;

    -- Aplicar cambio según tipo
    CASE v_solicitud.tipo_solicitud
        WHEN 'crear_alumno' THEN
            v_nombre := v_solicitud.datos_nuevos->>'nombre_completo';
            v_cedula := v_solicitud.datos_nuevos->>'cedula';
            v_telefono := v_solicitud.datos_nuevos->>'telefono';
            v_correo := v_solicitud.datos_nuevos->>'correo';

            -- Insertar o buscar alumno existente
            INSERT INTO public.alumnos (nombre_completo, cedula, telefono, email, curso)
            VALUES (v_nombre, v_cedula, v_telefono, v_correo, v_solicitud.curso_nombre)
            ON CONFLICT (cedula) DO UPDATE
            SET nombre_completo = EXCLUDED.nombre_completo,
                telefono = COALESCE(EXCLUDED.telefono, public.alumnos.telefono),
                curso = COALESCE(EXCLUDED.curso, public.alumnos.curso)
            RETURNING id INTO v_alumno_id;

            -- Inscribir en el curso
            INSERT INTO public.inscripciones (curso_id, alumno_id, estado, deleted_at)
            VALUES (v_curso_id, v_alumno_id, 'activo', NULL)
            ON CONFLICT (curso_id, alumno_id) DO UPDATE
            SET estado = 'activo', deleted_at = NULL;

        WHEN 'editar_alumno' THEN
            v_alumno_id := (v_solicitud.datos_nuevos->>'alumno_id')::UUID;
            v_nombre := v_solicitud.datos_nuevos->>'nombre_completo';
            v_cedula := v_solicitud.datos_nuevos->>'cedula';
            v_telefono := v_solicitud.datos_nuevos->>'telefono';
            v_correo := v_solicitud.datos_nuevos->>'correo';

            UPDATE public.alumnos
            SET nombre_completo = COALESCE(v_nombre, nombre_completo),
                cedula = COALESCE(v_cedula, cedula),
                telefono = COALESCE(v_telefono, telefono),
                email = COALESCE(v_correo, email),
                updated_at = now()
            WHERE id = v_alumno_id;

        WHEN 'eliminar_alumno' THEN
            v_alumno_id := (v_solicitud.datos_nuevos->>'alumno_id')::UUID;

            UPDATE public.inscripciones
            SET estado = 'retirado',
                deleted_at = now()
            WHERE curso_id = v_curso_id
              AND alumno_id = v_alumno_id;

        WHEN 'crear_tema' THEN
            v_tema := v_solicitud.datos_nuevos->>'tema';
            IF v_tema IS NOT NULL AND trim(v_tema) <> '' THEN
                SELECT COALESCE(temas, '[]'::jsonb) INTO v_temas_arr
                FROM public.cursos
                WHERE id = v_curso_id;

                v_temas_arr := v_temas_arr || jsonb_build_array(v_tema);

                UPDATE public.cursos
                SET temas = v_temas_arr,
                    updated_at = now()
                WHERE id = v_curso_id;

                INSERT INTO public.temas_curso (curso_id, titulo, orden)
                VALUES (v_curso_id, v_tema, COALESCE(jsonb_array_length(v_temas_arr), 1));
            END IF;

        WHEN 'editar_tema' THEN
            v_tema_viejo := v_solicitud.datos_anteriores->>'tema';
            v_tema := v_solicitud.datos_nuevos->>'tema';

            SELECT COALESCE(temas, '[]'::jsonb) INTO v_temas_arr
            FROM public.cursos
            WHERE id = v_curso_id;

            -- Reemplazar en array JSONB
            SELECT COALESCE(jsonb_agg(
                CASE WHEN elem #>> '{}' = v_tema_viejo THEN to_jsonb(v_tema)
                     ELSE elem END
            ), '[]'::jsonb)
            INTO v_temas_arr
            FROM jsonb_array_elements(v_temas_arr) elem;

            UPDATE public.cursos
            SET temas = v_temas_arr,
                updated_at = now()
            WHERE id = v_curso_id;

            UPDATE public.temas_curso
            SET titulo = v_tema,
                updated_at = now()
            WHERE curso_id = v_curso_id
              AND titulo = v_tema_viejo;

        WHEN 'eliminar_tema' THEN
            v_tema := v_solicitud.datos_nuevos->>'tema';

            SELECT COALESCE(temas, '[]'::jsonb) INTO v_temas_arr
            FROM public.cursos
            WHERE id = v_curso_id;

            -- Filtrar elemento del array JSONB
            SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
            INTO v_temas_arr
            FROM jsonb_array_elements(v_temas_arr) elem
            WHERE elem #>> '{}' <> v_tema;

            UPDATE public.cursos
            SET temas = v_temas_arr,
                updated_at = now()
            WHERE id = v_curso_id;

            DELETE FROM public.temas_curso
            WHERE curso_id = v_curso_id
              AND titulo = v_tema;
    END CASE;

    -- Actualizar registro de solicitud
    UPDATE public.solicitudes_aprobacion
    SET estado = 'aprobado',
        revisado_por = p_revisor_id,
        fecha_revision = now(),
        observacion_revision = p_observacion,
        updated_at = now()
    WHERE id = p_solicitud_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Solicitud aprobada y aplicada con éxito'
    );
END;
$$;

-- 3. Función RPC para RECHAZAR solicitud
CREATE OR REPLACE FUNCTION public.rechazar_solicitud(
    p_solicitud_id UUID,
    p_revisor_id UUID,
    p_observacion TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.solicitudes_aprobacion
    SET estado = 'rechazado',
        revisado_por = p_revisor_id,
        fecha_revision = now(),
        observacion_revision = p_observacion,
        updated_at = now()
    WHERE id = p_solicitud_id
      AND estado = 'pendiente';

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Solicitud no encontrada o ya procesada');
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Solicitud rechazada correctamente');
END;
$$;
