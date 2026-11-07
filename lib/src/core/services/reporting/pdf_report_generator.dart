import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'report_models.dart';

/// Generador vectorizado de informes PDF institucionales UMBRAL.
class PdfReportGenerator {
  static const _cPrimary = PdfColor.fromInt(0xFF5B21B6);
  static const _cSecondary = PdfColor.fromInt(0xFF0F172A);
  static const _cHeaderBg = PdfColor.fromInt(0xFFF1F5F9);
  static const _cRowAlt = PdfColor.fromInt(0xFFF8FAFC);
  static const _cBorder = PdfColor.fromInt(0xFFE2E8F0);
  static const _cMuted = PdfColor.fromInt(0xFF64748B);

  static Future<Uint8List> generatePdf({
    required ReportDataPayload data,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        header: (context) => _buildHeader(data),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          if (data.kpis.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _buildKpis(data.kpis),
          ],
          pw.SizedBox(height: 10),
          _buildTable(data),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildHeader(ReportDataPayload data) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _cPrimary, width: 2)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                data.institutionName,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _cPrimary),
              ),
              pw.Text('RIF: ${data.institutionalId}', style: const pw.TextStyle(fontSize: 7.5, color: _cMuted)),
              pw.SizedBox(height: 3),
              pw.Text(
                data.reportTitle.toUpperCase(),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _cSecondary),
              ),
              pw.Text(data.formattedPeriod, style: const pw.TextStyle(fontSize: 7.5, color: _cMuted)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(color: _cPrimary, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text('UMBRAL', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
              ),
              pw.SizedBox(height: 3),
              pw.Text('Emisión: ${data.formattedEmissionDate}', style: const pw.TextStyle(fontSize: 7, color: _cMuted)),
              if (data.generatedBy != null)
                pw.Text('Por: ${data.generatedBy}', style: const pw.TextStyle(fontSize: 7, color: _cMuted)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKpis(List<ReportKpi> kpis) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 6,
      children: kpis.map((kpi) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            color: _cRowAlt,
            borderRadius: pw.BorderRadius.circular(5),
            border: pw.Border.all(color: _cBorder, width: 0.8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(kpi.label.toUpperCase(), style: const pw.TextStyle(fontSize: 6, color: _cMuted)),
              pw.SizedBox(height: 1),
              pw.Text(kpi.value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _cPrimary)),
              if (kpi.subtitle != null) ...[
                pw.SizedBox(height: 1),
                pw.Text(kpi.subtitle!, style: const pw.TextStyle(fontSize: 5, color: _cMuted)),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildTable(ReportDataPayload data) {
    final aligns = List.generate(data.headers.length, (i) {
      return data.isNumericColumn(i) ? pw.Alignment.centerRight : pw.Alignment.centerLeft;
    });

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _cHeaderBg),
        children: List.generate(data.headers.length, (i) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            alignment: aligns[i],
            child: pw.Text(
              data.headers[i].toUpperCase(),
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _cSecondary),
            ),
          );
        }),
      ),
      ...List.generate(data.rows.length, (rowIndex) {
        final row = data.rows[rowIndex];
        final isAlt = rowIndex % 2 == 1;
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: isAlt ? _cRowAlt : PdfColors.white),
          children: List.generate(data.headers.length, (colIndex) {
            final val = colIndex < row.length ? row[colIndex]?.toString() ?? '' : '';
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
              alignment: aligns[colIndex],
              child: pw.Text(val, style: const pw.TextStyle(fontSize: 6.8, color: _cSecondary)),
            );
          }),
        );
      }),
    ];

    if (data.totalsRow != null) {
      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: _cHeaderBg,
            border: pw.Border(top: pw.BorderSide(color: _cPrimary, width: 1.2)),
          ),
          children: List.generate(data.headers.length, (colIndex) {
            final key = data.headers[colIndex];
            final val = data.totalsRow![key]?.toString() ?? (colIndex == 0 ? 'TOTALES' : '');
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              alignment: aligns[colIndex],
              child: pw.Text(val, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _cPrimary)),
            );
          }),
        ),
      );
    }

    return pw.Table(border: pw.TableBorder.all(color: _cBorder, width: 0.5), children: tableRows);
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _cBorder, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generado por Sistema UMBRAL - IMMUJER | Documento Administrativo', style: const pw.TextStyle(fontSize: 6.2, color: _cMuted)),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 6.2, color: _cMuted)),
        ],
      ),
    );
  }
}
