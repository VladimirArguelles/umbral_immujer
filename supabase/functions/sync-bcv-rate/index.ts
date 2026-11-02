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

function formatDateIso(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
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
    let fechaActualizacion = "";

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
      tasaEur = Number((tasaUsd * 1.08).toFixed(4));
    }

    // 3. Cálculo de la Fecha Efectiva en la Zona Horaria de Venezuela (America/Caracas, UTC-4)
    // En la banca venezolana (BCV), los viernes por la tarde se fija la tasa con fecha valor Lunes.
    // Durante viernes, sábado y domingo la tasa oficial vigente corresponde a la fecha del día lunes.
    const nowCaracas = new Date(
      new Date().toLocaleString("en-US", { timeZone: "America/Caracas" })
    );
    const dayOfWeek = nowCaracas.getDay(); // 0 = Domingo, 1 = Lunes, ..., 5 = Viernes, 6 = Sábado
    const fechaHoy = formatDateIso(nowCaracas);

    let fechaRegistro = fechaHoy;
    let esFinDeSemana = false;

    if (dayOfWeek === 5) {
      // Viernes -> Fecha valor Lunes (+3 días)
      const lunes = new Date(nowCaracas);
      lunes.setDate(nowCaracas.getDate() + 3);
      fechaRegistro = formatDateIso(lunes);
      esFinDeSemana = true;
    } else if (dayOfWeek === 6) {
      // Sábado -> Fecha valor Lunes (+2 días)
      const lunes = new Date(nowCaracas);
      lunes.setDate(nowCaracas.getDate() + 2);
      fechaRegistro = formatDateIso(lunes);
      esFinDeSemana = true;
    } else if (dayOfWeek === 0) {
      // Domingo -> Fecha valor Lunes (+1 día)
      const lunes = new Date(nowCaracas);
      lunes.setDate(nowCaracas.getDate() + 1);
      fechaRegistro = formatDateIso(lunes);
      esFinDeSemana = true;
    } else {
      // Lunes a Jueves: respetar fecha oficial si es posterior/igual a hoy, o usar hoy
      fechaRegistro = (fechaActualizacion && fechaActualizacion >= fechaHoy)
        ? fechaActualizacion
        : fechaHoy;
    }

    // 4. Insertar o actualizar en tabla tasa_cambiaria
    const rowsToUpsert = [
      {
        fecha: fechaRegistro,
        tasa_bcv: tasaUsd,
        tasa_eur: tasaEur,
        creado_en: new Date().toISOString(),
      },
    ];

    // Si es fin de semana y la fecha de hoy es diferente a la del lunes,
    // también aseguramos el registro para la fecha de hoy (evita vacíos al consultar por CURRENT_DATE)
    if (esFinDeSemana && fechaHoy !== fechaRegistro) {
      rowsToUpsert.push({
        fecha: fechaHoy,
        tasa_bcv: tasaUsd,
        tasa_eur: tasaEur,
        creado_en: new Date().toISOString(),
      });
    }

    const { data: upsertData, error: upsertError } = await supabase
      .from("tasa_cambiaria")
      .upsert(rowsToUpsert, { onConflict: "fecha" })
      .select();

    if (upsertError) {
      throw upsertError;
    }

    // 5. Actualización directa de la tasa en configuracion_general
    await supabase
      .from("configuracion_general")
      .update({
        valor: tasaUsd,
        actualizado_en: new Date().toISOString(),
      })
      .eq("clave", "tasa_cambio_oficial");

    try {
      await supabase
        .from("configuracion_general")
        .update({
          valor: tasaEur,
          actualizado_en: new Date().toISOString(),
        })
        .eq("clave", "tasa_eur_oficial");
    } catch (_) {}

    return new Response(
      JSON.stringify({
        success: true,
        message: esFinDeSemana
          ? `Tasas sincronizadas para fin de semana. Fecha valor asignada a día Lunes (${fechaRegistro}).`
          : `Tasas sincronizadas correctamente con el BCV para ${fechaRegistro}.`,
        fecha: fechaRegistro,
        fecha_hoy: fechaHoy,
        es_fin_de_semana: esFinDeSemana,
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
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
