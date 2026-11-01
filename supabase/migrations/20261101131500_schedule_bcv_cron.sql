-- Migration: 20261101131500_schedule_bcv_cron.sql
-- STEP 3: AUTOMATED SCHEDULING (CRON TRIGGER)

-- 1. Habilitar extensiones pg_net y pg_cron en el esquema extensions
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- 2. Eliminar job previo si existe para evitar duplicados
DO $$
BEGIN
    PERFORM cron.unschedule('sync-bcv-rate-daily');
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;

-- 3. Programar cron job diario a las 9:00 AM hora de Caracas (13:00 UTC)
-- Invoca la Edge Function sync-bcv-rate mediante net.http_post
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
