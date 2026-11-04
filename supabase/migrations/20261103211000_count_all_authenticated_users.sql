CREATE OR REPLACE FUNCTION public.count_authenticated_users()
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'Solo Super Admin puede consultar esta métrica.'
            USING ERRCODE = '42501';
    END IF;

    RETURN (
        SELECT COUNT(*)
        FROM auth.users AS auth_user
        WHERE auth_user.last_sign_in_at IS NOT NULL
    );
END;
$$;

REVOKE ALL ON FUNCTION public.count_authenticated_users() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.count_authenticated_users() TO authenticated;
