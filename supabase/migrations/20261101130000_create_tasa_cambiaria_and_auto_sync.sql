-- Migration: 20261101130000_create_tasa_cambiaria_and_auto_sync.sql
-- STEP 1: DATABASE MIGRATION SCHEMA (SQL)

-- 1. Crear tabla tasa_cambiaria
CREATE TABLE IF NOT EXISTS public.tasa_cambiaria (
    fecha DATE PRIMARY KEY,
    tasa_bcv NUMERIC(12, 4) NOT NULL,
    tasa_eur NUMERIC(12, 4) NOT NULL,
    creado_en TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Asegurar columna de tasa usada en encuestas_participacion si no existe
ALTER TABLE public.encuestas_participacion 
ADD COLUMN IF NOT EXISTS tasa_bcv_usada NUMERIC(12, 4);

-- 2. Trigger Function actualizar_config_tasa_bcv()
-- When a row is inserted or updated in tasa_cambiaria with fecha >= CURRENT_DATE,
-- automatically update the valor field in public.configuracion_general WHERE clave = 'tasa_cambio_oficial'.
CREATE OR REPLACE FUNCTION public.actualizar_config_tasa_bcv()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.fecha >= CURRENT_DATE THEN
        UPDATE public.configuracion_general
        SET valor = to_jsonb(NEW.tasa_bcv),
            actualizado_en = NOW()
        WHERE clave = 'tasa_cambio_oficial';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_actualizar_config_tasa_bcv ON public.tasa_cambiaria;
CREATE TRIGGER tr_actualizar_config_tasa_bcv
    AFTER INSERT OR UPDATE ON public.tasa_cambiaria
    FOR EACH ROW
    EXECUTE FUNCTION public.actualizar_config_tasa_bcv();

-- 3. Row-Level Security (RLS) on tasa_cambiaria
ALTER TABLE public.tasa_cambiaria ENABLE ROW LEVEL SECURITY;

-- Allow public read access (SELECT) for authenticated and anonymous users
DROP POLICY IF EXISTS "Permitir lectura publica de tasa cambiaria" ON public.tasa_cambiaria;
CREATE POLICY "Permitir lectura publica de tasa cambiaria"
    ON public.tasa_cambiaria
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Restrict write access (INSERT/UPDATE) exclusively to the service_role
DROP POLICY IF EXISTS "Restringir escritura a service_role" ON public.tasa_cambiaria;
CREATE POLICY "Restringir escritura a service_role"
    ON public.tasa_cambiaria
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 4. Actualización de recalcular_monto_encuesta:
-- Divide el monto en USD entre los alumnos confirmados y multiplica por la tasa BCV del día,
-- resultando en el monto individual a cancelar en Bolívares (Bs).
CREATE OR REPLACE FUNCTION public.recalcular_monto_encuesta(p_encuesta_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total INT;
    v_costo_usd NUMERIC(12, 2);
    v_tasa_bcv NUMERIC(12, 4);
    v_monto_ind_bs NUMERIC(12, 2);
BEGIN
    -- Alumnos confirmados
    SELECT COUNT(*) INTO v_total
    FROM public.respuestas_encuesta
    WHERE encuesta_id = p_encuesta_id AND asistira = true;

    -- Presupuesto en USD y tasa BCV de la encuesta
    SELECT costo_total_insumos, tasa_bcv_usada INTO v_costo_usd, v_tasa_bcv
    FROM public.encuestas_participacion
    WHERE id = p_encuesta_id;

    -- Obtener la tasa oficial BCV si no está establecida
    IF v_tasa_bcv IS NULL OR v_tasa_bcv <= 0 THEN
        SELECT tasa_bcv INTO v_tasa_bcv
        FROM public.tasa_cambiaria
        ORDER BY fecha DESC
        LIMIT 1;

        IF v_tasa_bcv IS NULL OR v_tasa_bcv <= 0 THEN
            SELECT (valor::text)::numeric INTO v_tasa_bcv
            FROM public.configuracion_general
            WHERE clave = 'tasa_cambio_oficial';
        END IF;

        IF v_tasa_bcv IS NULL OR v_tasa_bcv <= 0 THEN
            v_tasa_bcv := 1.0000;
        END IF;
    END IF;

    -- Cálculo: (Presupuesto USD / Alumnos Confirmados) * Tasa BCV = Monto en Bs.
    IF v_total > 0 THEN
        v_monto_ind_bs := ROUND(((v_costo_usd / v_total) * v_tasa_bcv), 2);
    ELSE
        v_monto_ind_bs := 0.00;
    END IF;

    UPDATE public.encuestas_participacion
    SET total_confirmados = v_total,
        monto_individual_calculado = v_monto_ind_bs,
        tasa_bcv_usada = v_tasa_bcv,
        updated_at = NOW()
    WHERE id = p_encuesta_id;

    UPDATE public.respuestas_encuesta
    SET monto_asignado = CASE WHEN asistira THEN v_monto_ind_bs ELSE 0.00 END,
        updated_at = NOW()
    WHERE encuesta_id = p_encuesta_id;
END;
$$;
