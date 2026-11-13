-- ==============================================================================
-- MIGRACIÓN: Hardening Core, Columnas FCM, RPCs de Inscripciones/Perfiles y Storage
-- Archivo: 20261113040000_core_hardening_and_rpcs.sql
-- ==============================================================================

-- 1. Agregar columnas fcm_token y fcm_updated_at a public.perfiles de forma idempotente
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'perfiles' AND column_name = 'fcm_token'
    ) THEN
        ALTER TABLE public.perfiles ADD COLUMN fcm_token TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'perfiles' AND column_name = 'fcm_updated_at'
    ) THEN
        ALTER TABLE public.perfiles ADD COLUMN fcm_updated_at TIMESTAMPTZ;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_perfiles_fcm_token ON public.perfiles(fcm_token) WHERE fcm_token IS NOT NULL;

-- Asegurar política RLS para que el usuario autenticado pueda actualizar su propio perfil y fcm_token
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' AND tablename = 'perfiles' AND policyname = 'perfiles_update_own'
    ) THEN
        CREATE POLICY "perfiles_update_own"
        ON public.perfiles
        FOR UPDATE
        TO authenticated
        USING (auth.uid() = id OR auth.uid() = user_id)
        WITH CHECK (auth.uid() = id OR auth.uid() = user_id);
    END IF;
END $$;


-- 2. Función RPC: notificar_cambio_perfil
CREATE OR REPLACE FUNCTION public.notificar_cambio_perfil(
    p_usuario_id UUID,
    p_nombre TEXT,
    p_correo TEXT,
    p_telefono TEXT,
    p_rol TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_destinatarios TEXT[] := ARRAY['coordinador', 'profesor', 'super_admin'];
    v_dest TEXT;
    v_count INT := 0;
BEGIN
    FOREACH v_dest IN ARRAY v_destinatarios LOOP
        INSERT INTO public.notificaciones (
            usuario_origen_id,
            rol_destino,
            titulo,
            mensaje,
            tipo,
            leido,
            datos,
            created_at
        ) VALUES (
            p_usuario_id,
            v_dest,
            'Perfil Actualizado: ' || COALESCE(p_nombre, 'Usuario'),
            'El usuario ' || COALESCE(p_nombre, 'Usuario') || ' (' || COALESCE(p_rol, 'usuario') || 
            ') ha actualizado sus datos personales (Correo: ' || COALESCE(p_correo, 'N/A') || 
            ', Teléfono: ' || COALESCE(p_telefono, 'N/A') || ').',
            'perfil_actualizado',
            false,
            jsonb_build_object(
                'usuario_id', p_usuario_id,
                'nombre', p_nombre,
                'correo', p_correo,
                'telefono', p_telefono,
                'rol', p_rol
            ),
            now()
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'notificaciones_creadas', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.notificar_cambio_perfil(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon;


-- 3. Función RPC: sync_inscripciones_batch para sincronizaciones atómicas en lote
CREATE OR REPLACE FUNCTION public.sync_inscripciones_batch(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cursos_meta JSONB := COALESCE(payload->'cursos_meta', '[]'::jsonb);
    v_temas_curso JSONB := COALESCE(payload->'temas_curso', '[]'::jsonb);
    v_alumnos JSONB := COALESCE(payload->'alumnos', '[]'::jsonb);
    v_inscripciones JSONB := COALESCE(payload->'inscripciones', '[]'::jsonb);
    v_asistencias JSONB := COALESCE(payload->'asistencias', '[]'::jsonb);
    
    elem JSONB;
    v_alumnos_count INT := 0;
    v_inscripciones_count INT := 0;
    v_asistencias_count INT := 0;
    v_curso_id UUID;
    v_alumno_id UUID;
BEGIN
    -- A. Procesar Alumnos en lote
    FOR elem IN SELECT * FROM jsonb_array_elements(v_alumnos) LOOP
        INSERT INTO public.alumnos (
            cedula,
            nombre_completo,
            correo,
            telefono,
            curso,
            created_at,
            updated_at
        ) VALUES (
            elem->>'cedula',
            elem->>'nombre_completo',
            elem->>'correo',
            elem->>'telefono',
            elem->>'curso',
            COALESCE((elem->>'created_at')::timestamptz, now()),
            now()
        )
        ON CONFLICT (cedula) DO UPDATE
        SET nombre_completo = COALESCE(EXCLUDED.nombre_completo, public.alumnos.nombre_completo),
            correo = COALESCE(EXCLUDED.correo, public.alumnos.correo),
            telefono = COALESCE(EXCLUDED.telefono, public.alumnos.telefono),
            curso = COALESCE(EXCLUDED.curso, public.alumnos.curso),
            updated_at = now();
            
        v_alumnos_count := v_alumnos_count + 1;
    END LOOP;

    -- B. Procesar Inscripciones en lote
    FOR elem IN SELECT * FROM jsonb_array_elements(v_inscripciones) LOOP
        -- Resolver ID de alumno por cédula si no viene id explícito
        IF elem ? 'alumno_id' AND (elem->>'alumno_id') IS NOT NULL THEN
            v_alumno_id := (elem->>'alumno_id')::uuid;
        ELSE
            SELECT id INTO v_alumno_id FROM public.alumnos WHERE cedula = (elem->>'cedula') LIMIT 1;
        END IF;

        -- Resolver ID de curso por nombre si no viene id explícito
        IF elem ? 'curso_id' AND (elem->>'curso_id') IS NOT NULL THEN
            v_curso_id := (elem->>'curso_id')::uuid;
        ELSE
            SELECT id INTO v_curso_id FROM public.cursos WHERE nombre ILIKE (elem->>'curso') LIMIT 1;
        END IF;

        IF v_alumno_id IS NOT NULL AND v_curso_id IS NOT NULL THEN
            INSERT INTO public.inscripciones (
                alumno_id,
                curso_id,
                estado,
                created_at,
                updated_at
            ) VALUES (
                v_alumno_id,
                v_curso_id,
                COALESCE(elem->>'estado', 'activa'),
                COALESCE((elem->>'fecha_inscripcion')::timestamptz, now()),
                now()
            )
            ON CONFLICT (alumno_id, curso_id) DO UPDATE
            SET estado = EXCLUDED.estado,
                updated_at = now();

            v_inscripciones_count := v_inscripciones_count + 1;
        END IF;
    END LOOP;

    -- C. Procesar Asistencias en lote
    FOR elem IN SELECT * FROM jsonb_array_elements(v_asistencias) LOOP
        IF elem ? 'alumno_id' AND (elem->>'alumno_id') IS NOT NULL THEN
            v_alumno_id := (elem->>'alumno_id')::uuid;
        ELSE
            SELECT id INTO v_alumno_id FROM public.alumnos WHERE cedula = (elem->>'cedula') LIMIT 1;
        END IF;

        IF elem ? 'curso_id' AND (elem->>'curso_id') IS NOT NULL THEN
            v_curso_id := (elem->>'curso_id')::uuid;
        ELSE
            SELECT id INTO v_curso_id FROM public.cursos WHERE nombre ILIKE (elem->>'curso') LIMIT 1;
        END IF;

        IF v_alumno_id IS NOT NULL AND v_curso_id IS NOT NULL AND (elem ? 'fecha') THEN
            INSERT INTO public.asistencia (
                alumno_id,
                curso_id,
                fecha,
                estado,
                created_at,
                updated_at
            ) VALUES (
                v_alumno_id,
                v_curso_id,
                (elem->>'fecha')::date,
                COALESCE(elem->>'estado', 'presente'),
                now(),
                now()
            )
            ON CONFLICT DO NOTHING;

            v_asistencias_count := v_asistencias_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'alumnos_procesados', v_alumnos_count,
        'inscripciones_procesadas', v_inscripciones_count,
        'asistencias_procesadas', v_asistencias_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_inscripciones_batch(JSONB) TO authenticated, anon;


-- 4. Creación y Políticas RLS para Buckets de Storage
DO $$
BEGIN
    -- Bucket avatars: Público
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
        'avatars',
        'avatars',
        true,
        5242880, -- 5MB
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
    )
    ON CONFLICT (id) DO UPDATE
    SET public = true,
        file_size_limit = 5242880,
        allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

    -- Bucket comprobantes: Privado
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
        'comprobantes',
        'comprobantes',
        false,
        10485760, -- 10MB
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
    )
    ON CONFLICT (id) DO UPDATE
    SET public = false,
        file_size_limit = 10485760,
        allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];

    -- Bucket justificativos: Privado
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
        'justificativos',
        'justificativos',
        false,
        10485760, -- 10MB
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
    )
    ON CONFLICT (id) DO UPDATE
    SET public = false,
        file_size_limit = 10485760,
        allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
END $$;

-- Políticas de Storage en storage.objects
DO $$
BEGIN
    -- A. avatars: Lectura pública
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'avatars_public_select'
    ) THEN
        CREATE POLICY "avatars_public_select" ON storage.objects
        FOR SELECT TO public
        USING (bucket_id = 'avatars');
    END IF;

    -- B. avatars: Subida autenticada
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'avatars_auth_upload'
    ) THEN
        CREATE POLICY "avatars_auth_upload" ON storage.objects
        FOR INSERT TO authenticated
        WITH CHECK (bucket_id = 'avatars');
    END IF;

    -- C. comprobantes: Subida para autenticados
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'comprobantes_auth_upload'
    ) THEN
        CREATE POLICY "comprobantes_auth_upload" ON storage.objects
        FOR INSERT TO authenticated
        WITH CHECK (bucket_id = 'comprobantes');
    END IF;

    -- D. comprobantes: Lectura para propietario o roles administrativos
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'comprobantes_owner_or_admin_select'
    ) THEN
        CREATE POLICY "comprobantes_owner_or_admin_select" ON storage.objects
        FOR SELECT TO authenticated
        USING (
            bucket_id = 'comprobantes' AND (
                auth.uid() = owner OR
                EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol IN ('super_admin', 'coordinador', 'operador_inscripcion'))
            )
        );
    END IF;

    -- E. justificativos: Subida para autenticados
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'justificativos_auth_upload'
    ) THEN
        CREATE POLICY "justificativos_auth_upload" ON storage.objects
        FOR INSERT TO authenticated
        WITH CHECK (bucket_id = 'justificativos');
    END IF;

    -- F. justificativos: Lectura para propietario, profesores o coordinación
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'justificativos_owner_or_admin_select'
    ) THEN
        CREATE POLICY "justificativos_owner_or_admin_select" ON storage.objects
        FOR SELECT TO authenticated
        USING (
            bucket_id = 'justificativos' AND (
                auth.uid() = owner OR
                EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol IN ('super_admin', 'coordinador', 'profesor'))
            )
        );
    END IF;
END $$;
