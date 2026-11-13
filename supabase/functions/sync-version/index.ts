import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  try {
    // 1. Actualizar app_build_number
    await adminClient.from("configuracion_general").upsert({
      clave: "app_build_number",
      valor: 9,
      descripcion: "Número entero de compilación de la última versión",
      updated_at: new Date().toISOString(),
    }, { onConflict: "clave" });

    // 2. Actualizar app_version_latest
    await adminClient.from("configuracion_general").upsert({
      clave: "app_version_latest",
      valor: "0.1.8",
      descripcion: "Versión semántica más reciente publicada",
      updated_at: new Date().toISOString(),
    }, { onConflict: "clave" });

    // 3. Actualizar app_update_notes
    await adminClient.from("configuracion_general").upsert({
      clave: "app_update_notes",
      valor: "Optimización de responsividad móvil en asistente Umby, Consola de Diagnóstico, filtros y sincronización de incidencias en Notificaciones.",
      updated_at: new Date().toISOString(),
    }, { onConflict: "clave" });

    // 4. Intentar ejecutar trigger de sincronización si existe
    try {
      await adminClient.rpc("ejecutar_sync_notificaciones");
    } catch (_) {}

    return new Response(JSON.stringify({ success: true, version: "0.1.8", build: 9 }), {
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
