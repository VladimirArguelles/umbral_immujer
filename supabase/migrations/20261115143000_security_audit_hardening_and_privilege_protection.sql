-- ==============================================================================
-- Migración: Endurecimiento Integral de Seguridad AppSec y Control de Acceso
-- 1. Protección contra escalada de privilegios en public.perfiles (Trigger & RLS)
-- 2. Corrección de bypass de autenticación en admin_update_user y RPCs administrativas
-- 3. Revocación de permisos de ejecución anónima en funciones críticas
-- 4. Blindaje del bucket storage 'updates' (eliminación de subida anónima)
-- 5. Endurecimiento de RLS en asistencia y respuestas_encuesta
-- 6. Configuración de search_path seguro en funciones SECURITY DEFINER
-- 7. Corrección de vista view_reporte_inscripciones (security_invoker = true)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TRIGGER DE PROTECCIÓN DE ROLES EN PUBLIC.PERFILES
-- Evita que cualquier usuario no-superadmin altere su propio rol o el de otros.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tr_fn_prevent_unauthorized_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF OLD.rol IS DISTINCT FROM NEW.rol THEN
        -- Permitir el cambio únicamente si el ejecutor es super_admin, postgres o service_role
        IF NOT public.is_super_admin() AND current_user NOT IN ('postgres', 'service_role') THEN
            RAISE EXCEPTION 'Acceso denegado: No tienes autorización para modificar roles de usuario.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_prevent_unauthorized_role_change ON public.perfiles;
CREATE TRIGGER tr_prevent_unauthorized_role_change
BEFORE UPDATE ON public.perfiles
FOR EACH ROW
EXECUTE FUNCTION public.tr_fn_prevent_unauthorized_role_change();

-- Reforzar política RLS de actualización en perfiles
DROP POLICY IF EXISTS "perfiles_update_own" ON public.perfiles;
CREATE POLICY "perfiles_update_own" ON public.perfiles
FOR UPDATE TO public
USING ((auth.uid() = id) OR is_coordinador() OR is_super_admin())
WITH CHECK ((auth.uid() = id) OR is_coordinador() OR is_super_admin());


-- ------------------------------------------------------------------------------
-- 2. CORRECCIÓN DE LA FUNCIÓN admin_update_user (Eliminar bypass de auth.uid() null)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_update_user(
    p_user_id uuid,
    p_nombre_completo text,
    p_cedula text,
    p_telefono text,
    p_rol text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Verificación estricta: solo super_admin o service_role
    IF NOT public.is_super_admin() AND current_user NOT IN ('postgres', 'service_role') THEN
        RAISE EXCEPTION 'Acceso denegado: solo Super Admin puede actualizar usuarios';
    END IF;

    -- 1. Actualizar o insertar en perfiles
    INSERT INTO public.perfiles (id, user_id, nombre_completo, cedula, telefono, rol, updated_at)
    VALUES (p_user_id, p_user_id, p_nombre_completo, p_cedula, p_telefono, p_rol, now())
    ON CONFLICT (id) DO UPDATE
    SET 
        nombre_completo = EXCLUDED.nombre_completo,
        cedula = EXCLUDED.cedula,
        telefono = EXCLUDED.telefono,
        rol = EXCLUDED.rol,
        updated_at = now();

    -- 2. Sincronizar en auth.users metadata
    UPDATE auth.users
    SET raw_user_meta_data = 
        COALESCE(raw_user_meta_data, '{}'::jsonb) || 
        jsonb_build_object(
            'nombre_completo', p_nombre_completo,
            'cedula', p_cedula,
            'telefono', p_telefono,
            'rol', p_rol,
            'role', p_rol
        )
    WHERE id = p_user_id;

    RETURN true;
END;
$$;


-- ------------------------------------------------------------------------------
-- 3. CORRECCIÓN DE LA FUNCIÓN promover_a_super_admin
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.promover_a_super_admin(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    IF NOT public.is_super_admin() AND current_user NOT IN ('postgres', 'service_role') THEN
        RAISE EXCEPTION 'Acceso denegado: solo Super Admin puede promover usuarios';
    END IF;

    SELECT id INTO v_user_id FROM auth.users WHERE LOWER(email) = LOWER(p_email);
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Usuario no encontrado en auth.users');
    END IF;

    UPDATE auth.users
    SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"rol":"super_admin"}'::jsonb
    WHERE id = v_user_id;

    UPDATE public.perfiles
    SET rol = 'super_admin', updated_at = now()
    WHERE id = v_user_id;

    RETURN jsonb_build_object('success', true, 'message', 'Usuario promovido a super_admin exitosamente', 'user_id', v_user_id);
END;
$$;


-- ------------------------------------------------------------------------------
-- 4. CORRECCIÓN DE inscribir_alumno_por_cedula (Verificación de permisos)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.inscribir_alumno_por_cedula(p_cedula text, p_nombre_curso text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_alumno_id uuid;
    v_curso_id uuid;
    v_inscripcion_id uuid;
BEGIN
    IF NOT public.can_manage_inscripciones() AND current_user NOT IN ('postgres', 'service_role') THEN
        RAISE EXCEPTION 'Acceso denegado: no tienes permisos para gestionar inscripciones.';
    END IF;

    SELECT id INTO v_alumno_id
    FROM public.alumnos
    WHERE regexp_replace(cedula, '\D', '', 'g') = regexp_replace(p_cedula, '\D', '', 'g')
    LIMIT 1;

    IF v_alumno_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT id INTO v_curso_id
    FROM public.cursos
    WHERE nombre ILIKE '%' || p_nombre_curso || '%'
       OR p_nombre_curso ILIKE '%' || nombre || '%'
    LIMIT 1;

    IF v_curso_id IS NULL THEN
        INSERT INTO public.cursos (nombre, estado, created_at, updated_at)
        VALUES (p_nombre_curso, 'activo', NOW(), NOW())
        RETURNING id INTO v_curso_id;
    END IF;

    INSERT INTO public.inscripciones (curso_id, alumno_id, estado, created_at, updated_at)
    VALUES (v_curso_id, v_alumno_id, 'activo', NOW(), NOW())
    ON CONFLICT (curso_id, alumno_id) DO UPDATE
    SET updated_at = NOW(),
        estado = 'activo'
    RETURNING id INTO v_inscripcion_id;

    RETURN v_inscripcion_id;
END;
$$;


-- ------------------------------------------------------------------------------
-- 5. REVOCACIÓN DE PERMISOS ANÓNIMOS (ANON/PUBLIC) EN FUNCIONES ADMINISTRATIVAS
-- ------------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.promover_a_super_admin(text) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.admin_update_user(uuid, text, text, text, text) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.admin_delete_user(uuid) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.admin_set_curso_cupo(uuid, integer, boolean) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.admin_set_inscripciones_periodo(boolean, date, date) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.aprobar_solicitud(uuid, uuid, text) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.rechazar_solicitud(uuid, uuid, text) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.get_registered_users() FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.obtener_usuarios_registrados() FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.obtener_diagnostico_sistema() FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.sync_inscripciones_batch(jsonb) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.inscribir_alumno_por_cedula(text, text) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.verificar_configuracion_dispositivo(text) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.actualizar_config_tasa_bcv() FROM anon, public;

GRANT EXECUTE ON FUNCTION public.promover_a_super_admin(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_curso_cupo(uuid, integer, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_inscripciones_periodo(boolean, date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aprobar_solicitud(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rechazar_solicitud(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_registered_users() TO authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_usuarios_registrados() TO authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_diagnostico_sistema() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_inscripciones_batch(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inscribir_alumno_por_cedula(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verificar_configuracion_dispositivo(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.actualizar_config_tasa_bcv() TO authenticated;


-- ------------------------------------------------------------------------------
-- 6. ASIGNACIÓN DE SEARCH_PATH SEGURO EN FUNCIONES SECURITY DEFINER
-- ------------------------------------------------------------------------------
ALTER FUNCTION public.update_updated_at_column() SET search_path = public, pg_temp;
ALTER FUNCTION public.tr_fn_recalcular_encuesta() SET search_path = public, pg_temp;
ALTER FUNCTION public.auto_confirm_user_trigger() SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_perfiles_email_correo() SET search_path = public, pg_temp;
ALTER FUNCTION public.actualizar_config_tasa_bcv() SET search_path = public, pg_temp;
ALTER FUNCTION public.recalcular_monto_encuesta(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.set_updated_at_solicitudes() SET search_path = public, pg_temp;
ALTER FUNCTION public.aprobar_solicitud(uuid, uuid, text) SET search_path = public, pg_temp;
ALTER FUNCTION public.rechazar_solicitud(uuid, uuid, text) SET search_path = public, pg_temp;
ALTER FUNCTION public.notificar_cambio_perfil(uuid, text, text, text, text) SET search_path = public, pg_temp;
ALTER FUNCTION public.tr_alumnos_auto_inscribir() SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_updated_at_column() SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_perfil_id_from_user_id() SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_temas_curso_to_cursos() SET search_path = public, pg_temp;
ALTER FUNCTION public.is_super_admin() SET search_path = public, pg_temp;
ALTER FUNCTION public.is_coordinador() SET search_path = public, pg_temp;
ALTER FUNCTION public.is_profesor() SET search_path = public, pg_temp;
ALTER FUNCTION public.is_operador_inscripcion_activo() SET search_path = public, pg_temp;
ALTER FUNCTION public.can_manage_inscripciones() SET search_path = public, pg_temp;


-- ------------------------------------------------------------------------------
-- 7. ENDURECIMIENTO DE VISTA DE REPORTES (SECURITY INVOKER)
-- ------------------------------------------------------------------------------
ALTER VIEW public.view_reporte_inscripciones SET (security_invoker = true);


-- ------------------------------------------------------------------------------
-- 8. ENDURECIMIENTO DEL BUCKET STORAGE 'updates'
-- Elimina subida y actualización anónima; restringe exclusivamente a super_admin.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "updates_anon_insert" ON storage.objects;
DROP POLICY IF EXISTS "updates_anon_update" ON storage.objects;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'updates_superadmin_insert'
  ) THEN
    CREATE POLICY "updates_superadmin_insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'updates' AND (
        EXISTS (
          SELECT 1 FROM public.perfiles
          WHERE perfiles.id = auth.uid() AND perfiles.rol = 'super_admin'
        )
      )
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'updates_superadmin_update'
  ) THEN
    CREATE POLICY "updates_superadmin_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
      bucket_id = 'updates' AND (
        EXISTS (
          SELECT 1 FROM public.perfiles
          WHERE perfiles.id = auth.uid() AND perfiles.rol = 'super_admin'
        )
      )
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'updates_superadmin_delete'
  ) THEN
    CREATE POLICY "updates_superadmin_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (
      bucket_id = 'updates' AND (
        EXISTS (
          SELECT 1 FROM public.perfiles
          WHERE perfiles.id = auth.uid() AND perfiles.rol = 'super_admin'
        )
      )
    );
  END IF;
END $$;


-- ------------------------------------------------------------------------------
-- 9. ENDURECIMIENTO DE POLÍTICAS EN asistencia Y respuestas_encuesta
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "asistencias_insert_prof" ON public.asistencia;
DROP POLICY IF EXISTS "asistencias_update_prof" ON public.asistencia;

CREATE POLICY "asistencias_insert_authorized" ON public.asistencia
FOR INSERT TO authenticated
WITH CHECK (
    is_coordinador() OR is_super_admin() OR EXISTS (
        SELECT 1 FROM public.cursos c
        LEFT JOIN public.profesores p ON c.profesor_id = p.id
        WHERE c.id = asistencia.curso_id
          AND (c.profesor_id = auth.uid() OR p.user_id = auth.uid() OR p.id = auth.uid())
    )
);

CREATE POLICY "asistencias_update_authorized" ON public.asistencia
FOR UPDATE TO authenticated
USING (
    is_coordinador() OR is_super_admin() OR EXISTS (
        SELECT 1 FROM public.cursos c
        LEFT JOIN public.profesores p ON c.profesor_id = p.id
        WHERE c.id = asistencia.curso_id
          AND (c.profesor_id = auth.uid() OR p.user_id = auth.uid() OR p.id = auth.uid())
    )
)
WITH CHECK (
    is_coordinador() OR is_super_admin() OR EXISTS (
        SELECT 1 FROM public.cursos c
        LEFT JOIN public.profesores p ON c.profesor_id = p.id
        WHERE c.id = asistencia.curso_id
          AND (c.profesor_id = auth.uid() OR p.user_id = auth.uid() OR p.id = auth.uid())
    )
);

DROP POLICY IF EXISTS "respuestas_update_user" ON public.respuestas_encuesta;

CREATE POLICY "respuestas_update_authorized" ON public.respuestas_encuesta
FOR UPDATE TO authenticated
USING (
    is_coordinador() OR is_super_admin() OR
    (alumno_id IN (SELECT a.id FROM public.alumnos a WHERE a.user_id = auth.uid())) OR
    EXISTS (
        SELECT 1 FROM public.encuestas_participacion ep
        JOIN public.cursos c ON ep.curso_id = c.id
        LEFT JOIN public.profesores p ON c.profesor_id = p.id
        WHERE ep.id = respuestas_encuesta.encuesta_id
          AND (c.profesor_id = auth.uid() OR p.user_id = auth.uid() OR p.id = auth.uid())
    )
)
WITH CHECK (
    is_coordinador() OR is_super_admin() OR
    (alumno_id IN (SELECT a.id FROM public.alumnos a WHERE a.user_id = auth.uid())) OR
    EXISTS (
        SELECT 1 FROM public.encuestas_participacion ep
        JOIN public.cursos c ON ep.curso_id = c.id
        LEFT JOIN public.profesores p ON c.profesor_id = p.id
        WHERE ep.id = respuestas_encuesta.encuesta_id
          AND (c.profesor_id = auth.uid() OR p.user_id = auth.uid() OR p.id = auth.uid())
    )
);
