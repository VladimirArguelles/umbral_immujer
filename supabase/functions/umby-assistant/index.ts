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

interface ConversationItem {
  sender: "user" | "assistant";
  text: string;
}

interface RequestBody {
  // Parámetros directos o de primer nivel
  query?: string;
  message?: string;
  userRole?: string;
  role?: string;
  currentModule?: string;
  module?: string;
  errorContext?: string;
  lastError?: string;
  userId?: string;
  userName?: string;

  // Objeto de telemetría emitido por la app cliente Flutter
  telemetry?: TelemetryPayload;

  // Historial contextual de la conversación
  conversationHistory?: ConversationItem[];

  // Flag para apertura automática de tickets ante excepciones críticas
  autoTicketOnCritical?: boolean;
}

interface GuideItem {
  id?: string;
  modulo: string;
  titulo_operacion: string;
  instrucciones_paso_a_paso: string;
  rol_permitido: string[];
}

interface SupportItem {
  id?: string;
  categoria: string;
  codigo_error?: string;
  titulo: string;
  sintoma: string;
  causa_raiz: string;
  solucion_guiada: string;
  solucion_tecnica_sql?: string;
  severidad: string;
}

serve(async (req: Request) => {
  // Manejo de preflight CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Configuración de credenciales y variables de entorno seguras
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? supabaseAnonKey;

    // Header de autorización del usuario (JWT)
    const authHeader = req.headers.get("Authorization");

    // Cliente 1 (Seguridad RLS): Ejecuta consultas con la identidad del usuario autenticado
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: authHeader ? { Authorization: authHeader } : undefined,
      },
      auth: {
        persistSession: false,
      },
    });

    // Cliente 2 (Operaciones Administrativas Internas): Tickets de sistema y alertas globales
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
      },
    });

    // 2. Extracción y normalización de parámetros recibidos desde Flutter
    const body: RequestBody = await req.json().catch(() => ({}));
    const query = (body.message || body.query || "").trim();
    const telemetry = body.telemetry || {};

    // Normalización del rol del usuario
    let rawRole = (body.userRole || body.role || telemetry.userRole || "alumno")
      .toLowerCase()
      .trim()
      .replace(/[\s\-]/g, "_");

    if (
      rawRole === "superadmin" ||
      rawRole === "super_admin" ||
      rawRole === "admin" ||
      rawRole === "administrador"
    ) {
      rawRole = "super_admin";
    } else if (rawRole === "docente" || rawRole === "maestro") {
      rawRole = "profesor";
    } else if (rawRole === "estudiante" || rawRole === "participante") {
      rawRole = "alumno";
    }
    const role = rawRole;
    const isSuperAdmin = role === "super_admin";
    const isCoordinator = role === "coordinador" || isSuperAdmin;
    const isTeacher = role === "profesor" || isSuperAdmin;

    // Módulo, error y contexto de usuario
    const currentModule = (
      body.currentModule ||
      body.module ||
      telemetry.currentModule ||
      "general"
    )
      .toLowerCase()
      .trim();

    const lastError = body.errorContext || body.lastError || telemetry.lastError || null;
    const userId = body.userId || telemetry.userId || null;
    const userName = body.userName || telemetry.userName || "Usuario";

    // 3. Consulta de tablas de Supabase aplicando estrictamente las políticas RLS
    // A) Guías operativas oficiales (filtradas por RLS según el rol del usuario conectado)
    let guides: GuideItem[] = [];
    try {
      const { data: guidesData, error: guidesErr } = await userClient
        .from("guia_operaciones")
        .select("id, modulo, titulo_operacion, instrucciones_paso_a_paso, rol_permitido");

      if (!guidesErr && Array.isArray(guidesData)) {
        guides = guidesData as GuideItem[];
      }
    } catch (_err) {
      // Manejo silencioso ante problemas de red
    }

    // B) Base de conocimiento técnico de soporte (política RLS para usuarios autenticados)
    let supportKnowledge: SupportItem[] = [];
    try {
      const { data: supportData, error: supportErr } = await userClient
        .from("soporte_conocimiento")
        .select(
          "id, categoria, codigo_error, titulo, sintoma, causa_raiz, solucion_guiada, solucion_tecnica_sql, severidad"
        );

      if (!supportErr && Array.isArray(supportData)) {
        supportKnowledge = supportData as SupportItem[];
      }
    } catch (_err) {
      // Manejo silencioso
    }

    // Diagnóstico de periféricos (impresora / bluetooth) si aplica
    let diagnosticResult: Record<string, unknown> | null = null;
    const isDeviceOrPrintingIssue =
      /impres|bluetooth|pos|ticket|termic/i.test(query) ||
      (lastError != null && /bluetooth|printer|impres/i.test(lastError));

    if (userId && (isDeviceOrPrintingIssue || /diagnostico|verificar/i.test(query))) {
      try {
        const { data: configData } = await userClient.rpc(
          "verificar_configuracion_dispositivo",
          { p_user_id: userId }
        );
        diagnosticResult = configData;
      } catch (_err) {
        // Fallback
      }
    }

    // Diagnóstico del sistema para Super Admin
    let systemAudit: Record<string, unknown> | null = null;
    if (isSuperAdmin && (/sistema|auditoria|rls|bd|postgres|tablas|tickets/i.test(query) || lastError)) {
      try {
        const { data: auditData } = await userClient.rpc("obtener_diagnostico_sistema");
        systemAudit = auditData;
      } catch (_err) {
        // Fallback
      }
    }

    // Registro automático de ticket ante fallas críticas
    let autoTicketId: string | null = null;
    const isCriticalFailure =
      lastError &&
      (lastError.includes("42501") ||
        lastError.toLowerCase().includes("permission denied") ||
        lastError.toLowerCase().includes("socketexception") ||
        lastError.toLowerCase().includes("jwt") ||
        lastError.toLowerCase().includes("fatal"));

    if (isCriticalFailure && userId && (body.autoTicketOnCritical ?? true)) {
      try {
        const { data: ticketRes } = await adminClient.rpc("registrar_ticket_soporte", {
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

    // Detección de incidencias operativas y diagnóstico de causas
    const isExplicitError =
      /problema|falla|fallo|error|no puedo|no deja|no funciona|no imprime|no guarda|se trab|bug|denegad|invalido|incorrecto|bloquead|42501|ayuda con error|falla al|no sincroniza/i.test(
        query
      );
    const isOperationIssue =
      isExplicitError ||
      (lastError != null && lastError.length > 0 && /error|fall|problema|ayuda con fallo/i.test(query));

    let operationalDiagnosis: { donde_esta_el_problema: string; que_debe_revisar: string } | null = null;
    let notificationSentToAdmin = false;

    if (isOperationIssue) {
      operationalDiagnosis = analyzeOperationalIssue(query, currentModule, role, lastError, telemetry);
      try {
        const notifTitle = `⚠️ Incidencia Operativa en [${currentModule.toUpperCase()}]: ${userName}`;
        const notifMensaje = `El usuario ${userName} (${role}) reportó un problema:\n"${query.substring(0, 160)}"\n\n📍 Dónde: ${operationalDiagnosis.donde_esta_el_problema}\n🛠️ Revisar: ${operationalDiagnosis.que_debe_revisar}`;

        await adminClient.from("notificaciones").insert({
          rol_destino: "super_admin",
          usuario_origen_id: userId || null,
          titulo: notifTitle,
          mensaje: notifMensaje,
          tipo: "incidencia_operacion",
          datos: {
            modulo: currentModule,
            usuario_nombre: userName,
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

    // 4. Conexión con Google Gemini (gemini-2.5-flash) o motor local de respaldo
    let responseText = "";
    let modelUsed = "local-manual-fallback";

    if (geminiApiKey && geminiApiKey.trim().length > 0) {
      try {
        responseText = await callGeminiModel(
          geminiApiKey.trim(),
          query,
          role,
          currentModule,
          userName,
          lastError,
          telemetry,
          guides,
          supportKnowledge,
          body.conversationHistory,
          autoTicketId
        );
        modelUsed = "gemini-2.5-flash";
      } catch (geminiError) {
        console.warn("[Umby-Assistant] Fallback a motor interactivo tras error en Gemini:", geminiError);
        responseText = buildInteractiveManualResponse(
          query,
          telemetry,
          guides,
          diagnosticResult,
          systemAudit,
          autoTicketId,
          operationalDiagnosis,
          notificationSentToAdmin,
          isSuperAdmin,
          isCoordinator,
          isTeacher
        );
      }
    } else {
      responseText = buildInteractiveManualResponse(
        query,
        telemetry,
        guides,
        diagnosticResult,
        systemAudit,
        autoTicketId,
        operationalDiagnosis,
        notificationSentToAdmin,
        isSuperAdmin,
        isCoordinator,
        isTeacher
      );
    }

    // 5. Respuesta JSON estructurada hacia Flutter
    return new Response(
      JSON.stringify({
        success: true,
        assistant: "Umby",
        role: "Manual Interactivo y Soporte Tecnico",
        model: modelUsed,
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
            normalizedRole: role,
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

// =============================================================================
// CONEXIÓN CON GOOGLE GEMINI (gemini-2.5-flash)
// =============================================================================
async function callGeminiModel(
  apiKey: string,
  query: string,
  role: string,
  currentModule: string,
  userName: string,
  lastError: string | null,
  telemetry: TelemetryPayload,
  guides: GuideItem[],
  supportKnowledge: SupportItem[],
  conversationHistory?: ConversationItem[],
  autoTicketId?: string | null
): Promise<string> {
  const isSuperAdmin = role === "super_admin";
  const isCoordinator = role === "coordinador";
  const isTeacher = role === "profesor";

  // System Prompt contextualizado según el perfil del usuario, módulo y políticas RLS
  let systemPrompt = `Eres Umby, el asistente virtual oficial, soporte técnico y manual interactivo inteligente de la plataforma UMBRAL del Instituto Municipal de la Mujer (IMMUJER).

OBJETIVO PRINCIPAL:
Guiar al usuario paso a paso de manera cordial, clara y precisa según su rol oficial (${role.toUpperCase()}) y el módulo en el que se encuentra (${currentModule.toUpperCase()}).

DIRECTRICES POR ROL:`;

  if (isSuperAdmin) {
    systemPrompt += `
- ROL ACTIVO: Super Administrador (DevOps / Arquitectura UMBRAL).
- Tienes acceso irrestricto y total a todos los módulos y opciones del sistema.
- Puedes ofrecer soporte avanzado sobre base de datos PostgreSQL, auditoría de políticas RLS, sincronización de tasas BCV, administración de perfiles y depuración de telemetría de errores técnicos.`;
  } else if (isCoordinator) {
    systemPrompt += `
- ROL ACTIVO: Coordinación General IMMUJER.
- Guiar en la gestión integral de formaciones y cursos, asignación de docentes, revisión y aprobación de temarios propuestos por profesores, inscripción y matrícula formal de alumnas por cédula de identidad, configuración de impresoras térmicas ESC/POS (Bluetooth/Red) para comprobantes de aportes, y descarga de reportes oficiales en PDF.`;
  } else if (isTeacher) {
    systemPrompt += `
- ROL ACTIVO: Profesor / Docente Formador.
- Guiar en el pase de lista de asistencia (Presente, Ausente, Justificada), diseño y activación de encuestas de satisfacción, cálculo y proyección de insumos para talleres prácticos, y redacción de propuestas de temarios para aprobación de Coordinación.
- REGLA CLAVE PARA ALUMNAS: Si el profesor consulta sobre inscribir, registrar o añadir alumnas a su curso, aclara con amabilidad que la matrícula formal la realiza Coordinación desde la sección Cursos -> Inscripciones, y que una vez inscrita aparecerá de inmediato en su lista de asistencia.`;
  } else {
    systemPrompt += `
- ROL ACTIVO: Alumna / Participante.
- Explicar de manera sencilla y cordial cómo consultar cursos matriculados, verificar su asistencia acumulada, registrar aportes prácticos de talleres y responder encuestas institucionales.
- No mostrar detalles técnicos de base de datos ni configuraciones administrativas.`;
  }

  systemPrompt += `

REGLAS ESTRICTAS DE SEGURIDAD Y PRIVACIDAD:
1. Jamás menciones que se enviaron notificaciones secretas al administrador o que se activaron alertas internas en segundo plano.
2. Formato: Utiliza GitHub Markdown claro, con viñetas, pasos numerados en negrita y títulos legibles.
3. Si el usuario pregunta "¿En qué me puedes ayudar?" o similar, resume las funciones disponibles específicamente para su rol (${role}) en el módulo "${currentModule}".
4. Si hay una consulta sobre errores o fallas operativas, proporciona soluciones paso a paso directas basadas en las guías y la base de conocimiento disponibles.`;

  if (lastError) {
    systemPrompt += `\n\nCONTEXTO DE ERROR TÉCNICO CAPTURADO: "${lastError}"\nProporciona instrucciones claras y amigables para resolverlo o verificar la causa.`;
  }

  if (autoTicketId) {
    systemPrompt += `\n\nTicket de soporte generado para esta sesión: #${autoTicketId.substring(0, 8)}.`;
  }

  if (guides && guides.length > 0) {
    systemPrompt += `\n\nMANUALES Y GUÍAS OPERATIVAS AUTORIZADAS (Verificadas por RLS):\n${JSON.stringify(
      guides.slice(0, 6).map((g) => ({
        titulo: g.titulo_operacion,
        modulo: g.modulo,
        pasos: g.instrucciones_paso_a_paso,
      }))
    )}`;
  }

  if (supportKnowledge && supportKnowledge.length > 0) {
    systemPrompt += `\n\nBASE DE CONOCIMIENTO TÉCNICO DE SOPORTE:\n${JSON.stringify(
      supportKnowledge.slice(0, 4).map((s) => ({
        titulo: s.titulo,
        sintoma: s.sintoma,
        solucion: s.solucion_guiada,
        categoria: s.categoria,
      }))
    )}`;
  }

  systemPrompt += `\n\nTelemetría activa: Módulo: ${currentModule}, Red: ${telemetry.networkStatus || "Normal"}, Bluetooth: ${telemetry.bluetoothStatus || "N/A"}.`;

  // Construcción de contenidos para Gemini API v1beta
  const contents: Array<{ role: string; parts: Array<{ text: string }> }> = [];

  // Agregar historial previo si existe
  if (Array.isArray(conversationHistory) && conversationHistory.length > 0) {
    for (const msg of conversationHistory.slice(-6)) {
      if (msg && msg.text) {
        contents.push({
          role: msg.sender === "user" ? "user" : "model",
          parts: [{ text: msg.text }],
        });
      }
    }
  }

  // Agregar el mensaje actual del usuario
  contents.push({
    role: "user",
    parts: [{ text: query }],
  });

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      system_instruction: {
        parts: [{ text: systemPrompt }],
      },
      contents: contents,
      generationConfig: {
        temperature: 0.25,
        topP: 0.95,
        maxOutputTokens: 1500,
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Gemini API respondió con status ${response.status}: ${errorText}`);
  }

  const json = await response.json();
  const text = json?.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!text || typeof text !== "string" || text.trim().length === 0) {
    throw new Error("Respuesta vacía recibida del modelo Gemini.");
  }

  return text.trim();
}

// =============================================================================
// DIAGNÓSTICO DE INCIDENCIAS OPERATIVAS
// =============================================================================
function analyzeOperationalIssue(
  query: string,
  module: string,
  role: string,
  lastError: string | null,
  telemetry: TelemetryPayload
): { donde_esta_el_problema: string; que_debe_revisar: string } {
  const q = query.toLowerCase();
  const err = (lastError || "").toLowerCase();

  if (
    q.includes("impres") ||
    q.includes("bluetooth") ||
    q.includes("ticket") ||
    err.includes("printer") ||
    err.includes("bluetooth")
  ) {
    return {
      donde_esta_el_problema: "Subsistema de Impresión Térmica ESC/POS (Módulo de Tickets / Bluetooth)",
      que_debe_revisar:
        "1. Verificar si la impresora Bluetooth está encendida y vinculada al dispositivo.\n2. En Web, verificar si el navegador permite el diálogo de impresión nativo.\n3. Comprobar registros en tabla configuraciones_impresora para el usuario.\n4. Si es Android, revisar permisos de ubicación y BLUETOOTH_CONNECT.",
    };
  }

  if (
    q.includes("guardar") ||
    q.includes("crear") ||
    q.includes("permiso") ||
    err.includes("42501") ||
    err.includes("row-level security")
  ) {
    return {
      donde_esta_el_problema: "Seguridad RLS en PostgreSQL o Permisos de Rol Insuficientes",
      que_debe_revisar:
        "1. Revisar políticas RLS para la tabla afectada en Supabase (error 42501).\n2. Verificar que el campo rol en perfiles corresponda al esperado ('" +
        role +
        "').\n3. Confirmar que el token JWT del usuario contenga el claim auth.uid() activo.",
    };
  }

  if (q.includes("bcv") || q.includes("tasa") || q.includes("dolar") || q.includes("cambio")) {
    return {
      donde_esta_el_problema: "Sincronización de Tasa Cambiaria Oficial BCV (Edge Function / Cron Job)",
      que_debe_revisar:
        "1. Verificar la última fecha de actualización en public.tasas_cambio_bcv.\n2. Probar la Edge Function sync-bcv-rate desde el panel de Supabase.\n3. Comprobar conectividad hacia la fuente oficial BCV.",
    };
  }

  if (q.includes("asistencia") || q.includes("pase de lista")) {
    return {
      donde_esta_el_problema: "Módulo de Asistencias y Clases Prácticas (Flujo Docente/Coordinación)",
      que_debe_revisar:
        "1. Verificar que el profesor tenga asignado el curso en profesores / cursos.\n2. Confirmar que existan alumnas matriculadas en inscripciones para la fecha.\n3. Validar políticas RLS en la tabla asistencias.",
    };
  }

  if (q.includes("temario") || q.includes("propuesta") || q.includes("aprobar")) {
    return {
      donde_esta_el_problema: "Flujo de Aprobación de Temarios (Módulo de Coordinación / Docentes)",
      que_debe_revisar:
        "1. Revisar la tabla solicitudes_aprobacion para solicitudes en estado 'pendiente'.\n2. Comprobar permisos del coordinador para modificar estado a 'aprobado'.",
    };
  }

  if (q.includes("encuesta") || q.includes("evaluacion")) {
    return {
      donde_esta_el_problema: "Módulo de Encuestas y Evaluaciones de Satisfacción",
      que_debe_revisar:
        "1. Verificar permisos en encuestas_participacion.\n2. Confirmar que el curso cuente con inscripciones activas.",
    };
  }

  if (q.includes("reporte") || q.includes("pdf") || q.includes("exportar")) {
    return {
      donde_esta_el_problema: "Motor de Generación de Reportes Consolidados y Exportación PDF",
      que_debe_revisar:
        "1. Verificar las vistas de base de datos view_reporte_*.\n2. Comprobar que no haya campos numéricos nulos en retención o asistencias.",
    };
  }

  return {
    donde_esta_el_problema: `Operación en Módulo [${module.toUpperCase()}] - Interacción de Usuario (${role})`,
    que_debe_revisar: `1. Última traza de error capturada: ${
      lastError || "Sin excepción crítica registrada"
    }.\n2. Estado de red: ${
      telemetry.networkStatus || "Desconocido"
    }.\n3. Verificar consistencia de datos en Supabase para el usuario ${telemetry.userId || "anónimo"}.`,
  };
}

// =============================================================================
// MOTOR LOCAL DE MANUAL INTERACTIVO (FALLBACK ANTE SINCRONIZACIÓN O CAÍDA DE IA)
// =============================================================================
function extractMeaningfulWords(text: string): string[] {
  const stopWords = new Set([
    "como", "cómo", "para", "de", "del", "la", "el", "los", "las", "un", "una",
    "unos", "unas", "en", "que", "qué", "por", "con", "sobre", "donde", "dónde",
    "mis", "tus", "sus", "nuevo", "nueva", "nuevos", "nuevas", "hacer", "puedo",
    "puedes", "me", "te", "se", "al", "a", "este", "esta", "estos", "estas"
  ]);

  return text
    .toLowerCase()
    .replace(/[¿?¡!.,;:()"\-_]/g, " ")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .split(/\s+/)
    .filter((w) => w.length > 2 && !stopWords.has(w));
}

function buildInteractiveManualResponse(
  query: string,
  telemetry: TelemetryPayload,
  guides: GuideItem[],
  deviceConfig: Record<string, unknown> | null,
  systemAudit: Record<string, unknown> | null,
  ticketId: string | null,
  operationalDiagnosis: { donde_esta_el_problema: string; que_debe_revisar: string } | null,
  notificationSentToAdmin: boolean,
  isSuperAdmin: boolean,
  isCoordinator: boolean,
  isTeacher: boolean
): string {
  const q = query.toLowerCase().trim();
  const userName = telemetry.userName || "Usuario";
  const userRole = (telemetry.userRole || "alumno").toLowerCase().trim().replace(/[\s\-]/g, "_");
  const normalizedUserRole =
    userRole === "superadmin" || userRole === "super_admin" ? "super_admin" : userRole;
  const currentModule = (telemetry.currentModule || "general").toLowerCase().trim();

  let headerNotices = "";
  if (ticketId) {
    headerNotices += `> [!CAUTION]\n> **Incidencia Crítica:** Se ha generado automáticamente el ticket **\`#${ticketId.substring(
      0,
      8
    )}\`**.\n\n`;
  }

  // CASO ESPECÍFICO: AÑADIR / REGISTRAR / INSCRIBIR ALUMNAS
  const isAddStudentQuery =
    (/anadir|añadir|agregar|inscribir|matricular|nuevo alumno|nueva alumna|alta alumno|ingresar alumno|crear alumno/i.test(
      q
    ) &&
      /alumno|alumna|estudiante|participante|matricula|inscrip/i.test(q)) ||
    (/como|cómo/i.test(q) &&
      /anadir|añadir|agregar|inscribir|matricular/i.test(q) &&
      /alumno|alumna|estudiante/i.test(q));

  if (isAddStudentQuery) {
    if (currentModule === "profesores" && !isCoordinator) {
      return `${headerNotices}### 📋 Gestión de Alumnas e Inscripciones en Profesores

Profesor(a) **${userName}**, en la plataforma UMBRAL IMMUJER la incorporación y matrícula de nuevas alumnas en los cursos se gestiona formalmente desde el **Módulo de Coordinación**:

1. **Gestión Administrativa:** La Coordinación registra a la participante con su Cédula de Identidad, Nombre Completo y Teléfono en la plataforma.
2. **Asignación al Curso:** Al matricular a la alumna en tu curso formativo activo, el sistema la vincula automáticamente a tu grupo.
3. **Pase de Lista Automático:** La alumna aparecerá de inmediato en tu listado de **Asistencias** para que puedas registrar su pase de lista, evaluar sus aportes prácticos o incluirla en las encuestas de satisfacción.

💡 **¿Necesitas inscribir a una alumna de inmediato?** Comunícate con la Coordinación del IMMUJER para realizar la asignación desde la pestaña **Cursos** -> **Inscripciones**.`;
    }

    return `${headerNotices}### 📖 Guía Paso a Paso: Cómo inscribir o matricular una nueva alumna en un curso

Hola, **${userName}**. Aquí tienes las instrucciones oficiales para realizar esta operación en **Coordinación**:

1. **Ubicación:** Dirígete al Módulo de **Coordinación**, pestaña **"Cursos"**.
2. **Seleccionar Formación:** Pulsa sobre el curso activo donde deseas añadir a la participante.
3. **Inscribir Alumna:** Selecciona la opción **"Inscripciones"** o **"Matricular Alumna"**.
4. **Búsqueda y Registro:** Busca a la alumna por su Cédula de Identidad o regístrala con sus datos personales si es nueva en la plataforma.
5. **Confirmar:** Pulsa **"Confirmar Inscripción"**. La alumna quedará asignada y aparecerá de inmediato en el listado de asistencia del profesor responsable.`;
  }

  // CASO 1: CONSULTA DE CAPACIDADES GENERALES
  const isHelpQuery =
    /ayud|que puedes hacer|que puedo hacer|capacidades|funciones|opciones|orienta/i.test(q) &&
    !/encuesta|asistencia|curso|impresora|perfil|tema|propuesta/i.test(q);

  if (isHelpQuery) {
    if (
      currentModule === "profesores" ||
      (isTeacher && currentModule !== "coordinacion" && currentModule !== "alumnos")
    ) {
      return `${headerNotices}¡Hola, **${userName}**! Como tu **Manual Interactivo en el Módulo de Profesores**, puedo guiarte paso a paso en:

- 📋 **Pase de Lista:** Cómo registrar la asistencia de tus alumnas en clases prácticas y justificar faltas.
- 📊 **Creación de Encuestas:** Cómo diseñar, programar y publicar encuestas de satisfacción para tus grupos.
- 📝 **Propuestas de Temarios:** Cómo redactar y enviar propuestas de nuevas sesiones formativas a Coordinación.
- 👤 **Mi Perfil Docente:** Dónde actualizar tu fotografía institucional, número telefónico y alternar el tema visual.

Selecciona uno de los temas rápidos o pregúntame directamente lo que desees realizar.`;
    }

    if (currentModule === "coordinacion" || isCoordinator) {
      return `${headerNotices}Hola, **${userName}**. Como tu **Manual Interactivo de Coordinación**, estoy preparado para orientarte en:

- 🎓 **Gestión de Cursos:** Registro, asignación de áreas formativas (Textil, Repostería, Peluquería) y horarios.
- 👨‍🏫 **Supervisión Docente:** Revisión y aprobación de propuestas de temarios enviadas por profesores.
- 🖨️ **Impresión Térmica:** Vinculación de impresoras Bluetooth ESC/POS y emisión de comprobantes de aportes.
- 📈 **Reportes Institucionales:** Filtrado de métricas y descarga de reportes oficiales en PDF desde "Ver Registros".
- 👤 **Mi Perfil:** Actualización de tus datos institucionales y preferencias.

¿En qué tarea o proceso requieres asistencia hoy?`;
    }

    if (isSuperAdmin) {
      return `${headerNotices}Hola, **${userName}** (Super Admin). Como tu **Manual Interactivo y Soporte DevOps UMBRAL**:

- ⚙️ **Telemetría y Base de Datos:** Auditoría RLS en PostgreSQL, diagnóstico de tablas e índices.
- 💵 **Tasa Oficial BCV:** Sincronización automática de divisas y forzado manual con la Edge Function.
- 👥 **Usuarios y Roles:** Modificación de permisos de perfiles (Super Admin, Coordinador, Profesor, Alumno).
- 🔔 **Centro de Alertas:** Notificaciones en vivo de incidencias operativas y fallas reportadas por los usuarios.

Indícame qué operación o diagnóstico deseas ejecutar.`;
    }

    return `${headerNotices}¡Hola, **${userName}**! Soy **Umby**, tu manual interactivo en UMBRAL IMMUJER.

En tu pantalla actual (**${currentModule}**), te oriento paso a paso en:
- 📚 Consultar tus cursos activos y porcentaje de asistencia acumulada.
- 💵 Registrar comprobantes de aportes para talleres prácticos.
- ⭐ Responder las encuestas de satisfacción institucional.
- 👤 Actualizar tu fotografía y número de teléfono en **Mi Perfil** (avatar superior derecho).

Dime qué operación deseas realizar y te guiaré con gusto.`;
  }

  // CASO 2: BÚSQUEDA INTELIGENTE DE GUÍAS PASO A PASO
  const queryWords = extractMeaningfulWords(q);
  let bestGuide: GuideItem | null = null;
  let bestScore = 0;

  for (const guide of guides) {
    const guideWords = extractMeaningfulWords(guide.titulo_operacion);
    let score = 0;
    let matchedDistinctWords = 0;

    for (const qw of queryWords) {
      let wordMatched = false;
      for (const gw of guideWords) {
        if (qw === gw) {
          score += 4;
          wordMatched = true;
          break;
        } else if (
          qw.length >= 4 &&
          gw.length >= 4 &&
          (qw.startsWith(gw.substring(0, 4)) || gw.startsWith(qw.substring(0, 4)))
        ) {
          score += 2;
          wordMatched = true;
          break;
        }
      }
      if (wordMatched) {
        matchedDistinctWords++;
      }
    }

    if (queryWords.length >= 2 && matchedDistinctWords < 2 && score < 6) {
      continue;
    }

    if (score >= 4) {
      if (guide.modulo === currentModule) {
        score += 1.5;
      } else if (guide.modulo === "general") {
        score += 0.5;
      }
    }

    if (score > bestScore && score >= 4.5) {
      bestScore = score;
      bestGuide = guide;
    }
  }

  if (bestGuide) {
    const isAllowed =
      isSuperAdmin ||
      bestGuide.rol_permitido.includes("todos") ||
      bestGuide.rol_permitido.includes(normalizedUserRole) ||
      (normalizedUserRole === "profesor" && bestGuide.rol_permitido.includes("profesor")) ||
      (normalizedUserRole === "coordinador" && bestGuide.rol_permitido.includes("coordinador"));

    if (!isAllowed) {
      return `${headerNotices}Hola, **${userName}**.

La operación **"${bestGuide.titulo_operacion}"** está reservada exclusivamente para los roles de **${bestGuide.rol_permitido
        .join(" / ")
        .toUpperCase()}**.

Tu perfil actual tiene rol de **${normalizedUserRole.toUpperCase()}**. En esta pantalla (**${currentModule}**), puedes realizar consultas y operaciones correspondientes a tu rol, pero no tienes permisos de modificación para esta función. Si consideras que requieres este acceso, comunícate con la Coordinación del IMMUJER o el Super Admin.`;
    }

    return `${headerNotices}### 📖 Guía Paso a Paso: ${bestGuide.titulo_operacion}

Hola, **${userName}**. Aquí tienes las instrucciones oficiales para realizar esta operación en el **${currentModule.toUpperCase()}**:

${bestGuide.instrucciones_paso_a_paso}

¿Tienes alguna duda sobre alguno de estos pasos o requieres asistencia adicional?`;
  }

  // CASO 3: RESPUESTAS ADAPTATIVAS POR ROL Y MÓDULO
  if (isSuperAdmin) {
    return `${headerNotices}Hola, **${userName}** (Super Admin). Como tu **Manual Interactivo y Soporte DevOps**:
- **Módulo Activo:** \`${currentModule}\`
- **Operaciones Disponibles:** Gestión global de cursos, sincronización BCV, auditoría de usuarios y configuración de guías.

Puedes consultarme cómo ejecutar cualquier operación paso a paso o solicitar diagnósticos de base de datos.`;
  }

  if (isTeacher || currentModule === "profesores") {
    return `${headerNotices}Profesor(a) **${userName}**, en el **Módulo de Profesores** puedes gestionar el pase de lista de tus cursos, crear encuestas estudiantiles, proyectar costos de insumos para talleres prácticos y proponer actualizaciones de temarios a Coordinación.

¿Sobre qué operación deseas que te guíe paso a paso?`;
  }

  if (isCoordinator || currentModule === "coordinacion") {
    return `${headerNotices}Hola, **${userName}**. Como **Manual Interactivo de Coordinación**, puedo guiarte paso a paso en:
- Registrar y programar nuevos cursos formativos.
- Asignar profesores y aprobar propuestas de temarios.
- Configurar tu impresora térmica y emitir comprobantes de aportes.
- Filtrar y exportar reportes en PDF desde "Ver Registros".

¿Qué operación deseas realizar en este momento?`;
  }

  return `${headerNotices}¡Hola, **${userName}**! Soy **Umby**, tu manual interactivo en UMBRAL IMMUJER.

En tu pantalla actual (**${currentModule}**), tienes permitido:
- Consultar tus asistencias acumuladas y estado de certificación.
- Registrar tus aportes prácticos con referencia de pago.
- Responder encuestas de satisfacción de tus talleres.
- Actualizar tu fotografía y número telefónico en **Mi Perfil** (avatar superior derecho).

Dime qué operación deseas realizar y te guiaré con gusto paso a paso.`;
}
