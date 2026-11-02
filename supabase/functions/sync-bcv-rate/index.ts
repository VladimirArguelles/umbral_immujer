import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

interface DolarVzlaResponse {
  current?: {
    date?: string;
    usd?: number;
    eur?: number;
  };
}

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

    let tasaUsd = 0;
    let tasaEur = 0;
    let fechaValorOficial = "";

    // 1. Endpoint primario CDN de alta fidelidad con Fecha Valor en tiempo real
    try {
      const resVzla = await fetch("https://rates.dolarvzla.com/bcv/current.json", {
        headers: { Accept: "application/json" },
      });
      if (resVzla.ok) {
        const dataVzla: DolarVzlaResponse = await resVzla.json();
        if (dataVzla.current?.usd && dataVzla.current.usd > 0) {
          tasaUsd = Number(dataVzla.current.usd);
          tasaEur = Number(dataVzla.current.eur || (tasaUsd * 1.08).toFixed(4));
          if (dataVzla.current.date) {
            fechaValorOficial = dataVzla.current.date.trim();
          }
        }
      }
    } catch (e) {
      console.warn("Fallo endpoint primario rates.dolarvzla.com, intentando scraping bcv...", e);
    }

    // 2. Consulta directa a la página oficial del BCV (bcv.org.ve)
    if (!tasaUsd || tasaUsd <= 0) {
      try {
        const bcvRes = await fetch("https://www.bcv.org.ve/", {
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          },
        });

        if (bcvRes.ok) {
          const html = await bcvRes.text();

          const matchUsd = html.match(/id="dolar"[\s\S]*?<strong[^>]*>\s*([\d.,]+)\s*<\/strong>/i);
          if (matchUsd && matchUsd[1]) {
            tasaUsd = parseFloat(matchUsd[1].trim().replace(/\./g, "").replace(",", "."));
          }

          const matchEur = html.match(/id="euro"[\s\S]*?<strong[^>]*>\s*([\d.,]+)\s*<\/strong>/i);
          if (matchEur && matchEur[1]) {
            tasaEur = parseFloat(matchEur[1].trim().replace(/\./g, "").replace(",", "."));
          }

          const matchFecha = html.match(/content="(\d{4}-\d{2}-\d{2})T/i);
          if (matchFecha && matchFecha[1]) {
            fechaValorOficial = matchFecha[1];
          }
        }
      } catch (e) {
        console.warn("Fallo scraping directo bcv.org.ve, usando fallback DolarAPI...", e);
      }
    }

    // 3. Fallback secundario: DolarAPI
    if (!tasaUsd || tasaUsd <= 0) {
      try {
        const resUsd = await fetch("https://ve.dolarapi.com/v1/dolares/oficial", {
          headers: { Accept: "application/json" },
        });
        if (resUsd.ok) {
          const dataUsd: RateResponse = await resUsd.json();
          tasaUsd = parseFloat(String(dataUsd.promedio));
          if (!fechaValorOficial && dataUsd.fechaActualizacion) {
            fechaValorOficial = dataUsd.fechaActualizacion.split("T")[0];
          }
        }
      } catch (e) {
        console.warn("Fallo fallback DolarAPI USD...", e);
      }
    }

    if (!tasaUsd || tasaUsd <= 0) {
      throw new Error("No se pudo obtener una tasa oficial BCV válida para USD.");
    }
    if (!tasaEur || tasaEur <= 0) {
      tasaEur = Number((tasaUsd * 1.08).toFixed(4));
    }

    // 4. Cálculo de Fecha Valor en la Zona Horaria de Venezuela (America/Caracas, UTC-4)
    const nowCaracas = new Date(
      new Date().toLocaleString("en-US", { timeZone: "America/Caracas" })
    );
    const dayOfWeek = nowCaracas.getDay(); // 0 = Domingo, 1 = Lunes, ..., 5 = Viernes, 6 = Sábado
    const fechaHoy = formatDateIso(nowCaracas);

    let fechaRegistro = fechaValorOficial;
    let esFinDeSemana = false;

    // Si es viernes (5), sábado (6) o domingo (0), la fecha valor bancaria oficial es el día Lunes
    if (dayOfWeek === 5) {
      const lunes = new Date(nowCaracas);
      lunes.setDate(nowCaracas.getDate() + 3);
      fechaRegistro = formatDateIso(lunes);
      esFinDeSemana = true;
    } else if (dayOfWeek === 6) {
      const lunes = new Date(nowCaracas);
      lunes.setDate(nowCaracas.getDate() + 2);
      fechaRegistro = formatDateIso(lunes);
      esFinDeSemana = true;
    } else if (dayOfWeek === 0) {
      const lunes = new Date(nowCaracas);
      lunes.setDate(nowCaracas.getDate() + 1);
      fechaRegistro = formatDateIso(lunes);
      esFinDeSemana = true;
    } else {
      if (!fechaRegistro || fechaRegistro < fechaHoy) {
        fechaRegistro = fechaHoy;
      }
    }

    // 5. Insertar o actualizar en tabla tasa_cambiaria
    const rowsToUpsert = [
      {
        fecha: fechaRegistro,
        tasa_bcv: tasaUsd,
        tasa_eur: tasaEur,
        creado_en: new Date().toISOString(),
      },
    ];

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

    // 6. Actualización directa de la tasa oficial en configuracion_general
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
          ? `Tasa oficial BCV actualizada con Fecha Valor día Lunes (${fechaRegistro}): Bs. ${tasaUsd}.`
          : `Tasa oficial BCV actualizada para ${fechaRegistro}: Bs. ${tasaUsd}.`,
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
