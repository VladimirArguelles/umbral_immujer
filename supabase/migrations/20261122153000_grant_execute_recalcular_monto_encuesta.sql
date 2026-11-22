-- Migration: 20261122153000_grant_execute_recalcular_monto_encuesta.sql
-- Descripción: Otorga permisos de ejecución controlados al rol authenticated para recalcular_monto_encuesta y notificar_cambio_perfil
-- Manteniendo revocado el acceso para anon y public.

-- 1. Permisos para recalcular_monto_encuesta
REVOKE EXECUTE ON FUNCTION public.recalcular_monto_encuesta(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.recalcular_monto_encuesta(uuid) TO authenticated;

-- 2. Permisos para notificar_cambio_perfil
REVOKE EXECUTE ON FUNCTION public.notificar_cambio_perfil(uuid, text, text, text, text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.notificar_cambio_perfil(uuid, text, text, text, text) TO authenticated;
