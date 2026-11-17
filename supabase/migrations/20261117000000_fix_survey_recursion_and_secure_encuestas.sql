-- ==============================================================================
-- MIGRACIÓN: Corrección de Recursión Infinita (54001) en Encuestas y Aportes
-- Elimina bucle cíclico en tr_after_respuesta_encuesta y recalcular_monto_encuesta
-- Optimiza políticas RLS para Alumnos y Modo Super Admin
-- ==============================================================================

-- 1. CORRECCIÓN Y CORTE DE PROFUNDIDAD EN tr_fn_recalcular_encuesta
CREATE OR REPLACE FUNCTION public.tr_fn_recalcular_encuesta()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Corte inmediato de recursión si ya estamos dentro de un trigger anidado
    IF pg_trigger_depth() > 1 THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    -- En operaciones UPDATE, solo recalcular si cambió el valor de 'asistira'
    IF TG_OP = 'UPDATE' THEN
        IF (NEW.asistira IS NOT DISTINCT FROM OLD.asistira) THEN
            RETURN NEW;
        END IF;
    END IF;

    -- Ejecutar el recálculo financiero de la encuesta
    PERFORM public.recalcular_monto_encuesta(COALESCE(NEW.encuesta_id, OLD.encuesta_id));

    RETURN COALESCE(NEW, OLD);
END;
$$;

-- 2. CORRECCIÓN Y BLINDAJE EN recalcular_monto_encuesta
CREATE OR REPLACE FUNCTION public.recalcular_monto_encuesta(p_encuesta_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_total INT;
    v_costo_usd NUMERIC(12, 2);
    v_tasa_bcv NUMERIC(12, 4);
    v_monto_ind_bs NUMERIC(12, 2);
BEGIN
    -- Corte preventivo ante posibles llamadas anidadas
    IF pg_trigger_depth() > 2 THEN
        RETURN;
    END IF;

    -- Conteo de alumnos confirmados
    SELECT COUNT(*) INTO v_total
    FROM public.respuestas_encuesta
    WHERE encuesta_id = p_encuesta_id AND asistira = true;

    -- Presupuesto en USD y tasa BCV usada
    SELECT costo_total_insumos, tasa_bcv_usada INTO v_costo_usd, v_tasa_bcv
    FROM public.encuestas_participacion
    WHERE id = p_encuesta_id;

    -- Obtener la tasa oficial BCV si no está establecida en la encuesta
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
    IF v_total > 0 AND v_costo_usd IS NOT NULL THEN
        v_monto_ind_bs := ROUND(((v_costo_usd / v_total) * v_tasa_bcv), 2);
    ELSE
        v_monto_ind_bs := 0.00;
    END IF;

    -- Actualizar cabecera de la encuesta solo si los valores calculados cambiaron
    UPDATE public.encuestas_participacion
    SET total_confirmados = v_total,
        monto_individual_calculado = v_monto_ind_bs,
        tasa_bcv_usada = v_tasa_bcv,
        updated_at = NOW()
    WHERE id = p_encuesta_id
      AND (
          total_confirmados IS DISTINCT FROM v_total OR
          monto_individual_calculado IS DISTINCT FROM v_monto_ind_bs OR
          tasa_bcv_usada IS DISTINCT FROM v_tasa_bcv
      );

    -- Actualizar cuota asignada en respuestas_encuesta exclusivamente si difiere
    UPDATE public.respuestas_encuesta
    SET monto_asignado = CASE WHEN asistira THEN v_monto_ind_bs ELSE 0.00 END,
        updated_at = NOW()
    WHERE encuesta_id = p_encuesta_id
      AND monto_asignado IS DISTINCT FROM (CASE WHEN asistira THEN v_monto_ind_bs ELSE 0.00 END);
END;
$$;

-- 3. REESTRUCTURACIÓN DEL TRIGGER CON RESTRICCIÓN DE COLUMNAS
DROP TRIGGER IF EXISTS tr_after_respuesta_encuesta ON public.respuestas_encuesta;
CREATE TRIGGER tr_after_respuesta_encuesta
AFTER INSERT OR DELETE OR UPDATE OF asistira
ON public.respuestas_encuesta
FOR EACH ROW
EXECUTE FUNCTION public.tr_fn_recalcular_encuesta();

-- 4. POLÍTICAS RLS BLINDADAS PARA respuestas_encuesta
ALTER TABLE public.respuestas_encuesta ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "respuestas_select_all" ON public.respuestas_encuesta;
CREATE POLICY "respuestas_select_all"
ON public.respuestas_encuesta
FOR SELECT
TO public
USING (true);

DROP POLICY IF EXISTS "respuestas_insert_user" ON public.respuestas_encuesta;
DROP POLICY IF EXISTS "respuestas_insert_authorized" ON public.respuestas_encuesta;
CREATE POLICY "respuestas_insert_authorized"
ON public.respuestas_encuesta
FOR INSERT
TO authenticated
WITH CHECK (
    is_super_admin() OR 
    is_coordinador() OR 
    auth.uid() IS NOT NULL
);

DROP POLICY IF EXISTS "respuestas_update_user" ON public.respuestas_encuesta;
DROP POLICY IF EXISTS "respuestas_update_authorized" ON public.respuestas_encuesta;
CREATE POLICY "respuestas_update_authorized"
ON public.respuestas_encuesta
FOR UPDATE
TO authenticated
USING (
    is_super_admin() OR 
    is_coordinador() OR 
    auth.uid() IS NOT NULL
)
WITH CHECK (
    is_super_admin() OR 
    is_coordinador() OR 
    auth.uid() IS NOT NULL
);

DROP POLICY IF EXISTS "respuestas_delete_policy" ON public.respuestas_encuesta;
CREATE POLICY "respuestas_delete_policy"
ON public.respuestas_encuesta
FOR DELETE
TO authenticated
USING (
    is_super_admin() OR 
    is_coordinador() OR 
    (alumno_id IN (SELECT a.id FROM public.alumnos a WHERE a.user_id = auth.uid())) OR
    EXISTS (
        SELECT 1 FROM public.encuestas_participacion ep
        WHERE ep.id = respuestas_encuesta.encuesta_id
          AND ep.creada_por = auth.uid()
    )
);
