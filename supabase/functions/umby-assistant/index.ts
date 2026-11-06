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

    const authHeader = req.headers.get("Authorization");
    const client = createClient(supabaseUrl, authHeader ? supabaseAnonKey : supabaseServiceRoleKey, {
      global: {
        headers: authHeader ? { Authorization: authHeader } : undefined,
      },
    });

    // Cliente administrativo para inserción de notificaciones sin bloqueos RLS
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);

    const body: RequestBody = await req.json();
    const query = (body.query || "").trim();
    const telemetry = body.telemetry || {};
    const role = (telemetry.userRole || "alumno").toLowerCase();
    const isSuperAdmin = role === "super_admin";
    const isCoordinator = role === "coordinador";
    const lastError = telemetry.lastError || null;
    const currentModule = (telemetry.currentModule || "general").toLowerCase();

    let diagnosticResult: Record<string, unknown> | null = null;
    let autoTicketId: string | null = null;

    // 1. Diagnóstico de dispositivos (impresión / bluetooth)
    const isDeviceOrPrintingIssue = /impres|bluetooth|pos|ticket|termic/i.test(query) ||
      (lastError != null && /bluetooth|printer|impres/i.test(lastError));

    if (telemetry.userId && (isDeviceOrPrintingIssue || /diagnostico|verificar/i.test(query))) {
      try {
        const { data: configData } = await client.rpc("verificar_configuracion_dispositivo", {
          p_user_id: telemetry.userId,
        });
        diagnosticResult = configData;
      } catch (_err) {
        // Fallback silencioso
      }
    }

    // 2. Diagnóstico de sistema para Super Admin
    let systemAudit: Record<string, unknown> | null = null;
    if (isSuperAdmin && (/sistema|auditoria|rls|bd|postgres|tablas|tickets/i.test(query) || lastError)) {
      try {
        const { data: auditData } = await client.rpc("obtener_diagnostico_sistema");
        systemAudit = auditData;
      } catch (_err) {
        // Fallback
      }
    }

    // 3. Crear ticket de soporte automático si hay un error crítico
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
          p_descripcion: `Falla detectada por telemetría en el módulo [${currentModule}]. Error: ${lastError}`,
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
        // Fallback
      }
    }

    // 4. CONSULTA A 'guia_operaciones' (Manual Interactivo Inteligente)
    let relevantGuides: Array<{ titulo_operacion: string; instrucciones_paso_a_paso: string; modulo: string; rol_permitido: string[] }> = [];
    try {
      const { data: guidesData } = await adminClient
        .from("guia_operaciones")
        .select("titulo_operacion, instrucciones_paso_a_paso, modulo, rol_permitido");

      if (guidesData && guidesData.length > 0) {
        relevantGuides = guidesData;
      }
    } catch (_e) {
      // Fallback
    }

    // 5. DETECCIÓN DE PROBLEMAS EN OPERACIONES Y NOTIFICACIÓN AL SUPER ADMIN
    const isOperationIssue = /problema|falla|fallo|error|no puedo|no deja|no funciona|no imprime|no guarda|se trab|bug|denegad|invalido|incorrecto|bloquead|42501|ayuda con error|falla al|no sincroniza/i.test(query) ||
      (lastError != null && lastError.length > 0);

    let operationalDiagnosis: { donde_esta_el_problema: string; que_debe_revisar: string } | null = null;
    let notificationSentToAdmin = false;

    if (isOperationIssue) {
      operationalDiagnosis = analyzeOperationalIssue(query, currentModule, role, lastError, telemetry);
      try {
        const notifTitle = `⚠️ Incidencia Operativa en [${currentModule.toUpperCase()}]: ${telemetry.userName || "Usuario"}`;
        const notifMensaje = `El usuario ${telemetry.userName || "Anónimo"} (${role}) reportó un problema:\n"${query.substring(0, 160)}"\n\n📍 Dónde: ${operationalDiagnosis.donde_esta_el_problema}\n🛠️ Revisar: ${operationalDiagnosis.que_debe_revisar}`;

        await adminClient.from("notificaciones").insert({
          rol_destino: "super_admin",
          usuario_origen_id: telemetry.userId || null,
          titulo: notifTitle,
          mensaje: notifMensaje,
          tipo: "incidencia_operacion",
          datos: {
            modulo: currentModule,
            usuario_nombre: telemetry.userName || "Usuario",
            usuario_rol: role,
            consulta_original: query,
            donde_esta_el_problema: operationalDiagnosis.donde_esta_el_problema,
            que_debe_revisar: operationalDiagnosis.que_debe_revisar,
            ultimo_error: lastError,
            telemetria: telemetry,
            fecha: new Date().toISOString(),
          },
          leido: false,
        });
        notificationSentToAdmin = true;
      } catch (_e) {
        // Fallback
      }
    }

    // 6. Base de Conocimiento de Soporte Técnico
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
      // Fallback
    }

    // 7. Generación de Respuesta Inteligente como Manual Interactivo
    let responseText = "";
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (geminiKey) {
      responseText = await callGeminiModel(
        geminiKey,
        query,
        telemetry,
        relevantGuides,
        knowledgeBaseArticles,
        diagnosticResult,
        systemAudit,
        autoTicketId,
        operationalDiagnosis,
        notificationSentToAdmin
      );
    } else {
      responseText = buildInteractiveManualResponse(
        query,
        telemetry,
        relevantGuides,
        knowledgeBaseArticles,
        diagnosticResult,
        systemAudit,
        autoTicketId,
        operationalDiagnosis,
        notificationSentToAdmin,
        isSuperAdmin,
        isCoordinator
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        assistant: "Umby",
        role: "Manual Interactivo y Soporte Técnico",
        response: responseText,
        diagnostics: {
          deviceConfig: diagnosticResult,
          systemAudit: isSuperAdmin ? systemAudit : null,
          ticketGenerado: autoTicketId,
          notificacionSuperAdmin: notificationSentToAdmin,
          analisisIncidencia: operationalDiagnosis,
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
 * Analiza un fallo o problema reportado por el usuario y determina dónde está la causa y qué debe revisar el Super Admin.
 */
function analyzeOperationalIssue(
  query: string,
  module: string,
  role: string,
  lastError: string | null,
  telemetry: TelemetryPayload
): { donde_esta_el_problema: string; que_debe_revisar: string } {
  const q = query.toLowerCase();
  const err = (lastError || "").toLowerCase();

  if (q.includes("impres") || q.includes("bluetooth") || q.includes("ticket") || err.includes("printer") || err.includes("bluetooth")) {
    return {
      donde_esta_el_problema: "Subsistema de Impresión Térmica ESC/POS (Módulo de Tickets / Bluetooth)",
      que_debe_revisar: "1. Verificar si la impresora Bluetooth está emparejada y encendida.\n2. En Web, verificar si el navegador tiene acceso al diálogo de impresión nativo del OS.\n3. Comprobar registros en tabla `configuraciones_impresora` para el usuario.\n4. Si es Android, revisar permisos BLUETOOTH_CONNECT en tiempo de ejecución.",
    };
  }

  if (q.includes("guardar") || q.includes("crear") || q.includes("permiso") || err.includes("42501") || err.includes("row-level security")) {
    return {
      donde_esta_el_problema: "Seguridad RLS en PostgreSQL o Permisos de Rol Insuficientes",
      que_debe_revisar: "1. Revisar políticas RLS para la tabla afectada en Supabase (error 42501).\n2. Verificar que el campo `rol` en `perfiles` corresponda al esperado ('" + role + "').\n3. Confirmar que el token JWT del usuario contenga el claim auth.uid() activo.",
    };
  }

  if (q.includes("bcv") || q.includes("tasa") || q.includes("dolar") || q.includes("cambio")) {
    return {
      donde_esta_el_problema: "Sincronización de Tasa Cambiaria Oficial BCV (Edge Function / Cron Job)",
      que_debe_revisar: "1. Verificar la última fecha de actualización en `public.tasas_cambio_bcv`.\n2. Probar la Edge Function `sync-bcv-rate` desde el panel de Supabase.\n3. Comprobar conectividad hacia la API de consulta BCV o web scraping.",
    };
  }

  if (q.includes("asistencia") || q.includes("pase de lista")) {
    return {
      donde_esta_el_problema: "Módulo de Asistencias y Clases Prácticas (Flujo Docente/Coordinación)",
      que_debe_revisar: "1. Verificar que el profesor tenga asignado el curso en `profesores` / `cursos`.\n2. Confirmar que existan alumnos matriculados en `inscripciones` para la fecha seleccionada.\n3. Validar políticas RLS en la tabla `asistencia`.",
    };
  }

  if (q.includes("temario") || q.includes("propuesta") || q.includes("aprobar")) {
    return {
      donde_esta_el_problema: "Flujo de Aprobación de Temarios (Módulo de Coordinación / Docentes)",
      que_debe_revisar: "1. Revisar la tabla `solicitudes_aprobacion` para solicitudes en estado 'pendiente'.\n2. Comprobar permisos del coordinador para modificar `estado` a 'aprobado'.",
    };
  }

  if (q.includes("reporte") || q.includes("pdf") || q.includes("exportar")) {
    return {
      donde_esta_el_problema: "Motor de Generación de Reportes Consolidados y Exportación PDF",
      que_debe_revisar: "1. Verificar las vistas de base de datos `view_reporte_*`.\n2. Comprobar que no haya campos numéricos nulos en retención o asistencias.",
    };
  }

  return {
    donde_esta_el_problema: `Operación en Módulo [${module.toUpperCase()}] - Interacción de Usuario (${role})`,
    que_debe_revisar: `1. Última traza de error capturada: ${lastError || "Sin excepción crítica registrada"}.\n2. Estado de red: ${telemetry.networkStatus || "Desconocido"}.\n3. Verificar consistencia de datos en Supabase para el usuario ${telemetry.userId || "anónimo"}.`,
  };
}

/**
 * Construye la respuesta del Manual Interactivo Inteligente adaptada al rol y módulo activo.
 */
function buildInteractiveManualResponse(
  query: string,
  telemetry: TelemetryPayload,
  guides: Array<{ titulo_operacion: string; instrucciones_paso_a_paso: string; modulo: string; rol_permitido: string[] }>,
  kbArticles: Array<{ titulo: string; solucion_tecnica: string; solucion_usuario: string }>,
  deviceConfig: Record<string, unknown> | null,
  systemAudit: Record<string, unknown> | null,
  ticketId: string | null,
  operationalDiagnosis: { donde_esta_el_problema: string; que_debe_revisar: string } | null,
  notificationSentToAdmin: boolean,
  isSuperAdmin: boolean,
  isCoordinator: boolean
): string {
  const q = query.toLowerCase();
  const userName = telemetry.userName || "Usuario";
  const userRole = (telemetry.userRole || "alumno").toLowerCase();
  const currentModule = (telemetry.currentModule || "general").toLowerCase();

  let headerNotices = "";
  if (ticketId) {
    headerNotices += `> [!CAUTION]\n> **Incidencia Crítica:** Se ha generado automáticamente el ticket **\`#${ticketId.substring(0, 8)}\`**.\n\n`;
  }
  if (notificationSentToAdmin && operationalDiagnosis) {
    headerNotices += `> [!NOTE]\n> **Notificación enviada al Super Admin:** He notificado al equipo técnico sobre el problema detectado en **${operationalDiagnosis.donde_esta_el_problema}**.\n\n`;
  }

  // Buscar guías coincidentes en guia_operaciones
  const matchedGuide = guides.find((g) => {
    const titleMatch = g.titulo_operacion.toLowerCase().split(/\s+/).some((w) => w.length > 4 && q.includes(w));
    const moduleMatch = g.modulo === currentModule || g.modulo === "general";
    return titleMatch && (moduleMatch || isSuperAdmin);
  });

  if (matchedGuide) {
    // Validar si el rol tiene permiso para esta operación
    const isAllowed = isSuperAdmin ||
      matchedGuide.rol_permitido.includes("todos") ||
      matchedGuide.rol_permitido.includes(userRole);

    if (!isAllowed) {
      return `${headerNotices}Hola, **${userName}**.

La operación **"${matchedGuide.titulo_operacion}"** está reservada exclusivamente para los roles de **${matchedGuide.rol_permitido.join(" / ").toUpperCase()}**.

Tu perfil actual tiene rol de **${userRole.toUpperCase()}**. En esta pantalla (**${currentModule}**), puedes realizar consultas y operaciones correspondientes a tu rol, pero no tienes permisos de modificación para esta función. Si consideras que requieres este acceso, comunícate con la Coordinación del IMMUJER o el Super Admin.`;
    }

    return `${headerNotices}### 📖 Guía Paso a Paso: ${matchedGuide.titulo_operacion}

Hola, **${userName}**. Aquí tienes las instrucciones oficiales para realizar esta operación en el **${currentModule.toUpperCase()}**:

${matchedGuide.instrucciones_paso_a_paso}

¿Tienes alguna duda sobre alguno de estos pasos o requieres asistencia adicional?`;
  }

  // --- RESPUESTA SUPER ADMIN ---
  if (isSuperAdmin) {
    if (q.includes("rls") || (telemetry.lastError && telemetry.lastError.includes("42501"))) {
      return `${headerNotices}### 🛠️ Diagnóstico DevOps: Seguridad RLS en PostgreSQL

**Estado:** Módulo \`${currentModule}\` | Error: \`${telemetry.lastError || "Sin excepción activa"}\`

\`\`\`sql
-- Auditar permisos de tablas y roles
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('perfiles', 'cursos', 'inscripciones', 'tickets_soporte', 'guia_operaciones');
\`\`\``;
    }

    if (q.includes("impres") || q.includes("bluetooth")) {
      return `${headerNotices}### 🖨️ Diagnóstico Técnico: Impresora Térmica ESC/POS

**Telemetría:** Bluetooth: \`${telemetry.bluetoothStatus || "Desconocido"}\` | Plataforma: \`${telemetry.platform || "Web"}\`

\`\`\`sql
SELECT * FROM public.configuraciones_impresora WHERE usuario_id = '${telemetry.userId || "auth.uid()"}';
\`\`\``;
    }

    return `${headerNotices}Hola, **${userName}** (Super Admin). Como tu **Manual Interactivo y Soporte DevOps**:
- **Módulo Activo:** \`${currentModule}\`
- **Operaciones Disponibles:** Gestión global de cursos, sincronización BCV, auditoría de usuarios y configuración de guías.

Puedes consultarme cómo ejecutar cualquier operación paso a paso o solicitar diagnósticos de base de datos.`;
  }

  // --- RESPUESTA COORDINADOR ---
  if (isCoordinator) {
    if (q.includes("curso") || q.includes("crear") || q.includes("registrar")) {
      return `${headerNotices}### 📖 Cómo registrar un nuevo curso en Coordinación

1. **Pestaña Cursos:** En tu panel de Coordinación, abre la primera pestaña **"Cursos"**.
2. **Botón Nuevo Curso:** Pulsa el botón **"Nuevo Curso"** ubicado en la esquina superior.
3. **Completar Datos:** Ingresa el nombre de la formación, selecciona el área técnica (ej. Repostería, Peluquería, Textil), el horario (días y horas) y asigna al profesor responsable.
4. **Guardar:** Pulsa **"Guardar Formación"** para activar las inscripciones al instante.`;
    }

    if (q.includes("profesor") || q.includes("aprobar") || q.includes("temario")) {
      return `${headerNotices}### 📖 Cómo revisar y aprobar temarios docentes

1. **Pestaña Profesores:** Dirígete a la pestaña **"Profesores"** en tu panel.
2. **Bandeja de Aprobaciones:** Revisa la sección superior de propuestas pendientes enviadas por los profesores.
3. **Detalles:** Toca la propuesta para evaluar su justificación, temario e insumos.
4. **Acción:** Pulsa **"Aprobar"** para integrarla al cronograma o **"Rechazar con Observaciones"** para correcciones.`;
    }

    return `${headerNotices}Hola, **${userName}**. Como **Manual Interactivo de Coordinación**, puedo guiarte paso a paso en:
- Registrar y programar nuevos cursos formativos.
- Asignar profesores y aprobar propuestas de temarios.
- Configurar tu impresora térmica y emitir comprobantes de aportes.
- Filtrar y exportar reportes en PDF desde "Ver Registros".

¿Qué operación deseas realizar en este momento?`;
  }

  // --- RESPUESTA ALUMNO / PROFESOR ---
  return `${headerNotices}¡Hola, **${userName}**! Soy **Umby**, tu manual interactivo en UMBRAL IMMUJER.

En tu pantalla actual (**${currentModule}**), tienes permitido:
- Consultar tus asistencias acumuladas y estado de certificación.
- Registrar tus aportes prácticos con referencia de pago.
- Responder encuestas de satisfacción de tus talleres.
- Actualizar tu fotografía y número telefónico en **Mi Perfil** (avatar superior derecho).

Dime qué operación deseas realizar y te guiaré con gusto paso a paso.`;
}

/**
 * Llamada a Gemini API con inyección de guías y contexto de permisos
 */
async function callGeminiModel(
  apiKey: string,
  query: string,
  telemetry: TelemetryPayload,
  guides: Array<{ titulo_operacion: string; instrucciones_paso_a_paso: string; modulo: string; rol_permitido: string[] }>,
  kbArticles: Array<{ titulo: string; solucion_tecnica: string; solucion_usuario: string }>,
  deviceConfig: Record<string, unknown> | null,
  systemAudit: Record<string, unknown> | null,
  ticketId: string | null,
  operationalDiagnosis: { donde_esta_el_problema: string; que_debe_revisar: string } | null,
  notificationSentToAdmin: boolean
): Promise<string> {
  const isSuperAdmin = telemetry.userRole === "super_admin";
  const systemPrompt = `Eres Umby, asistente virtual y Manual Interactivo Inteligente de la plataforma UMBRAL del Instituto Municipal de la Mujer (IMMUJER).
Tu misión es guiar al usuario paso a paso sobre cómo realizar operaciones según el módulo en el que se encuentre (${telemetry.currentModule}) y los permisos de su perfil (${telemetry.userRole}).

REGLAS ESTRICTAS DE SEGURIDAD Y PERMISOS:
1. Limita tus respuestas estrictamente a las operaciones que el rol "${telemetry.userRole}" tiene permitido realizar en el módulo "${telemetry.currentModule}".
2. Si el usuario solicita realizar una acción prohibida para su rol, indícale amablemente que requiere un rol superior (ej. Coordinador o Super Admin) y explica a quién debe dirigirse.
3. Si el usuario reporta una falla o problema técnico, sé empático y menciona que se ha notificado al Super Admin sobre el componente afectado.
${notificationSentToAdmin ? `Nota de notificación: Se ha enviado alerta al Super Admin sobre: ${operationalDiagnosis?.donde_esta_el_problema}.` : ""}
${ticketId ? `Ticket generado: #${ticketId.substring(0, 8)}` : ""}

Manuales Operativos autorizados para esta consulta:
${JSON.stringify(guides.slice(0, 6))}

Telemetría: Módulo: ${telemetry.currentModule}, Red: ${telemetry.networkStatus}, Bluetooth: ${telemetry.bluetoothStatus}, Último Error: ${telemetry.lastError || "Ninguno"}.`;

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
