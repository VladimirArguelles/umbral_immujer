import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: "Configuración de Supabase incompleta en el servidor." }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "No autorizado: falta token de sesión." }, 401);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return jsonResponse({ error: "Sesión inválida o expirada." }, 401);
    }

    const { data: callerProfile, error: profileError } = await adminClient
      .from("perfiles")
      .select("rol")
      .or(`id.eq.${userData.user.id},user_id.eq.${userData.user.id}`)
      .limit(1)
      .maybeSingle();

    if (profileError || callerProfile?.rol !== "super_admin") {
      return jsonResponse({ error: "Acceso denegado: solo Super Admin puede gestionar operadores." }, 403);
    }

    const payload = await req.json();
    const action = String(payload?.action ?? "");

    if (action === "create") {
      const email = String(payload?.email ?? "").trim().toLowerCase();
      const password = String(payload?.password ?? "").trim();
      const nombreCompleto = String(payload?.nombre_completo ?? "").trim();
      const cedula = String(payload?.cedula ?? "").trim();
      const telefono = String(payload?.telefono ?? "").trim();

      if (!email || !email.includes("@")) {
        return jsonResponse({ error: "Ingresa un correo electrónico válido." }, 400);
      }
      if (password.length < 6) {
        return jsonResponse({ error: "La contraseña temporal debe tener al menos 6 caracteres." }, 400);
      }
      if (!nombreCompleto) {
        return jsonResponse({ error: "El nombre completo es obligatorio." }, 400);
      }

      const { data: created, error: createError } = await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          nombre_completo: nombreCompleto,
          cedula: cedula || null,
          telefono: telefono || null,
          rol: "operador_inscripcion",
        },
      });

      if (createError || !created?.user) {
        return jsonResponse(
          { error: createError?.message ?? "No se pudo crear la credencial temporal." },
          400,
        );
      }

      const newUserId = created.user.id;
      const { error: upsertError } = await adminClient.from("perfiles").upsert(
        {
          id: newUserId,
          user_id: newUserId,
          nombre_completo: nombreCompleto,
          cedula: cedula || null,
          telefono: telefono || null,
          correo: email,
          email,
          rol: "operador_inscripcion",
          acceso_activo: true,
        },
        { onConflict: "id" },
      );

      if (upsertError) {
        return jsonResponse({ error: upsertError.message }, 400);
      }

      return jsonResponse({
        success: true,
        user_id: newUserId,
        email,
        nombre_completo: nombreCompleto,
      });
    }

    if (action === "toggle_access") {
      const userId = String(payload?.user_id ?? "").trim();
      const activo = Boolean(payload?.activo);
      if (!userId) {
        return jsonResponse({ error: "Falta el identificador del usuario." }, 400);
      }

      const { error: banError } = await adminClient.auth.admin.updateUserById(userId, {
        ban_duration: activo ? "none" : "876000h",
      });
      if (banError) {
        return jsonResponse({ error: banError.message }, 400);
      }

      const { error: perfilError } = await adminClient
        .from("perfiles")
        .update({ acceso_activo: activo, updated_at: new Date().toISOString() })
        .or(`id.eq.${userId},user_id.eq.${userId}`)
        .eq("rol", "operador_inscripcion");

      if (perfilError) {
        return jsonResponse({ error: perfilError.message }, 400);
      }

      return jsonResponse({ success: true, user_id: userId, acceso_activo: activo });
    }

    if (action === "delete") {
      const userId = String(payload?.user_id ?? "").trim();
      if (!userId) {
        return jsonResponse({ error: "Falta el identificador del usuario." }, 400);
      }
      if (userId === userData.user.id) {
        return jsonResponse({ error: "No puedes eliminar tu propia cuenta." }, 400);
      }

      await adminClient.from("perfiles").delete().or(`id.eq.${userId},user_id.eq.${userId}`);
      const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
      if (deleteError) {
        return jsonResponse({ error: deleteError.message }, 400);
      }

      return jsonResponse({ success: true, user_id: userId });
    }

    return jsonResponse({ error: `Acción no soportada: ${action}` }, 400);
  } catch (err) {
    return jsonResponse({ error: err instanceof Error ? err.message : String(err) }, 500);
  }
});
