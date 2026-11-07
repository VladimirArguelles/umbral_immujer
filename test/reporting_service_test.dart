import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:umbral_immujer/src/core/services/reporting/excel_report_generator.dart';
import 'package:umbral_immujer/src/core/services/reporting/html_report_generator.dart';
import 'package:umbral_immujer/src/core/services/reporting/pdf_report_generator.dart';
import 'package:umbral_immujer/src/core/services/reporting/report_models.dart';

void main() {
  group('Módulo Genérico de Informes UMBRAL', () {
    final payload = ReportDataPayload(
      reportTitle: 'Control de Asistencia Consolidada',
      institutionName: 'IMMUJER - Sistema UMBRAL',
      institutionalId: 'G-20012345-6',
      dateRange: DateTimeRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31),
      ),
      kpis: const [
        ReportKpi(label: 'Total Matriculados', value: '450'),
        ReportKpi(label: 'Asistencia Promedio', value: '92.4%'),
        ReportKpi(label: 'Total Recaudado', value: '\$ 1.250,00'),
      ],
      headers: const ['N°', 'Cédula', 'Nombre Completo', 'Curso', 'Asistencias', 'Aporte Bs'],
      rows: const [
        [1, 'V-12345678', 'Ana Pérez', 'Costura Básica', 8, 450.00],
        [2, 'V-23456789', 'Beatriz Silva', 'Panadería Artesanal', 7, 450.00],
        [3, 'V-34567890', 'Carmen Torres', 'Repostería Navideña', 8, 500.00],
      ],
      totalsRow: const {
        'N°': '3 Alumnos',
        'Asistencias': '23 Clases',
        'Aporte Bs': '1.400,00 Bs',
      },
      generatedBy: 'Coordinación Académica',
    );

    test('ReportDataPayload detecta columnas y orientación recomendada', () {
      expect(payload.isWideTable, isFalse);
      expect(payload.isNumericColumn(0), isTrue); // N°
      expect(payload.isNumericColumn(2), isFalse); // Nombre Completo
      expect(payload.isNumericColumn(4), isTrue); // Asistencias

      final widePayload = ReportDataPayload(
        reportTitle: 'Sábana Ancha',
        headers: const ['C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7'],
        rows: const [],
      );
      expect(widePayload.isWideTable, isTrue);
    });

    test('PdfReportGenerator produce bytes de documento PDF válidos', () async {
      final pdfBytes = await PdfReportGenerator.generatePdf(
        data: payload,
        format: PdfPageFormat.a4,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(1000));
      // Encabezado estándar de archivo PDF (%PDF-)
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));
    });

    test('ExcelReportGenerator produce bytes de hoja de cálculo XLSX válidos', () {
      final excelBytes = ExcelReportGenerator.generateExcel(payload);

      expect(excelBytes, isA<Uint8List>());
      expect(excelBytes.length, greaterThan(500));
      // Los archivos .xlsx son ZIP binarios con encabezado 'PK' (0x50, 0x4B)
      expect(excelBytes[0], equals(0x50));
      expect(excelBytes[1], equals(0x4B));
    });

    test('HtmlReportGenerator genera documento HTML imprimible con auto-print y sanitización XSS', () {
      final html = HtmlReportGenerator.generateHtml(payload);

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('Control de Asistencia Consolidada'));
      expect(html, contains('IMMUJER - Sistema UMBRAL'));
      expect(html, contains('window.print()'));
      expect(html, contains('500'));
      expect(html, contains('Costura Básica'));
      expect(html, contains('3 Alumnos'));
      expect(html, contains('1.400,00 Bs'));
    });

    test('HtmlReportGenerator escapa caracteres especiales HTML para evitar XSS', () {
      final xssPayload = ReportDataPayload(
        reportTitle: '<script>alert("hack")</script>',
        institutionName: 'IMMUJER & "Alcaldía"',
        institutionalId: "G-123'45",
        headers: ['<Col 1>', 'Col 2 & test'],
        rows: [
          ['<img src=x onerror=alert(1)>', 'Normal "Value"'],
        ],
      );

      final html = HtmlReportGenerator.generateHtml(xssPayload);

      expect(html, isNot(contains('<script>alert')));
      expect(html, contains('&lt;script&gt;alert(&quot;hack&quot;)&lt;/script&gt;'));
      expect(html, contains('IMMUJER &amp; &quot;Alcaldía&quot;'));
      expect(html, contains('G-123&#39;45'));
      expect(html, contains('&lt;img src=x onerror=alert(1)&gt;'));
    });

    test('HtmlReportGenerator adapta @page orientation a landscape o portrait dinámicamente', () {
      final verticalHtml = HtmlReportGenerator.generateHtml(payload, isLandscape: false);
      expect(verticalHtml, contains('@page { size: A4 portrait; margin: 1cm; }'));

      final horizontalHtml = HtmlReportGenerator.generateHtml(payload, isLandscape: true);
      expect(horizontalHtml, contains('@page { size: A4 landscape; margin: 1cm; }'));
    });
  });
}
