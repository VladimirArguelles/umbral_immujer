-- Migration: 20261104143000_update_bcv_cron_and_trigger.sql
-- AUTOMATED BCV SYNC & TRIGGER ENHANCEMENT

-- 1. Actualizar función trigger para sincronizar USD y EUR en configuracion_general
CREATE OR REPLACE FUNCTION public.actualizar_config_tasa_bcv()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.fecha >= CURRENT_DATE THEN
        INSERT INTO public.configuracion_general (clave, valor, actualizado_en)
        VALUES ('tasa_cambio_oficial', to_jsonb(NEW.tasa_bcv), NOW())
        ON CONFLICT (clave) DO UPDATE
        SET valor = EXCLUDED.valor,
            actualizado_en = NOW();

        INSERT INTO public.configuracion_general (clave, valor, actualizado_en)
        VALUES ('tasa_eur_oficial', to_jsonb(NEW.tasa_eur), NOW())
        ON CONFLICT (clave) DO UPDATE
        SET valor = EXCLUDED.valor,
            actualizado_en = NOW();
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_actualizar_config_tasa_bcv ON public.tasa_cambiaria;
CREATE TRIGGER tr_actualizar_config_tasa_bcv
    AFTER INSERT OR UPDATE ON public.tasa_cambiaria
    FOR EACH ROW
    EXECUTE FUNCTION public.actualizar_config_tasa_bcv();

-- 2. Asegurar extensiones pg_net y pg_cron
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- 3. Limpiar cron jobs previos para sincronización de tasa BCV
DO $$
BEGIN
    PERFORM cron.unschedule('sync-bcv-rate-daily');
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;

DO $$
BEGIN
    PERFORM cron.unschedule('sync-bcv-rate-publication-window');
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;

-- 4. Programación Automática Diaria:
-- Job A: Ejecución matutina a las 9:00 AM hora de Caracas (13:00 UTC) todos los días
SELECT cron.schedule(
    'sync-bcv-rate-daily',
    '0 13 * * *',
    $$
    SELECT net.http_post(
        url := COALESCE(
            current_setting('app.settings.supabase_url', true),
            'https://kkgacvhbcxgoxjpnkxmw.supabase.co'
        ) || '/functions/v1/sync-bcv-rate',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || COALESCE(
                current_setting('app.settings.service_role_key', true),
                current_setting('supabase.service_role_key', true),
                (SELECT valor->>0 FROM public.configuracion_general WHERE clave = 'service_role_key' LIMIT 1),
                'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
            )
        ),
        body := '{}'::jsonb
    );
    $$
);

-- Job B: Ejecución en ventana vespertina de publicación oficial del BCV
-- Cada 15 minutos entre las 4:00 PM y las 7:45 PM hora de Caracas (20:00 - 23:45 UTC) todos los días
SELECT cron.schedule(
    'sync-bcv-rate-publication-window',
    '*/15 20-23 * * *',
    $$
    SELECT net.http_post(
        url := COALESCE(
            current_setting('app.settings.supabase_url', true),
            'https://kkgacvhbcxgoxjpnkxmw.supabase.co'
        ) || '/functions/v1/sync-bcv-rate',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || COALESCE(
                current_setting('app.settings.service_role_key', true),
                current_setting('supabase.service_role_key', true),
                (SELECT valor->>0 FROM public.configuracion_general WHERE clave = 'service_role_key' LIMIT 1),
                'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
            )
        ),
        body := '{}'::jsonb
    );
    $$
);
