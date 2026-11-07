import 'report_models.dart';

/// Generador de documento HTML limpio, seguro (con sanitización contra XSS) y optimizado para @media print.
/// Permite invocar `window.print()` en navegadores móviles (Chrome Android / Safari iOS)
/// conectando directamente con el spooler e impresoras del sistema sin descargar archivos.
class HtmlReportGenerator {
  /// Escapa caracteres especiales HTML para evitar inyecciones de código o fallos de renderizado.
  static String _escapeHtml(dynamic input) {
    if (input == null) return '';
    return input
        .toString()
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Genera el código HTML completo con estilos de impresión A4, orientación dinámica y auto-print.
  static String generateHtml(ReportDataPayload data, {bool isLandscape = false}) {
    final buffer = StringBuffer();
    final effectiveLandscape = isLandscape || data.isWideTable;
    final pageSize = effectiveLandscape ? 'A4 landscape' : 'A4 portrait';

    final escapedTitle = _escapeHtml(data.reportTitle);
    final escapedInst = _escapeHtml(data.institutionName);
    final escapedRif = _escapeHtml(data.institutionalId);
    final escapedPeriod = _escapeHtml(data.formattedPeriod);
    final escapedEmission = _escapeHtml(data.formattedEmissionDate);

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="es">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="utf-8">');
    buffer.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('  <title>$escapedTitle</title>');
    buffer.writeln('  <style>');
    buffer.writeln('    @page { size: $pageSize; margin: 1cm; }');
    buffer.writeln('    * { box-sizing: border-box; }');
    buffer.writeln('    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; margin: 0; padding: 15px; color: #111827; background: #fff; font-size: 11px; }');
    buffer.writeln('    .header-box { border-bottom: 2px solid #E0115F; padding-bottom: 8px; margin-bottom: 12px; }');
    buffer.writeln('    .inst-name { font-size: 13px; font-weight: bold; color: #1E112A; text-transform: uppercase; }');
    buffer.writeln('    .inst-rif { font-size: 10px; color: #6B7280; }');
    buffer.writeln('    .title { font-size: 14px; font-weight: 800; color: #E0115F; margin: 5px 0 2px 0; text-transform: uppercase; }');
    buffer.writeln('    .meta { font-size: 10px; color: #4B5563; }');
    buffer.writeln('    .kpi-row { display: flex; flex-wrap: wrap; gap: 8px; margin: 10px 0 12px 0; }');
    buffer.writeln('    .kpi-card { background: #FFF5F7; border: 1px solid #FCE7F3; border-radius: 6px; padding: 6px 10px; flex: 1; min-width: 100px; }');
    buffer.writeln('    .kpi-val { font-size: 13px; font-weight: bold; color: #E0115F; }');
    buffer.writeln('    .kpi-lbl { font-size: 9px; color: #6B7280; text-transform: uppercase; }');
    buffer.writeln('    table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 10px; }');
    buffer.writeln('    th { background: #1E112A; color: #ffffff; padding: 6px 6px; text-align: left; font-weight: 600; }');
    buffer.writeln('    td { padding: 5px 6px; border-bottom: 1px solid #E5E7EB; color: #1F2937; }');
    buffer.writeln('    tr:nth-child(even) td { background: #F9FAFB; }');
    buffer.writeln('    .num { text-align: right; }');
    buffer.writeln('    .totals-row td { background: #F3F4F6 !important; font-weight: bold; border-top: 2px solid #1E112A; color: #111827; }');
    buffer.writeln('    .footer { margin-top: 20px; border-top: 1px solid #D1D5DB; padding-top: 6px; font-size: 9px; color: #9CA3AF; text-align: center; }');
    buffer.writeln('    @media print {');
    buffer.writeln('      body { padding: 0; }');
    buffer.writeln('    }');
    buffer.writeln('  </style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    // Encabezado
    buffer.writeln('  <div class="header-box">');
    buffer.writeln('    <div class="inst-name">$escapedInst</div>');
    buffer.writeln('    <div class="inst-rif">RIF: $escapedRif</div>');
    buffer.writeln('    <div class="title">$escapedTitle</div>');
    buffer.writeln('    <div class="meta">Período: $escapedPeriod &nbsp;|&nbsp; Emisión: $escapedEmission</div>');
    buffer.writeln('  </div>');

    // Tarjetas de KPIs
    if (data.kpis.isNotEmpty) {
      buffer.writeln('  <div class="kpi-row">');
      for (final kpi in data.kpis) {
        buffer.writeln('    <div class="kpi-card">');
        buffer.writeln('      <div class="kpi-val">${_escapeHtml(kpi.value)}</div>');
        buffer.writeln('      <div class="kpi-lbl">${_escapeHtml(kpi.label)}</div>');
        buffer.writeln('    </div>');
      }
      buffer.writeln('  </div>');
    }

    // Tabla de Datos
    buffer.writeln('  <table>');
    buffer.writeln('    <thead>');
    buffer.writeln('      <tr>');
    for (int i = 0; i < data.headers.length; i++) {
      final isNum = i == 0 || i >= data.headers.length - 2;
      buffer.writeln('        <th class="${isNum ? 'num' : ''}">${_escapeHtml(data.headers[i])}</th>');
    }
    buffer.writeln('      </tr>');
    buffer.writeln('    </thead>');
    buffer.writeln('    <tbody>');
    for (final row in data.rows) {
      buffer.writeln('      <tr>');
      for (int i = 0; i < row.length; i++) {
        final isNum = i == 0 || (row[i] is num) || (row[i].toString().startsWith(r'$'));
        buffer.writeln('        <td class="${isNum ? 'num' : ''}">${_escapeHtml(row[i])}</td>');
      }
      buffer.writeln('      </tr>');
    }
    if (data.totalsRow != null) {
      buffer.writeln('      <tr class="totals-row">');
      for (int i = 0; i < data.headers.length; i++) {
        final val = data.totalsRow![data.headers[i]] ?? (i == 0 ? 'TOTALES' : '');
        final isNum = i > 0 && val.toString().isNotEmpty;
        buffer.writeln('        <td class="${isNum ? 'num' : ''}">${_escapeHtml(val)}</td>');
      }
      buffer.writeln('      </tr>');
    }
    buffer.writeln('    </tbody>');
    buffer.writeln('  </table>');

    // Pie de página
    buffer.writeln('  <div class="footer">');
    buffer.writeln('    Generado por Sistema UMBRAL - IMMUJER &nbsp;|&nbsp; Documento Administrativo Oficial');
    buffer.writeln('  </div>');

    // Disparador de impresión directa al cargar la página con delay de seguridad de 500ms
    buffer.writeln('  <script>');
    buffer.writeln('    window.addEventListener("load", function() {');
    buffer.writeln('      setTimeout(function() {');
    buffer.writeln('        if (typeof window.print === "function") {');
    buffer.writeln('          window.print();');
    buffer.writeln('        }');
    buffer.writeln('      }, 500);');
    buffer.writeln('    });');
    buffer.writeln('  </script>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }
}
