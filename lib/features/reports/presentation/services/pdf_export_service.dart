import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/report_models.dart';

class PdfExportService {
  // Institutional Colors
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF2A3A93);
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFF4F46E5);
  static const PdfColor tableHeaderBg = PdfColor.fromInt(0xFFF0F3FF);
  static const PdfColor alternateRowBg = PdfColor.fromInt(0xFFF9FAFB);
  static const PdfColor textDark = PdfColor.fromInt(0xFF111827);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor borderLight = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor presentGreen = PdfColor.fromInt(0xFF059669);
  static const PdfColor absentRed = PdfColor.fromInt(0xFFDC2626);

  /// Imprime directamente usando el visor nativo de impresión
  static Future<void> imprimir(Uint8List bytes, String nombreArchivo) async {
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: nombreArchivo,
    );
  }

  /// Descarga o comparte el archivo PDF generado en el dispositivo
  static Future<void> descargar(Uint8List bytes, String nombreArchivo) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: nombreArchivo.endsWith('.pdf') ? nombreArchivo : '$nombreArchivo.pdf',
    );
  }

  // ===========================================================================
  // 1. REPORTE DE MATRÍCULA DE ALUMNOS
  // ===========================================================================
  static Future<Uint8List> generarReporteAlumnos({
    required List<ReporteAlumnoInscrito> alumnos,
    required String cursoSeleccionadoNombre,
    String? horario,
    String? profesor,
  }) async {
    final pdf = pw.Document();
    final fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          titulo: 'MATRÍCULA OFICIAL DE ESTUDIANTES',
          subtitulo: 'Sistema Integral de Formación UMBRAL IMMUJER',
          fechaActual: fechaActual,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoBanner(
            curso: cursoSeleccionadoNombre,
            profesor: profesor ?? (alumnos.isNotEmpty ? alumnos.first.profesorNombre : 'Sin asignar'),
            horario: horario ?? (alumnos.isNotEmpty ? alumnos.first.horario : 'Por definir'),
            totalRegistros: alumnos.length,
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: borderLight, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
            headerDecoration: const pw.BoxDecoration(color: tableHeaderBg),
            cellStyle: const pw.TextStyle(fontSize: 8, color: textDark),
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 22,
            headerHeight: 26,
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: alternateRowBg),
            headers: ['#', 'CÉDULA', 'NOMBRE COMPLETO', 'TELÉFONO', 'CORREO ELECTRÓNICO', 'ESTADO'],
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FixedColumnWidth(55),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FixedColumnWidth(70),
              4: const pw.FlexColumnWidth(2.5),
              5: const pw.FixedColumnWidth(48),
            },
            data: List.generate(alumnos.length, (index) {
              final a = alumnos[index];
              return [
                (index + 1).toString(),
                a.cedula,
                a.nombreCompleto.toUpperCase(),
                a.telefono.isNotEmpty ? a.telefono : 'N/A',
                a.correo,
                a.estadoInscripcion.toUpperCase(),
              ];
            }),
          ),
          pw.SizedBox(height: 30),
          _buildSignatureSection(),
        ],
      ),
    );

    return pdf.save();
  }

  // ===========================================================================
  // 2. SÁBANA DE ASISTENCIA Y CONTROL ACADÉMICO
  // ===========================================================================
  static Future<Uint8List> generarReporteAsistencia({
    required List<ReporteAsistenciaDetallada> registros,
    required String cursoSeleccionadoNombre,
    String? horario,
    String? profesor,
    DateTime? fechaSesion,
  }) async {
    final pdf = pw.Document();
    final fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final fechaSesionStr = fechaSesion != null
        ? DateFormat('dd/MM/yyyy').format(fechaSesion)
        : (registros.isNotEmpty ? DateFormat('dd/MM/yyyy').format(registros.first.fecha) : 'Todas las fechas');

    final totalAlumnos = registros.length;
    final totalPresentes = registros.where((r) => r.estado == 'Presente').length;
    final totalAusentes = totalAlumnos - totalPresentes;
    final porcentaje = totalAlumnos > 0 ? (totalPresentes / totalAlumnos * 100).toStringAsFixed(1) : '0.0';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          titulo: 'SÁBANA DE ASISTENCIA Y CONTROL ACADÉMICO',
          subtitulo: 'Registro de Participación y Presencialidad en Clase',
          fechaActual: fechaActual,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoBanner(
            curso: cursoSeleccionadoNombre,
            profesor: profesor ?? 'Docente Asignado',
            horario: horario ?? 'Horario Oficial',
            totalRegistros: totalAlumnos,
            extraEtiqueta: 'Sesión / Fecha',
            extraValor: fechaSesionStr,
          ),
          pw.SizedBox(height: 12),
          // Resumen de Métricas de Asistencia
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: borderLight, width: 0.8),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildKpiPdf('Total Matrícula', '$totalAlumnos', textDark),
                _buildKpiPdf('Presentes', '$totalPresentes', presentGreen),
                _buildKpiPdf('Ausentes', '$totalAusentes', absentRed),
                _buildKpiPdf('Tasa Asistencia', '$porcentaje%', primaryColor),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: borderLight, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
            headerDecoration: const pw.BoxDecoration(color: tableHeaderBg),
            cellStyle: const pw.TextStyle(fontSize: 8, color: textDark),
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 22,
            headerHeight: 26,
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: alternateRowBg),
            headers: ['#', 'CÉDULA', 'NOMBRE Y APELLIDO', 'FECHA', 'ESTADO', 'FIRMA DEL PARTICIPANTE'],
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FixedColumnWidth(55),
              2: const pw.FlexColumnWidth(2.8),
              3: const pw.FixedColumnWidth(55),
              4: const pw.FixedColumnWidth(55),
              5: const pw.FlexColumnWidth(2.0),
            },
            data: List.generate(registros.length, (index) {
              final r = registros[index];
              return [
                (index + 1).toString(),
                r.cedula,
                r.nombreCompleto.toUpperCase(),
                DateFormat('dd/MM/yyyy').format(r.fecha),
                r.estado.toUpperCase(),
                '', // Espacio para firma física
              ];
            }),
          ),
          pw.SizedBox(height: 30),
          _buildSignatureSection(
            cargoIzquierda: 'Firma del Facilitador / Docente',
            cargoDerecha: 'Coordinación Académica IMMUJER',
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ===========================================================================
  // 3. PLAN CURRICULAR / TEMARIO DEL CURSO
  // ===========================================================================
  static Future<Uint8List> generarReporteTemario({
    required List<ReporteTemaCurso> temas,
    required String cursoSeleccionadoNombre,
    String? horario,
    String? profesor,
  }) async {
    final pdf = pw.Document();
    final fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          titulo: 'PLAN DE FORMACIÓN Y CRONOGRAMA CURRICULAR',
          subtitulo: 'Contenido Programático y Estructura Modular',
          fechaActual: fechaActual,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoBanner(
            curso: cursoSeleccionadoNombre,
            profesor: profesor ?? 'Docente Titular',
            horario: horario ?? 'Horario Programado',
            totalRegistros: temas.length,
            extraEtiqueta: 'Sesiones Totales',
            extraValor: '${temas.length} Módulos',
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: borderLight, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
            headerDecoration: const pw.BoxDecoration(color: tableHeaderBg),
            cellStyle: const pw.TextStyle(fontSize: 8.5, color: textDark),
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 24,
            headerHeight: 26,
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: alternateRowBg),
            headers: ['#', 'MÓDULO / SESIÓN', 'CONTENIDO / TEMA A IMPARTIR', 'DESCRIPCIÓN Y OBJETIVO'],
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FixedColumnWidth(75),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(2.5),
            },
            data: List.generate(temas.length, (index) {
              final t = temas[index];
              return [
                t.orden.toString(),
                t.modulo.isNotEmpty ? t.modulo : 'Sesión ${t.orden}',
                t.titulo,
                t.descripcion.isNotEmpty ? t.descripcion : 'Práctica integral y evaluación continua',
              ];
            }),
          ),
          pw.SizedBox(height: 30),
          _buildSignatureSection(),
        ],
      ),
    );

    return pdf.save();
  }

  // ===========================================================================
  // 4. REPORTE DE CARGA DOCENTE
  // ===========================================================================
  static Future<Uint8List> generarReporteProfesores({
    required List<ReporteProfesorCurso> profesores,
  }) async {
    final pdf = pw.Document();
    final fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalMatriculaGlobal = profesores.fold<int>(0, (acc, p) => acc + p.totalAlumnos);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          titulo: 'REPORTE GENERAL DE CARGA DOCENTE Y CURSOS',
          subtitulo: 'Distribución de Facilitadores y Matrícula Estudiantil',
          fechaActual: fechaActual,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: tableHeaderBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderLight, width: 0.8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total de Cursos Activos: ${profesores.length}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.Text('Matrícula Global Consolidada: $totalMatriculaGlobal estudiantes',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: borderLight, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
            headerDecoration: const pw.BoxDecoration(color: tableHeaderBg),
            cellStyle: const pw.TextStyle(fontSize: 8, color: textDark),
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 22,
            headerHeight: 26,
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: alternateRowBg),
            headers: ['#', 'CURSO', 'FACILITADOR / DOCENTE', 'CÉDULA', 'TELÉFONO', 'HORARIO', 'MATRÍCULA'],
            columnWidths: {
              0: const pw.FixedColumnWidth(20),
              1: const pw.FlexColumnWidth(2.0),
              2: const pw.FlexColumnWidth(2.2),
              3: const pw.FixedColumnWidth(55),
              4: const pw.FixedColumnWidth(65),
              5: const pw.FlexColumnWidth(2.0),
              6: const pw.FixedColumnWidth(48),
            },
            data: List.generate(profesores.length, (index) {
              final p = profesores[index];
              return [
                (index + 1).toString(),
                p.cursoNombre,
                p.profesorNombre.toUpperCase(),
                p.cedula ?? 'N/A',
                p.telefono ?? 'N/A',
                p.horario,
                '${p.totalAlumnos} al.',
              ];
            }),
          ),
          pw.SizedBox(height: 30),
          _buildSignatureSection(),
        ],
      ),
    );

    return pdf.save();
  }

  // ===========================================================================
  // HELPERS DE COMPONENTES REUTILIZABLES PDF
  // ===========================================================================

  static pw.Widget _buildHeader({
    required String titulo,
    required String subtitulo,
    required String fechaActual,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'INSTITUTO MUNICIPAL DE LA MUJER (IMMUJER)',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.Text(
                  'ALCALDÍA DEL MUNICIPIO SAN FRANCISCO • ESTADO ZULIA',
                  style: const pw.TextStyle(fontSize: 7.5, color: textMuted),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Plataforma Académica UMBRAL',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: secondaryColor),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Emisión: $fechaActual', style: const pw.TextStyle(fontSize: 7.5, color: textMuted)),
                pw.Text('Reporte Oficial', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 1.5, color: primaryColor),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                titulo,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                subtitulo,
                style: const pw.TextStyle(fontSize: 8.5, color: textMuted),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderLight, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Documento Oficial Generado por el Sistema UMBRAL IMMUJER',
            style: const pw.TextStyle(fontSize: 7, color: textMuted),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: textMuted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoBanner({
    required String curso,
    required String profesor,
    required String horario,
    required int totalRegistros,
    String? extraEtiqueta,
    String? extraValor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: tableHeaderBg,
        border: pw.Border.all(color: borderLight, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoItem('Curso:', curso),
                pw.SizedBox(height: 2),
                _buildInfoItem('Docente:', profesor),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoItem('Horario:', horario),
                pw.SizedBox(height: 2),
                if (extraEtiqueta != null && extraValor != null)
                  _buildInfoItem('$extraEtiqueta:', extraValor)
                else
                  _buildInfoItem('Registros:', '$totalRegistros participantes'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoItem(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
        pw.SizedBox(width: 4),
        pw.Flexible(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 8, color: textDark),
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildKpiPdf(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 7.5, color: textMuted),
        ),
      ],
    );
  }

  static pw.Widget _buildSignatureSection({
    String cargoIzquierda = 'Coordinación Docente',
    String cargoDerecha = 'Dirección General IMMUJER',
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        pw.Column(
          children: [
            pw.Container(width: 140, height: 0.8, color: primaryColor),
            pw.SizedBox(height: 4),
            pw.Text(cargoIzquierda, style: const pw.TextStyle(fontSize: 7.5, color: textMuted)),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 140, height: 0.8, color: primaryColor),
            pw.SizedBox(height: 4),
            pw.Text(cargoDerecha, style: const pw.TextStyle(fontSize: 7.5, color: textMuted)),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 5. REPORTE OFICIAL DE INSCRIPCIONES
  // ===========================================================================
  static Future<Uint8List> generarReporteInscripciones({
    required List<ReporteInscripcion> inscripciones,
    required String cursoSeleccionadoNombre,
  }) async {
    final pdf = pw.Document();
    final fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final activosCount = inscripciones
        .where((i) => i.estadoInscripcion.toLowerCase() == 'activo')
        .length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(
          titulo: 'REPORTE OFICIAL DE INSCRIPCIONES',
          subtitulo: 'Registro Cronológico de Aspirantes y Cupos por Curso',
          fechaActual: fechaActual,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoBanner(
            curso: cursoSeleccionadoNombre,
            profesor: inscripciones.isNotEmpty
                ? inscripciones.first.profesorNombre
                : 'Sin asignar',
            horario: inscripciones.isNotEmpty
                ? inscripciones.first.horario
                : 'Por definir',
            totalRegistros: inscripciones.length,
            extraEtiqueta: 'INSCRIPCIONES ACTIVAS',
            extraValor: '$activosCount / ${inscripciones.length}',
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: borderLight, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
            headerDecoration: const pw.BoxDecoration(color: tableHeaderBg),
            cellStyle: const pw.TextStyle(fontSize: 7.8, color: textDark),
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 22,
            headerHeight: 26,
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: alternateRowBg),
            headers: [
              '#',
              'FECHA',
              'CÉDULA',
              'NOMBRE COMPLETO',
              'CURSO',
              'TELÉFONO',
              'CORREO',
              'ORIGEN',
              'ESTADO',
            ],
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FixedColumnWidth(68),
              2: const pw.FixedColumnWidth(58),
              3: const pw.FlexColumnWidth(2.1),
              4: const pw.FlexColumnWidth(1.8),
              5: const pw.FixedColumnWidth(68),
              6: const pw.FlexColumnWidth(1.8),
              7: const pw.FixedColumnWidth(52),
              8: const pw.FixedColumnWidth(48),
            },
            data: List.generate(inscripciones.length, (index) {
              final item = inscripciones[index];
              final fechaStr = item.fechaInscripcion != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(item.fechaInscripcion!)
                  : 'N/A';
              return [
                (index + 1).toString(),
                fechaStr,
                item.cedula,
                item.nombreCompleto.toUpperCase(),
                item.cursoNombre,
                item.telefono.isNotEmpty ? item.telefono : 'N/A',
                item.correo.isNotEmpty ? item.correo : 'N/A',
                item.origen.toUpperCase(),
                item.estadoInscripcion.toUpperCase(),
              ];
            }),
          ),
          pw.SizedBox(height: 28),
          _buildSignatureSection(),
        ],
      ),
    );

    return pdf.save();
  }
}
