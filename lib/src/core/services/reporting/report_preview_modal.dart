import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'excel_report_generator.dart';
import 'pdf_report_generator.dart';
import 'report_models.dart';

/// Modal Glassmorphism de Previsualización, Impresión y Exportación de Informes UMBRAL.
class ReportPreviewModal extends StatefulWidget {
  final ReportDataPayload data;

  const ReportPreviewModal({super.key, required this.data});

  /// Despliega el modal a pantalla completa con desenfoque Glassmorphism.
  static Future<void> show(BuildContext context, {required ReportDataPayload data}) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar informe',
      barrierColor: const Color(0xB30D0714),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, a1, a2) => ReportPreviewModal(data: data),
      transitionBuilder: (ctx, a1, a2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10 * a1.value, sigmaY: 10 * a1.value),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
    );
  }

  @override
  State<ReportPreviewModal> createState() => _ReportPreviewModalState();
}

class _ReportPreviewModalState extends State<ReportPreviewModal> {
  late bool _isLandscape;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _isLandscape = widget.data.isWideTable;
  }

  PdfPageFormat get _format => _isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: _buildFloatingToolbar(),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(160), blurRadius: 30, offset: const Offset(0, 10)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: PdfPreview(
                  build: (fmt) => PdfReportGenerator.generatePdf(data: widget.data, format: _format),
                  useActions: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  scrollViewDecoration: const BoxDecoration(color: Color(0xFF1E112A)),
                  pdfPreviewPageDecoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8))],
                  ),
                  loadingWidget: const Center(child: CircularProgressIndicator(color: Color(0xFFE0115F))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xE61A1028),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE0115F).withAlpha(100), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFFE0115F).withAlpha(50), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.description, color: Color(0xFFE0115F), size: 19),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.data.reportTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          _pillButton(
            icon: _isLandscape ? Symbols.stay_current_landscape : Symbols.stay_current_portrait,
            label: _isLandscape ? 'Horizontal' : 'Vertical',
            onTap: () => setState(() => _isLandscape = !_isLandscape),
            highlighted: true,
          ),
          const SizedBox(width: 6),
          _pillButton(icon: Symbols.print, label: 'Imprimir', onTap: _isProcessing ? null : _handlePrint),
          const SizedBox(width: 6),
          _pillButton(
            icon: Symbols.download,
            label: 'PDF',
            accentColor: const Color(0xFFE0115F),
            onTap: _isProcessing ? null : _handleSharePdf,
          ),
          const SizedBox(width: 6),
          _pillButton(
            icon: Symbols.table_chart,
            label: 'Excel',
            accentColor: const Color(0xFF10B981),
            onTap: _isProcessing ? null : _handleExportExcel,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Symbols.close, color: Colors.white70, size: 19),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(5),
              backgroundColor: Colors.white10,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool highlighted = false,
    Color? accentColor,
  }) {
    final color = accentColor ?? (highlighted ? const Color(0xFFE0115F) : Colors.white70);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(highlighted ? 25 : 12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(highlighted ? 120 : 40), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePrint() async {
    setState(() => _isProcessing = true);
    try {
      await Printing.layoutPdf(
        name: widget.data.reportTitle,
        format: _format,
        onLayout: (fmt) => PdfReportGenerator.generatePdf(data: widget.data, format: _format),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar con el servicio de impresión: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSharePdf() async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await PdfReportGenerator.generatePdf(data: widget.data, format: _format);
      final filename = 'Reporte_${widget.data.reportTitle.replaceAll(RegExp(r'\s+'), '_')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleExportExcel() async {
    setState(() => _isProcessing = true);
    try {
      await ExcelReportGenerator.exportAndShare(widget.data);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
