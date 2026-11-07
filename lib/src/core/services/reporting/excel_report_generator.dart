import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:printing/printing.dart';
import 'report_models.dart';

/// Generador y exportador de hojas de cálculo Excel (.xlsx) para informes UMBRAL.
class ExcelReportGenerator {
  /// Genera los bytes del archivo .xlsx con estructura institucional.
  static Uint8List generateExcel(ReportDataPayload data) {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
    const sheetName = 'Informe Administrativo';
    excel.rename(defaultSheetName, sheetName);
    final sheet = excel[sheetName];

    int currentRow = 0;

    // 1. Encabezado institucional
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value =
        TextCellValue(data.institutionName);
    currentRow++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value =
        TextCellValue('RIF: ${data.institutionalId}');
    currentRow++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value =
        TextCellValue(data.reportTitle.toUpperCase());
    currentRow++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value =
        TextCellValue(data.formattedPeriod);
    currentRow++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value =
        TextCellValue('Emisión: ${data.formattedEmissionDate}');
    currentRow++;

    if (data.generatedBy != null) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value =
          TextCellValue('Emitido por: ${data.generatedBy}');
      currentRow++;
    }

    // 2. Bloque de KPIs
    if (data.kpis.isNotEmpty) {
      currentRow++;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value =
          TextCellValue('INDICADORES CLAVE (KPIS)');
      currentRow++;

      for (int i = 0; i < data.kpis.length; i++) {
        final kpi = data.kpis[i];
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i * 2, rowIndex: currentRow)).value =
            TextCellValue(kpi.label);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: (i * 2) + 1, rowIndex: currentRow)).value =
            TextCellValue(kpi.value);
      }
      currentRow++;
    }

    // Espacio antes de la tabla principal
    currentRow++;

    // 3. Fila de Encabezados de Tabla
    for (int col = 0; col < data.headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow)).value =
          TextCellValue(data.headers[col].toUpperCase());
    }
    currentRow++;

    // 4. Filas de Datos
    for (final row in data.rows) {
      for (int col = 0; col < data.headers.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        final val = col < row.length ? row[col] : null;

        if (val == null) {
          cell.value = TextCellValue('');
        } else if (val is int) {
          cell.value = IntCellValue(val);
        } else if (val is double) {
          cell.value = DoubleCellValue(val);
        } else if (val is bool) {
          cell.value = BoolCellValue(val);
        } else {
          final str = val.toString().trim();
          final parsedInt = int.tryParse(str);
          final parsedDouble = double.tryParse(str.replaceAll(',', '.'));

          if (parsedInt != null) {
            cell.value = IntCellValue(parsedInt);
          } else if (parsedDouble != null) {
            cell.value = DoubleCellValue(parsedDouble);
          } else {
            cell.value = TextCellValue(str);
          }
        }
      }
      currentRow++;
    }

    // 5. Fila Final de Totales (si aplica)
    if (data.totalsRow != null) {
      for (int col = 0; col < data.headers.length; col++) {
        final key = data.headers[col];
        final val = data.totalsRow![key] ?? (col == 0 ? 'TOTALES' : '');
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));

        if (val is int) {
          cell.value = IntCellValue(val);
        } else if (val is double) {
          cell.value = DoubleCellValue(val);
        } else {
          cell.value = TextCellValue(val.toString());
        }
      }
      currentRow++;
    }

    final rawBytes = excel.save();
    return Uint8List.fromList(rawBytes ?? []);
  }

  /// Exporta y descarga o comparte el archivo Excel en la plataforma activa.
  static Future<bool> exportAndShare(
    ReportDataPayload data, {
    String? customFilename,
  }) async {
    final bytes = generateExcel(data);
    final rawName = customFilename ??
        'Reporte_${data.reportTitle.replaceAll(RegExp(r'\s+'), '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final cleanName = rawName.endsWith('.xlsx') ? rawName : '$rawName.xlsx';

    return Printing.sharePdf(
      bytes: bytes,
      filename: cleanName,
    );
  }
}
