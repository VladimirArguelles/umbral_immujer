-- Migración: Funciones de consulta y gestión de usuarios registrados para Super Admin
-- Fecha: 2026-11-08
-- Objetivo: Permitir al Super Admin consultar y actualizar usuarios autenticados con sus perfiles

CREATE OR REPLACE FUNCTION public.obtener_usuarios_registrados()
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    nombre_completo TEXT,
    cedula TEXT,
    telefono TEXT,
    rol TEXT,
    created_at TIMESTAMPTZ,
    last_sign_in_at TIMESTAMPTZ,
    email_confirmed_at TIMESTAMPTZ,
    avatar_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    IF auth.uid() IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE public.perfiles.id = auth.uid() AND public.perfiles.rol = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Acceso denegado: solo Super Admin puede consultar usuarios registrados';
    END IF;

    RETURN QUERY
    SELECT 
        u.id AS user_id,
        u.email::TEXT,
        COALESCE(p.nombre_completo, u.raw_user_meta_data->>'nombre_completo', 'Usuario')::TEXT,
        COALESCE(p.cedula, u.raw_user_meta_data->>'cedula')::TEXT,
        COALESCE(p.telefono, u.raw_user_meta_data->>'telefono')::TEXT,
        COALESCE(p.rol, u.raw_user_meta_data->>'rol', u.raw_user_meta_data->>'role', 'alumno')::TEXT,
        u.created_at,
        u.last_sign_in_at,
        u.email_confirmed_at,
        p.avatar_url::TEXT
    FROM auth.users u
    LEFT JOIN public.perfiles p ON u.id = p.id OR u.id = p.user_id
    ORDER BY u.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.obtener_usuarios_registrados() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obtener_usuarios_registrados() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_update_user(
    p_user_id UUID,
    p_nombre_completo TEXT,
    p_cedula TEXT,
    p_telefono TEXT,
    p_rol TEXT
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    IF auth.uid() IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE public.perfiles.id = auth.uid() AND public.perfiles.rol = 'super_admin'
    ) THEN
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

REVOKE ALL ON FUNCTION public.admin_update_user(UUID, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_user(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

-- Política de eliminación segura para Super Admin en tabla perfiles
DROP POLICY IF EXISTS "perfiles_delete_superadmin" ON public.perfiles;
CREATE POLICY "perfiles_delete_superadmin" ON public.perfiles
FOR DELETE
TO authenticated
USING (public.is_super_admin());

-- Función RPC para eliminar usuario y credenciales en Supabase Auth
CREATE OR REPLACE FUNCTION public.admin_delete_user(p_user_id UUID)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE public.perfiles.id = auth.uid() AND public.perfiles.rol = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Acceso denegado: solo Super Admin puede eliminar usuarios';
    END IF;

    IF auth.uid() = p_user_id THEN
        RAISE EXCEPTION 'Operación no permitida: no puedes eliminar tu propia cuenta de Super Admin';
    END IF;

    DELETE FROM public.perfiles WHERE id = p_user_id OR user_id = p_user_id;
    DELETE FROM auth.users WHERE id = p_user_id;

    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_delete_user(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(UUID) TO authenticated, service_role;

