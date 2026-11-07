import 'package:flutter/material.dart';

/// KPI o métrica destacada para el encabezado del informe administrativo.
class ReportKpi {
  final String label;
  final String value;
  final String? subtitle;

  const ReportKpi({
    required this.label,
    required this.value,
    this.subtitle,
  });

  factory ReportKpi.fromMap(Map<String, dynamic> map) {
    return ReportKpi(
      label: map['label']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      subtitle: map['subtitle']?.toString(),
    );
  }
}

/// Carga genérica de datos para la generación, vista previa y exportación de informes.
class ReportDataPayload {
  final String reportTitle;
  final String institutionName;
  final String institutionalId;
  final DateTimeRange? dateRange;
  final List<ReportKpi> kpis;
  final List<String> headers;
  final List<List<dynamic>> rows;
  final Map<String, dynamic>? totalsRow;
  final String? generatedBy;

  const ReportDataPayload({
    required this.reportTitle,
    this.institutionName = 'IMMUJER - Sistema UMBRAL',
    this.institutionalId = 'G-20000000-0',
    this.dateRange,
    this.kpis = const [],
    required this.headers,
    required this.rows,
    this.totalsRow,
    this.generatedBy,
  });

  /// Determina si la tabla es ancha (más de 6 columnas) para sugerir orientación horizontal.
  bool get isWideTable => headers.length > 6;

  /// Retorna el rango de fechas en formato legible de texto.
  String get formattedPeriod {
    if (dateRange == null) return 'Período no especificado (Histórico General)';
    final start = _formatDate(dateRange!.start);
    final end = _formatDate(dateRange!.end);
    return 'Desde: $start  -  Hasta: $end';
  }

  /// Retorna la fecha y hora de emisión formateada.
  String get formattedEmissionDate {
    final now = DateTime.now();
    return '${_formatDate(now)} ${_formatTime(now)}';
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  /// Verifica si una columna contiene predominantemente valores numéricos para alinearla a la derecha.
  bool isNumericColumn(int columnIndex) {
    if (rows.isEmpty || columnIndex >= headers.length) return false;
    int numericCount = 0;
    int checkCount = 0;
    for (final row in rows) {
      if (columnIndex < row.length && row[columnIndex] != null) {
        checkCount++;
        final val = row[columnIndex];
        if (val is num) {
          numericCount++;
        } else {
          final str = val.toString().trim().replaceAll('\$', '').replaceAll('Bs', '').replaceAll(',', '.').trim();
          if (double.tryParse(str) != null) {
            numericCount++;
          }
        }
      }
    }
    return checkCount > 0 && (numericCount / checkCount) >= 0.7;
  }
}
