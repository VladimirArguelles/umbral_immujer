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

const SPANISH_MONTHS: Record<string, string> = {
  enero: "01",
  febrero: "02",
  marzo: "03",
  abril: "04",
  mayo: "05",
  junio: "06",
  julio: "07",
  agosto: "08",
  septiembre: "09",
  octubre: "10",
  noviembre: "11",
  diciembre: "12",
};

function parseSpanishDateText(text: string): string | null {
  // Ej: "Miércoles, 04 Noviembre 2026" o "04 de Noviembre de 2026" o "4 Noviembre 2026"
  const clean = text.toLowerCase().trim();
  const match = clean.match(/(\d{1,2})\s+(?:de\s+)?([a-záéíóú]+)(?:\s+de)?\s+(\d{4})/i);
  if (!match) return null;

  const day = match[1].padStart(2, "0");
  const monthName = match[2];
  const year = match[3];

  const month = SPANISH_MONTHS[monthName];
  if (!month) return null;

  return `${year}-${month}-${day}`;
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
    let fuenteUtilizada = "";

    // 1. Consulta directa y prioritaria a la página oficial del BCV (bcv.org.ve)
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 7000);

      const bcvRes = await fetch("https://www.bcv.org.ve/", {
        signal: controller.signal,
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
          Accept:
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
          "Accept-Language": "es-VE,es-ES;q=0.9,es;q=0.8,en;q=0.7",
          "Cache-Control": "no-cache",
          Pragma: "no-cache",
        },
      });

      clearTimeout(timeoutId);

      if (bcvRes.ok) {
        const html = await bcvRes.text();

        // Extracción de USD ($)
        const matchUsd = html.match(/id="dolar"[\s\S]*?<strong[^>]*>\s*([\d.,]+)\s*<\/strong>/i);
        if (matchUsd && matchUsd[1]) {
          tasaUsd = parseFloat(matchUsd[1].trim().replace(/\./g, "").replace(",", "."));
        }

        // Extracción de EUR (€)
        const matchEur = html.match(/id="euro"[\s\S]*?<strong[^>]*>\s*([\d.,]+)\s*<\/strong>/i);
        if (matchEur && matchEur[1]) {
          tasaEur = parseFloat(matchEur[1].trim().replace(/\./g, "").replace(",", "."));
        }

        // Extracción de Fecha Valor oficial
        // a) Por atributo content="YYYY-MM-DDT..." en metadato de fecha
        const matchFechaAttr = html.match(/content="(\d{4}-\d{2}-\d{2})T/i);
        if (matchFechaAttr && matchFechaAttr[1]) {
          fechaValorOficial = matchFechaAttr[1];
        }

        // b) Por texto en bloque "Fecha Valor"
        if (!fechaValorOficial) {
          const matchFechaTexto = html.match(/Fecha\s+Valor[\s\S]*?<strong[^>]*>([\s\S]*?)<\/strong>/i);
          if (matchFechaTexto && matchFechaTexto[1]) {
            const parsed = parseSpanishDateText(matchFechaTexto[1]);
            if (parsed) fechaValorOficial = parsed;
          }
        }

        // c) Por clase date-display-single
        if (!fechaValorOficial) {
          const matchDateDisplay = html.match(/class="date-display-single"[^>]*>([\s\S]*?)<\/span>/i);
          if (matchDateDisplay && matchDateDisplay[1]) {
            const parsed = parseSpanishDateText(matchDateDisplay[1]);
            if (parsed) fechaValorOficial = parsed;
          }
        }

        if (tasaUsd > 0) {
          fuenteUtilizada = "BCV Oficial Directo (bcv.org.ve)";
        }
      }
    } catch (e) {
      console.warn("Consulta directa a bcv.org.ve falló o expiró, usando proveedores de contingencia...", e);
    }

    // 2. Fallback primario: CDN sincronizada de alta fidelidad con Fecha Valor en tiempo real
    if (!tasaUsd || tasaUsd <= 0 || !fechaValorOficial) {
      try {
        const resVzla = await fetch("https://rates.dolarvzla.com/bcv/current.json", {
          headers: { Accept: "application/json" },
        });
        if (resVzla.ok) {
          const dataVzla: DolarVzlaResponse = await resVzla.json();
          if (dataVzla.current?.usd && dataVzla.current.usd > 0) {
            if (!tasaUsd || tasaUsd <= 0) {
              tasaUsd = Number(dataVzla.current.usd);
            }
            if ((!tasaEur || tasaEur <= 0) && dataVzla.current.eur) {
              tasaEur = Number(dataVzla.current.eur);
            }
            if (!fechaValorOficial && dataVzla.current.date) {
              fechaValorOficial = dataVzla.current.date.trim();
            }
            if (!fuenteUtilizada) {
              fuenteUtilizada = "rates.dolarvzla.com (BCV Realtime CDN)";
            }
          }
        }
      } catch (e) {
        console.warn("Fallo endpoint de contingencia rates.dolarvzla.com...", e);
      }
    }

    // 3. Fallback secundario: DolarAPI (USD y EUR)
    if (!tasaUsd || tasaUsd <= 0 || !tasaEur || tasaEur <= 0) {
      try {
        const resUsd = await fetch("https://ve.dolarapi.com/v1/dolares/oficial", {
          headers: { Accept: "application/json" },
        });
        if (resUsd.ok) {
          const dataUsd: RateResponse = await resUsd.json();
          if (!tasaUsd || tasaUsd <= 0) {
            tasaUsd = parseFloat(String(dataUsd.promedio));
          }
          if (!fechaValorOficial && dataUsd.fechaActualizacion) {
            fechaValorOficial = dataUsd.fechaActualizacion.split("T")[0];
          }
          if (!fuenteUtilizada) {
            fuenteUtilizada = "DolarAPI Oficial";
          }
        }

        const resEur = await fetch("https://ve.dolarapi.com/v1/euros/oficial", {
          headers: { Accept: "application/json" },
        });
        if (resEur.ok) {
          const dataEur: RateResponse = await resEur.json();
          if (!tasaEur || tasaEur <= 0) {
            tasaEur = parseFloat(String(dataEur.promedio));
          }
          if (!fechaValorOficial && dataEur.fechaActualizacion) {
            fechaValorOficial = dataEur.fechaActualizacion.split("T")[0];
          }
        }
      } catch (e) {
        console.warn("Fallo fallback DolarAPI...", e);
      }
    }

    // Validación de tasas obtenidas
    if (!tasaUsd || tasaUsd <= 0) {
      throw new Error("No se pudo obtener una tasa oficial BCV válida para USD en ninguna de las fuentes.");
    }
    if (!tasaEur || tasaEur <= 0) {
      tasaEur = Number((tasaUsd * 1.08).toFixed(4));
    }

    // 4. Determinación directa de la Fecha Valor oficial
    // Se elimina cualquier condicional que altere o posponga la fecha a días específicos.
    // La fecha valor oficial provista por el BCV es la autoridad absoluta.
    const nowCaracas = new Date(
      new Date().toLocaleString("en-US", { timeZone: "America/Caracas" })
    );
    const hourCaracas = nowCaracas.getHours();
    const horaCaracasStr = nowCaracas.toLocaleTimeString("es-VE", {
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    });

    // Identificación de franja horaria dentro del ciclo de 4 sincronizaciones diarias:
    // Mañana 1 (~08:00 AM), Mañana 2 (~11:00 AM), Tarde 1 (~02:00 PM), Tarde 2 (~05:00 PM - Post 04:00 PM Fecha Valor)
    let franjaSincronizacion = "Sincronización Manual / Extra";
    if (hourCaracas >= 6 && hourCaracas < 10) {
      franjaSincronizacion = "Mañana 1 (Apertura 08:00 AM VET)";
    } else if (hourCaracas >= 10 && hourCaracas < 13) {
      franjaSincronizacion = "Mañana 2 (Media Mañana 11:00 AM VET)";
    } else if (hourCaracas >= 13 && hourCaracas < 16) {
      franjaSincronizacion = "Tarde 1 (Cierre Bancario 02:00 PM VET)";
    } else if (hourCaracas >= 16) {
      franjaSincronizacion = "Tarde 2 (Post 04:00 PM - Publicación Oficial Fecha Valor BCV)";
    }

    const fechaFinal = fechaValorOficial || formatDateIso(nowCaracas);

    // 5. Persistencia (Upsert) en tabla tasa_cambiaria
    const { data: upsertData, error: upsertError } = await supabase
      .from("tasa_cambiaria")
      .upsert(
        {
          fecha: fechaFinal,
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

    // 6. Persistencia (Upsert) inmediata en configuracion_general
    await supabase
      .from("configuracion_general")
      .upsert(
        [
          {
            clave: "tasa_cambio_oficial",
            valor: tasaUsd,
            actualizado_en: new Date().toISOString(),
          },
          {
            clave: "tasa_eur_oficial",
            valor: tasaEur,
            actualizado_en: new Date().toISOString(),
          },
        ],
        { onConflict: "clave" }
      );

    return new Response(
      JSON.stringify({
        success: true,
        message: `Tasa oficial BCV sincronizada [${franjaSincronizacion} - ${horaCaracasStr}] con Fecha Valor oficial (${fechaFinal}): USD Bs. ${tasaUsd}, EUR Bs. ${tasaEur}.`,
        franja: franjaSincronizacion,
        hora_caracas: horaCaracasStr,
        fecha_valor: fechaFinal,
        tasa_bcv: tasaUsd,
        tasa_eur: tasaEur,
        fuente: fuenteUtilizada || "BCV Oficial",
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
