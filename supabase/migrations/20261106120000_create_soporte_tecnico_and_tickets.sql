-- ==============================================================================
-- MIGRACIÓN: Módulo de Soporte Técnico Inteligente, Base de Conocimiento y Tickets
-- ==============================================================================

-- 1. Tabla de configuración de impresoras (si no existe)
CREATE TABLE IF NOT EXISTS public.configuraciones_impresora (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    tipo_conexion TEXT NOT NULL CHECK (tipo_conexion IN ('bluetooth', 'red', 'sistema')),
    identificador TEXT NOT NULL,
    nombre_impresora TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE TRIGGER trg_configuraciones_impresora_updated_at
BEFORE UPDATE ON public.configuraciones_impresora
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_config_impresora_user_id ON public.configuraciones_impresora(user_id);
ALTER TABLE public.configuraciones_impresora ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Los usuarios pueden gestionar su configuracion de impresora" ON public.configuraciones_impresora;
CREATE POLICY "Los usuarios pueden gestionar su configuracion de impresora"
ON public.configuraciones_impresora
FOR ALL
TO authenticated
USING (
    auth.uid() = user_id
    OR (SELECT rol FROM public.perfiles WHERE id = auth.uid()) IN ('super_admin', 'coordinador', 'administrador')
)
WITH CHECK (
    auth.uid() = user_id
    OR (SELECT rol FROM public.perfiles WHERE id = auth.uid()) IN ('super_admin', 'coordinador', 'administrador')
);

-- 2. Base de Conocimiento Técnico (Soporte y Diagnóstico DevOps)
CREATE TABLE IF NOT EXISTS public.soporte_conocimiento (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    categoria TEXT NOT NULL,
    codigo_error TEXT,
    titulo TEXT NOT NULL,
    sintoma TEXT NOT NULL,
    causa_raiz TEXT NOT NULL,
    solucion_guiada TEXT NOT NULL,
    solucion_tecnica_sql TEXT,
    severidad TEXT NOT NULL DEFAULT 'media' CHECK (severidad IN ('baja', 'media', 'alta', 'critica')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE TRIGGER trg_soporte_conocimiento_updated_at
BEFORE UPDATE ON public.soporte_conocimiento
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_soporte_conocimiento_cat ON public.soporte_conocimiento(categoria);
CREATE INDEX IF NOT EXISTS idx_soporte_conocimiento_cod ON public.soporte_conocimiento(codigo_error);
ALTER TABLE public.soporte_conocimiento ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para soporte_conocimiento
DROP POLICY IF EXISTS "Lectura de base de conocimiento para usuarios autenticados" ON public.soporte_conocimiento;
CREATE POLICY "Lectura de base de conocimiento para usuarios autenticados"
ON public.soporte_conocimiento
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Modificacion de base de conocimiento exclusiva Super Admin" ON public.soporte_conocimiento;
CREATE POLICY "Modificacion de base de conocimiento exclusiva Super Admin"
ON public.soporte_conocimiento
FOR ALL
TO authenticated
USING (
    (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
)
WITH CHECK (
    (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
);

-- 3. Tabla de Tickets de Soporte y Diagnóstico
CREATE TABLE IF NOT EXISTS public.tickets_soporte (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    user_nombre TEXT,
    user_rol TEXT,
    modulo TEXT NOT NULL,
    titulo TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    diagnostico_ia TEXT,
    telemetria JSONB DEFAULT '{}'::jsonb,
    severidad TEXT NOT NULL DEFAULT 'media' CHECK (severidad IN ('baja', 'media', 'alta', 'critica')),
    estado TEXT NOT NULL DEFAULT 'abierto' CHECK (estado IN ('abierto', 'en_revision', 'resuelto', 'cerrado')),
    resolucion TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE TRIGGER trg_tickets_soporte_updated_at
BEFORE UPDATE ON public.tickets_soporte
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_tickets_soporte_user ON public.tickets_soporte(user_id);
CREATE INDEX IF NOT EXISTS idx_tickets_soporte_modulo ON public.tickets_soporte(modulo);
CREATE INDEX IF NOT EXISTS idx_tickets_soporte_estado ON public.tickets_soporte(estado);
CREATE INDEX IF NOT EXISTS idx_tickets_soporte_created ON public.tickets_soporte(created_at DESC);
ALTER TABLE public.tickets_soporte ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para tickets_soporte
DROP POLICY IF EXISTS "Lectura de tickets por rol y alcance" ON public.tickets_soporte;
CREATE POLICY "Lectura de tickets por rol y alcance"
ON public.tickets_soporte
FOR SELECT
TO authenticated
USING (
    -- El propio creador puede ver sus tickets
    auth.uid() = user_id
    -- Super Admin tiene acceso global a todos los tickets y diagnósticos del sistema
    OR (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
    -- Coordinadores acceden a tickets generados en módulos pedagógicos y de gestión
    OR (
        (SELECT rol FROM public.perfiles WHERE id = auth.uid()) IN ('coordinador', 'administrador')
        AND modulo IN ('coordinacion', 'profesores', 'alumnos', 'reportes', 'impresion')
    )
);

DROP POLICY IF EXISTS "Insercion de tickets de soporte para usuarios autenticados" ON public.tickets_soporte;
CREATE POLICY "Insercion de tickets de soporte para usuarios autenticados"
ON public.tickets_soporte
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id OR user_id IS NULL
);

DROP POLICY IF EXISTS "Actualizacion de tickets por Super Admin y Coordinacion" ON public.tickets_soporte;
CREATE POLICY "Actualizacion de tickets por Super Admin y Coordinacion"
ON public.tickets_soporte
FOR UPDATE
TO authenticated
USING (
    (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
    OR (
        (SELECT rol FROM public.perfiles WHERE id = auth.uid()) IN ('coordinador', 'administrador')
        AND modulo IN ('coordinacion', 'profesores', 'alumnos', 'reportes', 'impresion')
    )
    OR auth.uid() = user_id
)
WITH CHECK (
    (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
    OR (
        (SELECT rol FROM public.perfiles WHERE id = auth.uid()) IN ('coordinador', 'administrador')
        AND modulo IN ('coordinacion', 'profesores', 'alumnos', 'reportes', 'impresion')
    )
    OR auth.uid() = user_id
);

DROP POLICY IF EXISTS "Eliminacion de tickets exclusiva para Super Admin" ON public.tickets_soporte;
CREATE POLICY "Eliminacion de tickets exclusiva para Super Admin"
ON public.tickets_soporte
FOR DELETE
TO authenticated
USING (
    (SELECT rol FROM public.perfiles WHERE id = auth.uid()) = 'super_admin'
);

-- 4. Funciones seguras para Function Calling / Diagnóstico
CREATE OR REPLACE FUNCTION public.registrar_ticket_soporte(
    p_modulo TEXT,
    p_titulo TEXT,
    p_descripcion TEXT,
    p_diagnostico_ia TEXT DEFAULT NULL,
    p_telemetria JSONB DEFAULT '{}'::jsonb,
    p_severidad TEXT DEFAULT 'media'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_nombre TEXT := 'Usuario Anónimo';
    v_rol TEXT := 'desconocido';
    v_ticket_id UUID;
    v_result JSONB;
BEGIN
    IF v_user_id IS NOT NULL THEN
        SELECT nombre_completo, rol::text INTO v_nombre, v_rol
        FROM public.perfiles
        WHERE id = v_user_id;
    END IF;

    INSERT INTO public.tickets_soporte (
        user_id,
        user_nombre,
        user_rol,
        modulo,
        titulo,
        descripcion,
        diagnostico_ia,
        telemetria,
        severidad,
        estado
    ) VALUES (
        v_user_id,
        COALESCE(v_nombre, 'Usuario'),
        COALESCE(v_rol, 'alumno'),
        p_modulo,
        p_titulo,
        p_descripcion,
        p_diagnostico_ia,
        COALESCE(p_telemetria, '{}'::jsonb),
        COALESCE(p_severidad, 'media'),
        'abierto'
    )
    RETURNING id INTO v_ticket_id;

    SELECT jsonb_build_object(
        'success', true,
        'ticket_id', v_ticket_id,
        'modulo', p_modulo,
        'estado', 'abierto',
        'mensaje', 'Ticket de soporte registrado satisfactoriamente.'
    ) INTO v_result;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.verificar_configuracion_dispositivo(
    p_modulo TEXT DEFAULT 'general'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_printer_config RECORD;
    v_bcv_config RECORD;
    v_result JSONB;
BEGIN
    SELECT * INTO v_printer_config
    FROM public.configuraciones_impresora
    WHERE user_id = v_user_id
    ORDER BY updated_at DESC
    LIMIT 1;

    SELECT tasa, fuente, updated_at INTO v_bcv_config
    FROM public.tasa_cambiaria
    ORDER BY fecha DESC, created_at DESC
    LIMIT 1;

    v_result := jsonb_build_object(
        'impresora_configurada', v_printer_config.id IS NOT NULL,
        'tipo_impresora', COALESCE(v_printer_config.tipo_conexion, 'no_definido'),
        'nombre_impresora', COALESCE(v_printer_config.nombre_impresora, 'Sin configurar'),
        'tasa_bcv_activa', COALESCE(v_bcv_config.tasa, 0),
        'tasa_bcv_actualizada', v_bcv_config.updated_at,
        'modulo_solicitado', p_modulo
    );

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.obtener_diagnostico_sistema()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_rol TEXT;
    v_total_tickets INT;
    v_tickets_abiertos INT;
    v_total_usuarios INT;
    v_total_cursos INT;
    v_result JSONB;
BEGIN
    SELECT rol::text INTO v_rol
    FROM public.perfiles
    WHERE id = v_user_id;

    -- Seguridad estricta: Solo Super Admin puede invocar diagnósticos globales del sistema
    IF v_rol != 'super_admin' THEN
        RAISE EXCEPTION 'Acceso denegado: Se requiere rol Super Admin para ejecutar diagnósticos del sistema.';
    END IF;

    SELECT COUNT(*) INTO v_total_tickets FROM public.tickets_soporte;
    SELECT COUNT(*) INTO v_tickets_abiertos FROM public.tickets_soporte WHERE estado = 'abierto';
    SELECT COUNT(*) INTO v_total_usuarios FROM public.perfiles;
    SELECT COUNT(*) INTO v_total_cursos FROM public.cursos;

    v_result := jsonb_build_object(
        'status', 'operativo',
        'total_usuarios', v_total_usuarios,
        'total_cursos', v_total_cursos,
        'total_tickets', v_total_tickets,
        'tickets_abiertos', v_tickets_abiertos,
        'database_version', version(),
        'timestamp', now()
    );

    RETURN v_result;
END;
$$;

-- 5. Semillas de Base de Conocimiento Técnico (DevOps, Impresión, Supabase, RLS)
INSERT INTO public.soporte_conocimiento (categoria, codigo_error, titulo, sintoma, causa_raiz, solucion_guiada, solucion_tecnica_sql, severidad)
VALUES
(
    'impresion',
    'ERR_PRINTER_BT_CONNECT',
    'Impresora Bluetooth no detectada o desconectada',
    'El botón de impresión no emite ticket o muestra alerta de dispositivo no encontrado.',
    'El dispositivo Bluetooth no está emparejado con el equipo móvil o los permisos de localización/Bluetooth cercanos fueron denegados.',
    '1. Enciende la impresora térmica y comprueba que la luz de Bluetooth parpadee.\n2. Ve a los Ajustes de Bluetooth de tu teléfono/tablet y vincula el dispositivo manualmente con el PIN (suele ser 0000 o 1234).\n3. En UMBRAL, pulsa Ajustes de Impresora y presiona "Escanear Bluetooth".',
    'Verificar en Flutter permissions: BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION. En Web, Bluetooth nativo no está disponible por socket directo, usar System Printer o red TCP ESC/POS vía NetworkSocketClient.',
    'alta'
),
(
    'supabase',
    'ERR_SUPABASE_42501_RLS',
    'Error de permiso denegado en consulta o actualización (42501)',
    'La consulta a Supabase retorna error "new row violates row-level security policy for table".',
    'El usuario autenticado intentó insertar o modificar una fila donde la política WITH CHECK o USING de RLS no evalúa a true para su auth.uid() o rol.',
    'Verifica que hayas iniciado sesión con el rol correspondiente para realizar esta acción. Si necesitas permisos adicionales, contacta al Super Admin de UMBRAL.',
    'SELECT tablename, policyname, permissive, roles, cmd, qual, with_check FROM pg_policies WHERE schemaname = ''public'' AND tablename = ''nombre_tabla''; Asegurar que el rol en perfiles coincida con auth.jwt()->>''rol'' o subquery.',
    'critica'
),
(
    'red',
    'ERR_SOCKET_TIMEOUT',
    'Timeout en conexión TCP de impresora de red',
    'La impresión por red WiFi tarda más de 5 segundos y arroja error SocketException.',
    'La dirección IP configurada para la impresora en red no responde en el puerto 9100 (RAW ESC/POS) o el dispositivo está en otra subred.',
    '1. Verifica que la impresora y tu dispositivo estén conectados a la misma red WiFi de IMMUJER.\n2. Imprime la hoja de configuración de red de la impresora para confirmar su IP actual.\n3. En Ajustes de Impresora, actualiza la dirección IP y el puerto (predeterminado 9100).',
    'Testing con ping y nc: nc -zv [IP_IMPRESORA] 9100. En Flutter verificar timeout en NetworkSocketClient: Socket.connect(host, port, timeout: Duration(seconds: 5)).',
    'media'
),
(
    'autenticacion',
    'ERR_AUTH_SESSION_EXPIRED',
    'Sesión expirada o token JWT no renovado',
    'La aplicación redirige abruptamente al login o las consultas retornan 401 Unauthorized.',
    'El token de acceso expiró y el refresh token no pudo ser renovado debido a corte de conectividad o invalidación de sesión en Supabase.',
    'Introduce nuevamente tu correo institucional y contraseña en la pantalla de inicio de sesión.',
    'Verificar auth.users y sessions en auth schema: SELECT id, email, last_sign_in_at FROM auth.users WHERE id = auth.uid(); Comprobar Supabase.instance.client.auth.currentSession y autoRefreshToken.',
    'media'
),
(
    'bcv',
    'ERR_BCV_SYNC',
    'Tasa BCV desactualizada o fuera de fecha laboral',
    'Los montos en Bolívares no coinciden con la tasa publicada hoy por el Banco Central de Venezuela.',
    'El cron job de actualización no pudo conectarse a la API oficial o el sitio del BCV publicó fuera del horario bancario habitual.',
    'En el panel de Super Admin o Configuración General, pulsa el botón "Sincronizar BCV" para forzar la actualización manual en vivo.',
    'SELECT * FROM public.tasa_cambiaria ORDER BY fecha DESC LIMIT 5; Para forzar actualización ejecutar Edge Function sync-bcv-rate o llamar SELECT public.sincronizar_tasa_bcv();',
    'baja'
)
ON CONFLICT DO NOTHING;
