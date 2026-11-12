-- ============================================================================
-- MIGRACIÓN: Hardening de permisos RPC (revocar anon) y optimización RLS
-- Archivo: 20261111214000_hardening_inscripciones_rls_and_rpc_grants.sql
-- ============================================================================

REVOKE ALL ON FUNCTION public.is_profesor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_profesor() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_operador_inscripcion_activo() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_operador_inscripcion_activo() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.can_manage_inscripciones() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_manage_inscripciones() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.obtener_cursos_con_cupos() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.obtener_cursos_con_cupos() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.registrar_inscripcion_aspirante(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_inscripcion_aspirante(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.obtener_operadores_inscripcion() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.obtener_operadores_inscripcion() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_toggle_operador_acceso(UUID, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_toggle_operador_acceso(UUID, BOOLEAN) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_create_operador_inscripcion(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_create_operador_inscripcion(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_set_inscripciones_activas(BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_inscripciones_activas(BOOLEAN) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.validate_inscripcion_cupo() FROM PUBLIC, anon;

DROP POLICY IF EXISTS "alumnos_update_authorized" ON public.alumnos;
CREATE POLICY "alumnos_update_authorized" ON public.alumnos
FOR UPDATE
TO authenticated
USING (
    public.is_coordinador()
    OR public.is_profesor()
    OR public.is_operador_inscripcion_activo()
    OR (SELECT auth.uid()) = user_id
    OR (user_id IS NULL AND correo IS NOT NULL AND lower(correo) = lower((SELECT auth.jwt()) ->> 'email'))
)
WITH CHECK (
    public.is_coordinador()
    OR public.is_profesor()
    OR public.is_operador_inscripcion_activo()
    OR (SELECT auth.uid()) = user_id
);

INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261111214000', 'hardening_inscripciones_rls_and_rpc_grants')
ON CONFLICT (version) DO NOTHING;
