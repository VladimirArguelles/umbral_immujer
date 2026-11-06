import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

interface TelemetryPayload {
  currentModule?: string;
  networkStatus?: string;
  bluetoothStatus?: string;
  lastError?: string;
  platform?: string;
  userRole?: string;
  userId?: string;
  userName?: string;
}

interface RequestBody {
  query: string;
  telemetry?: TelemetryPayload;
  conversationHistory?: Array<{ sender: "user" | "assistant"; text: string }>;
  autoTicketOnCritical?: boolean;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? supabaseAnonKey;

    // Obtener token del usuario del header Authorization si existe
    const authHeader = req.headers.get("Authorization");
    const client = createClient(supabaseUrl, authHeader ? supabaseAnonKey : supabaseServiceRoleKey, {
      global: {
        headers: authHeader ? { Authorization: authHeader } : undefined,
      },
    });

    const body: RequestBody = await req.json();
    const query = (body.query || "").trim();
    const telemetry = body.telemetry || {};
    const role = (telemetry.userRole || "alumno").toLowerCase();
    const isSuperAdmin = role === "super_admin";
    const isCoordinator = role === "coordinador";
    const lastError = telemetry.lastError || null;
    const currentModule = telemetry.currentModule || "general";

    let diagnosticResult: Record<string, unknown> | null = null;
    let autoTicketId: string | null = null;

    // 1. Diagnóstico de configuraciones si se solicita o hay falla de impresión/dispositivos
    const isDeviceOrPrintingIssue = /impres|bluetooth|pos|ticket|termic/i.test(query) ||
      (lastError && /bluetooth|printer|impres/i.test(lastError));

    if (telemetry.userId && (isDeviceOrPrintingIssue || /diagnostico|verificar/i.test(query))) {
      try {
        const { data: configData } = await client.rpc("verificar_configuracion_dispositivo", {
          p_user_id: telemetry.userId,
        });
        diagnosticResult = configData;
      } catch (_err) {
        // Fallback silencioso si el RPC no está disponible
      }
    }

    // 2. Diagnóstico de sistema para Super Admin
    let systemAudit: Record<string, unknown> | null = null;
    if (isSuperAdmin && (/sistema|auditoria|rls|bd|postgres|tablas|tickets/i.test(query) || lastError)) {
      try {
        const { data: auditData } = await client.rpc("obtener_diagnostico_sistema");
        systemAudit = auditData;
      } catch (_err) {
        // Fallback silencioso
      }
    }

    // 3. Crear ticket de soporte automático si hay un error crítico capturado en telemetría
    const isCriticalFailure = lastError && (
      lastError.includes("42501") ||
      lastError.toLowerCase().includes("permission denied") ||
      lastError.toLowerCase().includes("socketexception") ||
      lastError.toLowerCase().includes("jwt") ||
      lastError.toLowerCase().includes("fatal")
    );

    if (isCriticalFailure && telemetry.userId && (body.autoTicketOnCritical ?? true)) {
      try {
        const { data: ticketRes } = await client.rpc("registrar_ticket_soporte", {
          p_modulo: currentModule,
          p_titulo: `Error crítico automático: ${lastError.substring(0, 80)}`,
          p_descripcion: `Falla detectada por telemetría en el módulo [${currentModule}].\nError: ${lastError}\nRed: ${telemetry.networkStatus}\nBluetooth: ${telemetry.bluetoothStatus}`,
          p_severidad: "critica",
          p_metadatos: {
            telemetry,
            query_origen: query,
          },
        });
        if (ticketRes?.ticket_id) {
          autoTicketId = ticketRes.ticket_id;
        }
      } catch (_e) {
        // RLS o error RPC manejado de forma segura
      }
    }

    // 4. Búsqueda en la Base de Conocimiento de Soporte Técnico (soporte_conocimiento)
    let knowledgeBaseArticles: Array<{ titulo: string; solucion_tecnica: string; solucion_usuario: string; categoria: string }> = [];
    try {
      const searchTerms = query.split(/\s+/).filter((w) => w.length > 3);
      const orFilter = searchTerms.map((t) => `palabras_clave.cs.{${t.toLowerCase()}}`).join(",");
      
      const { data: articles } = await client
        .from("soporte_conocimiento")
        .select("titulo, solucion_tecnica, solucion_usuario, categoria")
        .or(orFilter.length > 0 ? orFilter : "categoria.eq.general")
        .limit(3);

      if (articles && articles.length > 0) {
        knowledgeBaseArticles = articles;
      }
    } catch (_e) {
      // Base de conocimiento vacía o inaccesible por RLS
    }

    // 5. Motor de Respuesta Inteligente Umby (Adaptativa por Rol)
    let responseText = "";

    // Si hay un LLM externo (Gemini API o compatible) configurado en el entorno
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (geminiKey) {
      responseText = await callGeminiModel(
        geminiKey,
        query,
        telemetry,
        knowledgeBaseArticles,
        diagnosticResult,
        systemAudit,
        autoTicketId
      );
    } else {
      // Motor experto nativo de soporte técnico y devops UMBRAL
      responseText = buildExpertDiagnosticResponse(
        query,
        telemetry,
        knowledgeBaseArticles,
        diagnosticResult,
        systemAudit,
        autoTicketId,
        isSuperAdmin,
        isCoordinator
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        assistant: "Umby",
        role: "Soporte Técnico y DevOps",
        response: responseText,
        diagnostics: {
          deviceConfig: diagnosticResult,
          systemAudit: isSuperAdmin ? systemAudit : null,
          ticketGenerado: autoTicketId,
          activeTelemetry: {
            module: currentModule,
            network: telemetry.networkStatus,
            bluetooth: telemetry.bluetoothStatus,
            errorCapturado: lastError != null,
          },
        },
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        assistant: "Umby",
        error: (error as Error).message,
        hint: "Verifique la conexión o contacte al administrador de UMBRAL.",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

/**
 * Generador de respuestas adaptativas expertas según el rol (Super Admin vs Coordinador/Usuario).
 */
function buildExpertDiagnosticResponse(
  query: string,
  telemetry: TelemetryPayload,
  kbArticles: Array<{ titulo: string; solucion_tecnica: string; solucion_usuario: string }>,
  deviceConfig: Record<string, unknown> | null,
  systemAudit: Record<string, unknown> | null,
  ticketId: string | null,
  isSuperAdmin: boolean,
  isCoordinator: boolean
): string {
  const q = query.toLowerCase();
  const userName = telemetry.userName || "Usuario";
  const lastError = telemetry.lastError;
  const currentModule = telemetry.currentModule || "General";

  // Alerta de ticket generado automáticamente
  let ticketHeader = "";
  if (ticketId) {
    ticketHeader = `> [!CAUTION]\n> **Incidencia Registrada:** Se ha generado automáticamente el ticket de soporte técnico **\`#${ticketId.substring(0, 8)}\`** debido a un fallo crítico detectado en telemetría.\n\n`;
  }

  // --- RESPUESTA SUPER ADMIN: ENFOQUE DEVOPS, SQL, DART Y RLS ---
  if (isSuperAdmin) {
    if (q.includes("rls") || q.includes("politica") || (lastError && lastError.includes("42501"))) {
      return `${ticketHeader}### 🛠️ Diagnóstico DevOps: Seguridad RLS en PostgreSQL

**Estado Detectado:**
- **Módulo:** \`${currentModule}\`
- **Último Error:** \`${lastError || "No hay excepciones RLS activas en memoria"}\`

**Verificación y Resolución Directa en Base de Datos:**
Para auditar y corregir permisos denegados (código \`42501\`), ejecuta el siguiente script en el editor SQL de Supabase:

\`\`\`sql
-- 1. Verificar estado de RLS en las tablas del módulo
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('perfiles', 'cursos', 'inscripciones', 'tickets_soporte', 'soporte_conocimiento');

-- 2. Asegurar bypass seguro para Super Admin en la tabla afectada:
DROP POLICY IF EXISTS "super_admin_manage_all" ON public.tickets_soporte;
CREATE POLICY "super_admin_manage_all" ON public.tickets_soporte
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles
      WHERE perfiles.id = auth.uid() AND perfiles.rol = 'super_admin'
    )
  );
\`\`\`

**Regla de Arquitectura:** En el cliente Flutter, asegúrate de no usar llamadas REST directas si el JWT no contiene el claim verificado en \`perfiles.rol\`.`;
    }

    if (q.includes("impres") || q.includes("bluetooth") || q.includes("pos") || (lastError && /bluetooth|printer/i.test(lastError))) {
      return `${ticketHeader}### 🖨️ Diagnóstico Técnico: Subsistema de Impresión Térmica ESC/POS

**Telemetría del Cliente:**
- **Adaptador Bluetooth:** \`${telemetry.bluetoothStatus || "Desconocido"}\`
- **Plataforma:** \`${telemetry.platform || "Web/Móvil"}\`
- **Configuración en BD:** \`${deviceConfig?.impresora_registrada ? "Registrada (" + deviceConfig?.direccion_mac + ")" : "Sin impresora asignada"}\`

**Acciones de Código y Configuración:**
1. **En Web:** Los navegadores no soportan sockets RFCOMM directos de Bluetooth Classic. La app en entorno web utiliza simulación o impresión PDF térmica mediante el driver del navegador.
2. **En Android / iOS:** Verifica los permisos en \`AndroidManifest.xml\`:
\`\`\`xml
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
\`\`\`
3. **Consulta de Configuración:**
\`\`\`sql
SELECT * FROM public.configuraciones_impresora WHERE usuario_id = '${telemetry.userId || "auth.uid()"}';
\`\`\``;
    }

    if (q.includes("bcv") || q.includes("tasa") || q.includes("dolar")) {
      return `${ticketHeader}### 💵 Diagnóstico Técnico: Sincronización Tasa BCV

**Mecanismo:** La tasa cambiaria se sincroniza mediante la Edge Function \`sync-bcv-rate\` activada periódicamente por un Cron Job de pg_cron o trigger HTTP.

**Comprobación en Supabase:**
\`\`\`sql
-- Consultar última tasa registrada y antigüedad
SELECT tasa, fecha_registro, fuente, 
       (now() - fecha_registro) AS antiguedad
FROM public.tasas_cambio_bcv
ORDER BY fecha_registro DESC 
LIMIT 1;
\`\`\`
Si la tasa tiene más de 24 horas hábiles sin refrescarse, invoca manualmente la función \`sync-bcv-rate\` desde el panel de Edge Functions.`;
    }

    if (systemAudit) {
      return `${ticketHeader}### 📊 Estado y Diagnóstico Global del Sistema

- **Tickets Activos:** \`${(systemAudit as Record<string, unknown>).tickets_activos ?? 0}\`
- **Total Tablas Auditadas:** \`${(systemAudit as Record<string, unknown>).total_tablas ?? "N/A"}\`
- **Tasa BCV:** \`${(systemAudit as Record<string, unknown>).tasa_bcv_actual ?? "No disponible"}\` (Actualizada: ${(systemAudit as Record<string, unknown>).tasa_bcv_fecha ?? "N/A"})
- **Módulo Activo:** \`${currentModule}\`
- **Telemetría de Red:** \`${telemetry.networkStatus || "Online"}\`
- **Último Error Registrado:** \`${lastError || "Ninguno"}\`

¿Deseas generar un script correctivo para alguna tabla o revisar la traza de logs de Supabase?`;
    }

    // Super Admin consulta general técnica
    return `${ticketHeader}Hola, **${userName}** (Super Admin). Como **Umby**, tu soporte técnico DevOps para UMBRAL:

- **Módulo de Ejecución:** \`${currentModule}\`
- **Estado de Conexión:** \`${telemetry.networkStatus || "Conectado"}\` | **Bluetooth:** \`${telemetry.bluetoothStatus || "Inactivo"}\`
${lastError ? `- **Última Excepción Capturada:** \`${lastError}\`\n` : ""}

**Capacidades Rápidas:**
1. **Auditoría de RLS y Permisos:** Pídeme verificar políticas para roles \`coordinador\`, \`profesor\` o \`alumno\`.
2. **Sistemas de Impresión:** Diagnóstico de sockets Bluetooth, comandos ESC/POS y compatibilidad Web vs Nativo.
3. **Base de Datos y Telemetría:** Consultas SQL de salud, tickets de error e integridad relacional.

Indícame qué incidencia o tabla deseas diagnosticar.`;
  }

  // --- RESPUESTA COORDINADOR: NAVEGACIÓN Y SOPORTE OPERATIVO SIN JERGA TÉCNICA ---
  if (isCoordinator) {
    if (q.includes("impres") || q.includes("ticket") || q.includes("bluetooth")) {
      return `${ticketHeader}Hola, **${userName}**. Te ayudo con la impresora de tickets:

1. **Revisa la Conexión:** Asegúrate de que la impresora térmica tenga papel, esté encendida y el Bluetooth del dispositivo se encuentre activo.
2. **Si estás en una computadora (Navegador):** Los navegadores imprimen mediante la ventana estándar de impresión del sistema. Al emitir un comprobante, presiona **Imprimir** y selecciona tu impresora térmica en el listado de impresoras del sistema operativo.
3. **Si el ticket no sale:** Verifica que no haya cola de impresión pausada en el panel de control de tu computadora.

Si el problema continúa, he registrado la incidencia para revisión del equipo técnico.`;
    }

    if (q.includes("navegar") || q.includes("seccion") || q.includes("donde")) {
      return `Hola, **${userName}**. Aquí tienes la guía de navegación de tu **Panel de Coordinación**:

- **Cursos (Pestaña 1):** Aquí visualizas las formaciones activas, inscripciones abiertas y áreas técnicas del IMMUJER.
- **En Vivo (Pestaña 2):** Te permite monitorear las clases y transmisiones en tiempo real.
- **Profesores (Pestaña 3):** Gestión de la plantilla docente, revisión de materias asignadas y aprobación de temarios.
- **Insumos (Pestaña 4):** Control del inventario y materiales utilizados en los talleres prácticos.
- **Botón "Ver Registros" (Barra Superior):** Te lleva directamente al Centro de Reportes consolidados para descargar constancias y estadísticas.
- **Mi Perfil (Avatar Superior Derecho):** Aquí puedes actualizar tu fotografía institucional, número telefónico y contraseña.`;
    }

    return `${ticketHeader}Hola, **${userName}**. Soy **Umby**, tu asistente de soporte en el **Módulo de Coordinación**.

Puedo ayudarte a:
- Orientarte paso a paso en la navegación entre las secciones (**Cursos**, **En Vivo**, **Profesores**, **Insumos**).
- Resolver dudas sobre la aprobación de temarios y revisión de solicitudes docentes.
- Guía para emisión de comprobantes, reportes y configuración de impresora.

¿En qué tarea o pantalla requieres apoyo hoy?`;
  }

  // --- RESPUESTA GENERAL (PROFESORES / ALUMNOS) ---
  return `${ticketHeader}¡Hola, **${userName}**! Soy **Umby**, tu asistente de soporte en UMBRAL IMMUJER.

Estoy aquí para ayudarte a utilizar la plataforma con fluidez:
- Consultar tus cursos y asistencias.
- Responder encuestas de satisfacción.
- Actualizar tus datos y fotografía en **Mi Perfil** (icono en la esquina superior derecha).
- Resolver cualquier duda o inconveniente en tu pantalla actual (**${currentModule}**).

¿Qué duda o dificultad tienes en este momento?`;
}

/**
 * Llamada opcional a Gemini si existe la API Key en el entorno
 */
async function callGeminiModel(
  apiKey: string,
  query: string,
  telemetry: TelemetryPayload,
  kbArticles: Array<{ titulo: string; solucion_tecnica: string; solucion_usuario: string }>,
  deviceConfig: Record<string, unknown> | null,
  systemAudit: Record<string, unknown> | null,
  ticketId: string | null
): Promise<string> {
  const isSuperAdmin = telemetry.userRole === "super_admin";
  const systemPrompt = `Eres Umby, asistente virtual de Soporte Técnico y DevOps para la plataforma UMBRAL del Instituto Municipal de la Mujer (IMMUJER).
Eres un experto senior en Flutter, Dart, Supabase, PostgreSQL, Row Level Security (RLS) y sistemas de impresión térmica móvil/web.
Tu respuesta debe ser profesional y adaptativa:
- Si el usuario es Super Admin (rol super_admin): responde con precisión técnica, scripts SQL exactos, código Dart, análisis de RLS o arquitectura.
- Si el usuario es Coordinador, Profesor o Alumno: responde con instrucciones claras paso a paso, amables y sin jerga técnica compleja.
Contexto de telemetría:
- Módulo actual: ${telemetry.currentModule}
- Red: ${telemetry.networkStatus}
- Bluetooth: ${telemetry.bluetoothStatus}
- Último error del sistema: ${telemetry.lastError || "Ninguno"}
- Ticket generado: ${ticketId || "Ninguno"}
Base de Conocimiento relevante: ${JSON.stringify(kbArticles)}
Diagnóstico dispositivo: ${JSON.stringify(deviceConfig)}
Auditoría sistema: ${JSON.stringify(systemAudit)}`;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          { role: "user", parts: [{ text: `${systemPrompt}\n\nConsulta del usuario: ${query}` }] },
        ],
      }),
    }
  );

  if (!res.ok) {
    throw new Error(`Gemini API respondió ${res.status}`);
  }

  const json = await res.json();
  return json?.candidates?.[0]?.content?.parts?.[0]?.text || "No se pudo generar respuesta con IA.";
}
