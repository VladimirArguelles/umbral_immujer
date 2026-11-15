import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-deploy-token",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const deploySecret = Deno.env.get("DEPLOY_SECRET");

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(
      JSON.stringify({
        error: "Configuración incompleta: SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY ausente en el entorno.",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }

  // 1. Verificación de Seguridad: Requiere Token de Despliegue secreto o JWT de Super Admin
  const deployToken = req.headers.get("x-deploy-token");
  const authHeader = req.headers.get("Authorization");
  let authorized = false;

  if (deploySecret && deployToken && deployToken === deploySecret) {
    authorized = true;
  } else if (authHeader && authHeader.startsWith("Bearer ")) {
    try {
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData } = await userClient.auth.getUser();
      if (userData?.user?.id) {
        const adminClient = createClient(supabaseUrl, serviceRoleKey);
        const { data: profile } = await adminClient
          .from("perfiles")
          .select("rol")
          .eq("id", userData.user.id)
          .maybeSingle();

        if (profile?.rol === "super_admin") {
          authorized = true;
        }
      }
    } catch (_e) {
      authorized = false;
    }
  }

  if (!authorized) {
    return new Response(
      JSON.stringify({
        error: "Acceso denegado: Esta operación requiere permisos de Super Admin o un token de despliegue válido.",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 403,
      }
    );
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  try {
    let targetVersion = "0.1.8";
    let targetBuild = 9;
    let targetNotes = "Optimización de responsividad móvil en asistente Umby, Consola de Diagnóstico, filtros y sincronización de incidencias en Notificaciones.";

    if (req.method === "POST") {
      try {
        const body = await req.json();
        if (body?.version) targetVersion = String(body.version).trim();
        if (body?.build) targetBuild = parseInt(String(body.build), 10) || targetBuild;
        if (body?.notes) targetNotes = String(body.notes).trim();
      } catch (_) {
        // Usar valores predeterminados si no se envió body JSON
      }
    }

    // 1. Actualizar app_build_number
    const { error: errBuild } = await adminClient.from("configuracion_general").upsert({
      clave: "app_build_number",
      valor: targetBuild,
      descripcion: "Número entero de compilación de la última versión",
      updated_at: new Date().toISOString(),
    }, { onConflict: "clave" });

    if (errBuild) {
      throw new Error(`Fallo al actualizar app_build_number: ${errBuild.message}`);
    }

    // 2. Actualizar app_version_latest
    const { error: errVersion } = await adminClient.from("configuracion_general").upsert({
      clave: "app_version_latest",
      valor: targetVersion,
      descripcion: "Versión semántica más reciente publicada",
      updated_at: new Date().toISOString(),
    }, { onConflict: "clave" });

    if (errVersion) {
      throw new Error(`Fallo al actualizar app_version_latest: ${errVersion.message}`);
    }

    // 3. Actualizar app_update_notes
    const { error: errNotes } = await adminClient.from("configuracion_general").upsert({
      clave: "app_update_notes",
      valor: targetNotes,
      updated_at: new Date().toISOString(),
    }, { onConflict: "clave" });

    if (errNotes) {
      throw new Error(`Fallo al actualizar app_update_notes: ${errNotes.message}`);
    }

    return new Response(JSON.stringify({ success: true, version: targetVersion, build: targetBuild }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
