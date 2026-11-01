import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

interface RateResponse {
  promedio: number | string;
  fechaActualizacion?: string;
  moneda?: string;
  fuente?: string;
}

serve(async (req: Request) => {
  // Manejo de preflight CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Variables de entorno SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY requeridas.");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Consultar Tasa Oficial BCV para USD
    let tasaUsd = 0;
    let fechaActualizacion = new Date().toISOString().split("T")[0];

    try {
      const resUsd = await fetch("https://ve.dolarapi.com/v1/dolares/oficial", {
        headers: { Accept: "application/json" },
      });
      if (resUsd.ok) {
        const dataUsd: RateResponse = await resUsd.json();
        tasaUsd = parseFloat(String(dataUsd.promedio));
        if (dataUsd.fechaActualizacion) {
          fechaActualizacion = dataUsd.fechaActualizacion.split("T")[0];
        }
      }
    } catch (e) {
      console.warn("Fallo endpoint primario USD, reintentando fallback...", e);
    }

    // Fallback USD si es necesario
    if (!tasaUsd || tasaUsd <= 0) {
      try {
        const resFallback = await fetch("https://ve.dolarapi.com/v1/dolares", {
          headers: { Accept: "application/json" },
        });
        if (resFallback.ok) {
          const list: RateResponse[] = await resFallback.json();
          const oficial = list.find((item) => item.fuente === "oficial") || list[0];
          if (oficial) {
            tasaUsd = parseFloat(String(oficial.promedio));
            if (oficial.fechaActualizacion) {
              fechaActualizacion = oficial.fechaActualizacion.split("T")[0];
            }
          }
        }
      } catch (e) {
        console.error("Error en fallback USD:", e);
      }
    }

    // 2. Consultar Tasa Oficial BCV para EUR
    let tasaEur = 0;
    try {
      const resEur = await fetch("https://ve.dolarapi.com/v1/euros/oficial", {
        headers: { Accept: "application/json" },
      });
      if (resEur.ok) {
        const dataEur: RateResponse = await resEur.json();
        tasaEur = parseFloat(String(dataEur.promedio));
      }
    } catch (e) {
      console.warn("Fallo endpoint primario EUR...", e);
    }

    // Fallback EUR si es necesario
    if (!tasaEur || tasaEur <= 0) {
      try {
        const resFallbackEur = await fetch("https://ve.dolarapi.com/v1/euros", {
          headers: { Accept: "application/json" },
        });
        if (resFallbackEur.ok) {
          const listEur: RateResponse[] = await resFallbackEur.json();
          const oficialEur = listEur.find((item) => item.fuente === "oficial") || listEur[0];
          if (oficialEur) {
            tasaEur = parseFloat(String(oficialEur.promedio));
          }
        }
      } catch (e) {
        console.error("Error en fallback EUR:", e);
      }
    }

    if (!tasaUsd || tasaUsd <= 0) {
      throw new Error("No se pudo obtener una tasa oficial BCV válida para USD.");
    }
    if (!tasaEur || tasaEur <= 0) {
      tasaEur = Number((tasaUsd * 1.08).toFixed(4)); // Referencia aproximada si EUR no responde
    }

    // Fecha a registrar (usar la fecha oficial de la tasa o la fecha actual)
    const fechaRegistro = fechaActualizacion || new Date().toISOString().split("T")[0];

    // 3. Insertar o actualizar en tabla tasa_cambiaria
    const { data: upsertData, error: upsertError } = await supabase
      .from("tasa_cambiaria")
      .upsert(
        {
          fecha: fechaRegistro,
          tasa_bcv: tasaUsd,
          tasa_eur: tasaEur,
          creado_en: new Date().toISOString(),
        },
        { onConflict: "fecha" }
      )
      .select();

    if (upsertError) {
      throw upsertError;
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Tasas sincronizadas correctamente con el BCV.",
        fecha: fechaRegistro,
        tasa_bcv: tasaUsd,
        tasa_eur: tasaEur,
        data: upsertData,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error al sincronizar tasas BCV:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: (error as Error).message,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
