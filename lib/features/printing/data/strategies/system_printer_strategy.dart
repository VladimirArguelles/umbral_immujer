import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/printer_models.dart';

class SystemPrinterStrategy implements PrinterStrategy {
  @override
  Future<bool> printTicket(TicketData ticket, ConfiguracionImpresora config) async {
    try {
      Uint8List bytes;
      if (ticket.pdfBytes != null && ticket.pdfBytes!.isNotEmpty) {
        bytes = ticket.pdfBytes!;
      } else {
        bytes = await _generateBasicTicketPdf(ticket);
      }

      final printers = await Printing.listPrinters();
      Printer? selectedPrinter;
      for (final p in printers) {
        if (p.url == config.identificador || p.name == config.nombreImpresora) {
          selectedPrinter = p;
          break;
        }
      }

      if (selectedPrinter != null) {
        final result = await Printing.directPrintPdf(
          printer: selectedPrinter,
          onLayout: (PdfPageFormat format) async => bytes,
          name: ticket.titulo,
        );
        return result;
      } else {
        // Si no se encuentra la impresora por identificador, abrir diálogo de impresión del sistema
        return await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: ticket.titulo,
        );
      }
    } catch (_) {
      // Fallback a layout general del sistema
      if (ticket.pdfBytes != null) {
        return await Printing.layoutPdf(
          onLayout: (_) async => ticket.pdfBytes!,
          name: ticket.titulo,
        );
      }
      return false;
    }
  }

  @override
  Future<bool> testConnection(ConfiguracionImpresora config) async {
    try {
      final printers = await Printing.listPrinters();
      return printers.any(
        (p) => p.url == config.identificador || p.name == config.nombreImpresora,
      );
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> _generateBasicTicketPdf(TicketData ticket) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  ticket.titulo,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
              ),
              if (ticket.subtitulo != null)
                pw.Center(
                  child: pw.Text(
                    ticket.subtitulo!,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              pw.Divider(),
              ...ticket.items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(item.columna1, style: const pw.TextStyle(fontSize: 9)),
                      ),
                      if (item.columna2 != null)
                        pw.Text(item.columna2!, style: const pw.TextStyle(fontSize: 9)),
                      if (item.columna3 != null)
                        pw.Text('  ${item.columna3!}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
              if (ticket.totales.isNotEmpty) ...[
                pw.Divider(),
                ...ticket.totales.entries.map(
                  (e) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(e.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(e.value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
              ],
              if (ticket.pieDePagina != null) ...[
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(ticket.pieDePagina!, style: const pw.TextStyle(fontSize: 8)),
                ),
              ],
            ],
          );
        },
      ),
    );
    return pdf.save();
  }
}
