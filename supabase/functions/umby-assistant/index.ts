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

    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);

    const body: RequestBody = await req.json();
    const query = (body.query || "").trim();
    const telemetry = body.telemetry || {};

    // NORMALIZACIÓN ESTRICTA: SUPERADMIN = SUPER_ADMIN
    let rawRole = (telemetry.userRole || "alumno").toLowerCase().trim().replace(/[\s\-]/g, "_");
    if (rawRole === "superadmin" || rawRole === "super_admin" || rawRole === "admin" || rawRole === "administrador") {
      rawRole = "super_admin";
    }
    const role = rawRole;
    const isSuperAdmin = role === "super_admin";
    const isCoordinator = role === "coordinador" || isSuperAdmin;
    const isTeacher = role === "profesor" || isSuperAdmin;
    const lastError = telemetry.lastError || null;
    const currentModule = (telemetry.currentModule || "general").toLowerCase().trim();

    let diagnosticResult: Record<string, unknown> | null = null;
    let autoTicketId: string | null = null;

    // 1. Diagnóstico de dispositivos
    const isDeviceOrPrintingIssue = /impres|bluetooth|pos|ticket|termic/i.test(query) ||
      (lastError != null && /bluetooth|printer|impres/i.test(lastError));

    if (telemetry.userId && (isDeviceOrPrintingIssue || /diagnostico|verificar/i.test(query))) {
      try {
        const { data: configData } = await client.rpc("verificar_configuracion_dispositivo", {
          p_user_id: telemetry.userId,
        });
        diagnosticResult = configData;
      } catch (_err) {
        // Fallback
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
    let allGuides: Array<{ titulo_operacion: string; instrucciones_paso_a_paso: string; modulo: string; rol_permitido: string[] }> = [];
    try {
      const { data: guidesData } = await adminClient
        .from("guia_operaciones")
        .select("titulo_operacion, instrucciones_paso_a_paso, modulo, rol_permitido");

      if (guidesData && guidesData.length > 0) {
        allGuides = guidesData;
      }
    } catch (_e) {
      // Fallback
    }

    // 5. DETECCIÓN DE PROBLEMAS EN OPERACIONES Y NOTIFICACIÓN AL SUPER ADMIN
    const isExplicitError = /problema|falla|fallo|error|no puedo|no deja|no funciona|no imprime|no guarda|se trab|bug|denegad|invalido|incorrecto|bloquead|42501|ayuda con error|falla al|no sincroniza/i.test(query);
    const isOperationIssue = isExplicitError ||
      (lastError != null && lastError.length > 0 && /error|fall|problema|ayuda con fallo/i.test(query));

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

    // 6. Generación de Respuesta Inteligente
    let responseText = "";
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (geminiKey) {
      responseText = await callGeminiModel(
        geminiKey,
        query,
        telemetry,
        allGuides,
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
        allGuides,
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

    return new Response(
      JSON.stringify({
        success: true,
        assistant: "Umby",
        role: "Manual Interactivo y Soporte Tecnico",
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
        hint: "Verifique la conexion o contacte al administrador de UMBRAL.",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

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
      donde_esta_el_problema: "Subsistema de Impresion Termica ESC/POS (Modulo de Tickets / Bluetooth)",
      que_debe_revisar: "1. Verificar si la impresora Bluetooth esta emparejada y encendida.\n2. En Web, verificar si el navegador tiene acceso al dialogo de impresion nativo del OS.\n3. Comprobar registros en tabla configuraciones_impresora para el usuario.\n4. Si es Android, revisar permisos BLUETOOTH_CONNECT en tiempo de ejecucion.",
    };
  }

  if (q.includes("guardar") || q.includes("crear") || q.includes("permiso") || err.includes("42501") || err.includes("row-level security")) {
    return {
      donde_esta_el_problema: "Seguridad RLS en PostgreSQL o Permisos de Rol Insuficientes",
      que_debe_revisar: "1. Revisar politicas RLS para la tabla afectada en Supabase (error 42501).\n2. Verificar que el campo rol en perfiles corresponda al esperado ('" + role + "').\n3. Confirmar que el token JWT del usuario contenga el claim auth.uid() activo.",
    };
  }

  if (q.includes("bcv") || q.includes("tasa") || q.includes("dolar") || q.includes("cambio")) {
    return {
      donde_esta_el_problema: "Sincronizacion de Tasa Cambiaria Oficial BCV (Edge Function / Cron Job)",
      que_debe_revisar: "1. Verificar la ultima fecha de actualizacion en public.tasas_cambio_bcv.\n2. Probar la Edge Function sync-bcv-rate desde el panel de Supabase.\n3. Comprobar conectividad hacia la API de consulta BCV o web scraping.",
    };
  }

  if (q.includes("asistencia") || q.includes("pase de lista")) {
    return {
      donde_esta_el_problema: "Modulo de Asistencias y Clases Practicas (Flujo Docente/Coordinacion)",
      que_debe_revisar: "1. Verificar que el profesor tenga asignado el curso en profesores / cursos.\n2. Confirmar que existan alumnos matriculados en inscripciones para la fecha seleccionada.\n3. Validar politicas RLS en la tabla asistencia.",
    };
  }

  if (q.includes("temario") || q.includes("propuesta") || q.includes("aprobar")) {
    return {
      donde_esta_el_problema: "Flujo de Aprobacion de Temarios (Modulo de Coordinacion / Docentes)",
      que_debe_revisar: "1. Revisar la tabla solicitudes_aprobacion para solicitudes en estado 'pendiente'.\n2. Comprobar permisos del coordinador para modificar estado a 'aprobado'.",
    };
  }

  if (q.includes("encuesta") || q.includes("evaluacion")) {
    return {
      donde_esta_el_problema: "Modulo de Encuestas y Evaluaciones de Satisfaccion",
      que_debe_revisar: "1. Verificar permisos en encuestas_participacion.\n2. Confirmar que el curso cuente con inscripciones activas.",
    };
  }

  if (q.includes("reporte") || q.includes("pdf") || q.includes("exportar")) {
    return {
      donde_esta_el_problema: "Motor de Generacion de Reportes Consolidados y Exportacion PDF",
      que_debe_revisar: "1. Verificar las vistas de base de datos view_reporte_*.\n2. Comprobar que no haya campos numericos nulos en retencion o asistencias.",
    };
  }

  return {
    donde_esta_el_problema: `Operacion en Modulo [${module.toUpperCase()}] - Interaccion de Usuario (${role})`,
    que_debe_revisar: `1. Ultima traza de error capturada: ${lastError || "Sin excepcion critica registrada"}.\n2. Estado de red: ${telemetry.networkStatus || "Desconocido"}.\n3. Verificar consistencia de datos en Supabase para el usuario ${telemetry.userId || "anonimo"}.`,
  };
}

/**
 * Normaliza y limpia una cadena de texto para extraccion de palabras clave sin stop words
 */
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
    .replace(/[\u0300-\u036f]/g, "") // Remueve tildes y diacríticos
    .split(/\s+/)
    .filter((w) => w.length > 2 && !stopWords.has(w));
}

function buildInteractiveManualResponse(
  query: string,
  telemetry: TelemetryPayload,
  guides: Array<{ titulo_operacion: string; instrucciones_paso_a_paso: string; modulo: string; rol_permitido: string[] }>,
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
  const normalizedUserRole = (userRole === "superadmin" || userRole === "super_admin") ? "super_admin" : userRole;
  const currentModule = (telemetry.currentModule || "general").toLowerCase().trim();

  let headerNotices = "";
  if (ticketId) {
    headerNotices += `> [!CAUTION]\n> **Incidencia Critica:** Se ha generado automaticamente el ticket **\`#${ticketId.substring(0, 8)}\`**.\n\n`;
  }
  // NOTA: No se inyecta información de notificación técnica al usuario final en las respuestas de chat

  // =========================================================================
  // CASO ESPECÍFICO: AÑADIR / REGISTRAR / INSCRIBIR / MATRICULAR ALUMNOS
  // =========================================================================
  const isAddStudentQuery = (/anadir|añadir|agregar|inscribir|matricular|nuevo alumno|nueva alumna|alta alumno|ingresar alumno|crear alumno/i.test(q) &&
    /alumno|alumna|estudiante|participante|matricula|inscrip/i.test(q)) ||
    (/como|cómo/i.test(q) && /anadir|añadir|agregar|inscribir|matricular/i.test(q) && /alumno|alumna|estudiante/i.test(q));

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

  // =========================================================================
  // CASO 1: CONSULTA DE CAPACIDADES GENERALES ("¿En qué me puedes ayudar?")
  // =========================================================================
  const isHelpQuery = /ayud|que puedes hacer|que puedo hacer|capacidades|funciones|opciones|orienta/i.test(q) &&
    !/encuesta|asistencia|curso|impresora|perfil|tema|propuesta/i.test(q);

  if (isHelpQuery) {
    if (currentModule === "profesores" || (isTeacher && currentModule !== "coordinacion" && currentModule !== "alumnos")) {
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

  // =========================================================================
  // CASO 2: BÚSQUEDA INTELIGENTE DE GUÍAS PASO A PASO (Relevance Matcher Robusto)
  // =========================================================================
  const queryWords = extractMeaningfulWords(q);

  let bestGuide: typeof guides[0] | null = null;
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

    // Regla estricta: Si la consulta tiene 2 o más palabras clave, exigir al menos 2 coincidencias léxicas
    if (queryWords.length >= 2 && matchedDistinctWords < 2 && score < 6) {
      continue;
    }

    // Bonificación por módulo SOLO si ya existe una coincidencia léxica sólida comprobada
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
    // REGLA CRÍTICA: SUPERADMIN Y SUPER_ADMIN TIENEN ACCESO TOTAL A TODAS LAS OPERACIONES
    const isAllowed = isSuperAdmin ||
      bestGuide.rol_permitido.includes("todos") ||
      bestGuide.rol_permitido.includes(normalizedUserRole) ||
      (normalizedUserRole === "profesor" && bestGuide.rol_permitido.includes("profesor")) ||
      (normalizedUserRole === "coordinador" && bestGuide.rol_permitido.includes("coordinador"));

    if (!isAllowed) {
      return `${headerNotices}Hola, **${userName}**.

La operacion **"${bestGuide.titulo_operacion}"** esta reservada exclusivamente para los roles de **${bestGuide.rol_permitido.join(" / ").toUpperCase()}**.

Tu perfil actual tiene rol de **${normalizedUserRole.toUpperCase()}**. En esta pantalla (**${currentModule}**), puedes realizar consultas y operaciones correspondientes a tu rol, pero no tienes permisos de modificacion para esta funcion. Si consideras que requieres este acceso, comunicate con la Coordinacion del IMMUJER o el Super Admin.`;
    }

    return `${headerNotices}### 📖 Guia Paso a Paso: ${bestGuide.titulo_operacion}

Hola, **${userName}**. Aqui tienes las instrucciones oficiales para realizar esta operacion en el **${currentModule.toUpperCase()}**:

${bestGuide.instrucciones_paso_a_paso}

¿Tienes alguna duda sobre alguno de estos pasos o requieres asistencia adicional?`;
  }

  // =========================================================================
  // CASO 3: RESPUESTAS ADAPTATIVAS POR ROL Y MÓDULO
  // =========================================================================

  // --- SUPER ADMIN ---
  if (isSuperAdmin) {
    if (q.includes("rls") || (telemetry.lastError && telemetry.lastError.includes("42501"))) {
      return `${headerNotices}### 🛠️ Diagnostico DevOps: Seguridad RLS en PostgreSQL

**Estado:** Modulo \`${currentModule}\` | Error: \`${telemetry.lastError || "Sin excepcion activa"}\`

\`\`\`sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('perfiles', 'cursos', 'inscripciones', 'tickets_soporte', 'guia_operaciones', 'notificaciones');
\`\`\``;
    }

    if (q.includes("impres") || q.includes("bluetooth")) {
      return `${headerNotices}### 🖨️ Diagnostico Tecnico: Impresora Termica ESC/POS

**Telemetria:** Bluetooth: \`${telemetry.bluetoothStatus || "Desconocido"}\` | Plataforma: \`${telemetry.platform || "Web"}\`

\`\`\`sql
SELECT * FROM public.configuraciones_impresora WHERE usuario_id = '${telemetry.userId || "auth.uid()"}';
\`\`\``;
    }

    return `${headerNotices}Hola, **${userName}** (Super Admin). Como tu **Manual Interactivo y Soporte DevOps**:
- **Modulo Activo:** \`${currentModule}\`
- **Operaciones Disponibles:** Gestion global de cursos, sincronizacion BCV, auditoria de usuarios y configuracion de guias.

Puedes consultarme como ejecutar cualquier operacion paso a paso o solicitar diagnosticos de base de datos.`;
  }

  // --- DOCENTES / PROFESORES ---
  if (isTeacher || currentModule === "profesores") {
    if (q.includes("encuesta") || q.includes("evaluacion")) {
      return `${headerNotices}### 📖 Cómo crear una encuesta para tus alumnos

1. **Ubicación:** En tu panel de Profesores, ve a la pestaña **"Encuestas / Evaluaciones"**.
2. **Crear Encuesta:** Pulsa el botón **"Crear Encuesta"** o el icono **"+"** en la barra superior.
3. **Formulario:** Ingresa el título de la evaluación, selecciona tu curso activo y define los criterios de calificación (escala de 1 a 5 estrellas).
4. **Publicar:** Pulsa **"Activar Encuesta"** para que aparezca al instante en el panel de tus alumnas.`;
    }

    if (q.includes("asistencia") || q.includes("pase de lista")) {
      return `${headerNotices}### 📖 Cómo registrar el pase de lista de asistencia

1. **Ubicación:** Abre la pestaña **"Asistencias"** en el Módulo de Profesores.
2. **Fecha y Curso:** Selecciona el curso y la fecha de la sesión técnica.
3. **Pase de Lista:** Marca cada alumna como Presente (verde), Ausente (rojo) o Justificada (amarillo).
4. **Guardar:** Pulsa **"Guardar Asistencias"** para consolidar los porcentajes en tiempo real.`;
    }

    if (q.includes("tema") || q.includes("temario") || q.includes("propuesta") || q.includes("aprobar")) {
      return `${headerNotices}### 📖 Cómo solicitar la aprobación de un nuevo tema

1. **Ubicación:** Ingresa a la pestaña **"Temarios / Propuestas"** en el Módulo de Profesores.
2. **Proponer Tema:** Toca el botón **"Proponer Tema"**.
3. **Detalles:** Especifica el título de la clase práctica, objetivos pedagógicos e insumos requeridos.
4. **Enviar:** Pulsa **"Enviar a Coordinación"** para que la dirección evalúe y apruebe tu propuesta.`;
    }

    return `${headerNotices}Profesor(a) **${userName}**, en el **Módulo de Profesores** puedes gestionar el pase de lista de tus cursos, crear encuestas estudiantiles, proyectar costos de insumos para talleres prácticos y proponer actualizaciones de temarios a Coordinación.

¿Sobre qué operación deseas que te guíe paso a paso?`;
  }

  // --- COORDINADORES ---
  if (isCoordinator || currentModule === "coordinacion") {
    if (q.includes("curso") || q.includes("crear") || q.includes("registrar")) {
      return `${headerNotices}### 📖 Cómo registrar un nuevo curso en Coordinación

1. **Pestaña Cursos:** En tu panel de Coordinación, abre la primera pestaña **"Cursos"**.
2. **Botón Nuevo Curso:** Pulsa el botón **"Nuevo Curso"** ubicado en la esquina superior.
3. **Completar Datos:** Ingresa el nombre de la formación, selecciona el área técnica (ej. Repostería, Peluquería, Textil), el horario (días y horas) y asigna al profesor responsable.
4. **Guardar:** Pulsa **"Guardar Formación"** para activar las inscripciones al instante.`;
    }

    return `${headerNotices}Hola, **${userName}**. Como **Manual Interactivo de Coordinación**, puedo guiarte paso a paso en:
- Registrar y programar nuevos cursos formativos.
- Asignar profesores y aprobar propuestas de temarios.
- Configurar tu impresora térmica y emitir comprobantes de aportes.
- Filtrar y exportar reportes en PDF desde "Ver Registros".

¿Qué operación deseas realizar en este momento?`;
  }

  // --- ALUMNOS ---
  return `${headerNotices}¡Hola, **${userName}**! Soy **Umby**, tu manual interactivo en UMBRAL IMMUJER.

En tu pantalla actual (**${currentModule}**), tienes permitido:
- Consultar tus asistencias acumuladas y estado de certificación.
- Registrar tus aportes prácticos con referencia de pago.
- Responder encuestas de satisfacción de tus talleres.
- Actualizar tu fotografía y número telefónico en **Mi Perfil** (avatar superior derecho).

Dime qué operación deseas realizar y te guiaré con gusto paso a paso.`;
}

async function callGeminiModel(
  apiKey: string,
  query: string,
  telemetry: TelemetryPayload,
  guides: Array<{ titulo_operacion: string; instrucciones_paso_a_paso: string; modulo: string; rol_permitido: string[] }>,
  deviceConfig: Record<string, unknown> | null,
  systemAudit: Record<string, unknown> | null,
  ticketId: string | null,
  operationalDiagnosis: { donde_esta_el_problema: string; que_debe_revisar: string } | null,
  notificationSentToAdmin: boolean
): Promise<string> {
  const isSuperAdmin = telemetry.userRole === "super_admin" || telemetry.userRole === "superadmin";
  const systemPrompt = `Eres Umby, asistente virtual y Manual Interactivo Inteligente de la plataforma UMBRAL del Instituto Municipal de la Mujer (IMMUJER).
Tu misión es guiar al usuario paso a paso sobre cómo realizar operaciones según el módulo en el que se encuentre (${telemetry.currentModule}) y los permisos de su perfil (${telemetry.userRole}).

REGLAS ESTRICTAS DE SEGURIDAD Y PERMISOS:
1. El rol "super_admin" y "superadmin" son el MISMO rol: tienen acceso total, absoluto e irrestricto a todas las operaciones y módulos. NUNCA le digas al Super Admin que no tiene permisos.
2. Si el usuario solicita realizar una acción prohibida para su rol (ej. Alumno queriendo editar cursos), indícale amablemente que requiere un rol superior (ej. Coordinador o Super Admin) y explica a quién debe dirigirse.
3. Si el usuario pregunta "¿En qué me puedes ayudar?", explica detalladamente las operaciones que puede realizar en el módulo "${telemetry.currentModule}".
4. Si el usuario pregunta sobre cómo añadir, inscribir o matricular una nueva alumna en un curso:
   - En el Módulo de Profesores: Explica que la matriculación la realiza formalmente la Coordinación en la sección de Cursos, y que una vez inscrita aparecerá automáticamente en el listado de asistencia del profesor.
   - En el Módulo de Coordinación / Super Admin: Explica el paso a paso para ir a Cursos -> Seleccionar curso -> Inscribir Alumna por su Cédula.
5. REGLA ESTRICTA: NUNCA menciones en tus respuestas al usuario final que se ha enviado una notificación o alerta al Super Admin ni que se ha reportado una falla técnica interna.
${ticketId ? `Ticket generado: #${ticketId.substring(0, 8)}` : ""}

Manuales Operativos autorizados:
${JSON.stringify(guides.slice(0, 8))}

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
