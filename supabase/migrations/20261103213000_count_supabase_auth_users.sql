CREATE OR REPLACE FUNCTION public.count_authenticated_users()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
    SELECT count(*) FROM auth.users;
$$;

REVOKE ALL ON FUNCTION public.count_authenticated_users() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.count_authenticated_users() TO anon, authenticated, service_role;
