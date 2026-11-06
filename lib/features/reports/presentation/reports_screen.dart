import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/assistant/presentation/widgets/mia_assistant_widget.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

import '../data/reports_repository.dart';
import '../domain/report_models.dart';
import 'services/pdf_export_service.dart';

class ReportsScreen extends StatefulWidget {
  final String? initialCursoId;
  final TipoReporte? initialTipoReporte;

  const ReportsScreen({
    super.key,
    this.initialCursoId,
    this.initialTipoReporte,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsRepository _repo = ReportsRepository();

  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  String? _errorMessage;

  List<Map<String, String>> _cursos = [];
  String _selectedCursoId = 'todos';
  TipoReporte _tipoReporte = TipoReporte.alumnos;

  // Data lists
  List<ReporteAlumnoInscrito> _alumnos = [];
  List<ReporteProfesorCurso> _profesores = [];
  List<ReporteTemaCurso> _temas = [];
  List<ReporteAsistenciaDetallada> _asistencias = [];
  List<ReporteAsistenciaResumen> _asistenciasResumen = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialCursoId != null) {
      _selectedCursoId = widget.initialCursoId!;
    }
    if (widget.initialTipoReporte != null) {
      _tipoReporte = widget.initialTipoReporte!;
    }
    _initData();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cursos = await _repo.getCursosParaFiltro();
      if (!mounted) return;
      setState(() {
        _cursos = cursos;
      });
      await _loadReportData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar cursos: $e';
      });
    }
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cursoId = _selectedCursoId == 'todos' ? null : _selectedCursoId;

      switch (_tipoReporte) {
        case TipoReporte.alumnos:
          _alumnos = await _repo.getAlumnosPorCurso(cursoId: cursoId);
          break;
        case TipoReporte.asistencia:
          _asistencias = await _repo.getAsistenciaDetallada(cursoId: cursoId);
          _asistenciasResumen = await _repo.getAsistenciaResumen(
            cursoId: cursoId,
          );
          break;
        case TipoReporte.temario:
          _temas = await _repo.getTemasPorCurso(cursoId: cursoId);
          break;
        case TipoReporte.profesores:
          _profesores = await _repo.getProfesoresCursos(cursoId: cursoId);
          break;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al consultar la vista de reporte: $e';
        });
      }
    }
  }

  String get _currentCursoNombre {
    if (_selectedCursoId == 'todos') return 'Todos los Cursos';
    final found = _cursos.firstWhere(
      (c) => c['id'] == _selectedCursoId,
      orElse: () => {'nombre': 'Curso Seleccionado'},
    );
    return found['nombre'] ?? 'Curso';
  }

  // ===========================================================================
  // ACCIONES: GENERACIÓN DE PDF, IMPRESIÓN Y DESCARGA
  // ===========================================================================
  Future<Uint8List?> _generatePdfBytes() async {
    final cursoNombre = _currentCursoNombre;

    switch (_tipoReporte) {
      case TipoReporte.alumnos:
        if (_alumnos.isEmpty) {
          _showSnack('No hay alumnos inscritos para exportar.');
          return null;
        }
        return await PdfExportService.generarReporteAlumnos(
          alumnos: _filteredAlumnos,
          cursoSeleccionadoNombre: cursoNombre,
        );

      case TipoReporte.asistencia:
        if (_asistencias.isEmpty) {
          _showSnack('No hay registros de asistencia para exportar.');
          return null;
        }
        return await PdfExportService.generarReporteAsistencia(
          registros: _filteredAsistencias,
          cursoSeleccionadoNombre: cursoNombre,
        );

      case TipoReporte.temario:
        if (_temas.isEmpty) {
          _showSnack('No hay temas curriculares para exportar.');
          return null;
        }
        return await PdfExportService.generarReporteTemario(
          temas: _filteredTemas,
          cursoSeleccionadoNombre: cursoNombre,
        );

      case TipoReporte.profesores:
        if (_profesores.isEmpty) {
          _showSnack('No hay asignaciones docentes para exportar.');
          return null;
        }
        return await PdfExportService.generarReporteProfesores(
          profesores: _filteredProfesores,
        );
    }
  }

  Future<void> _handleGuardar() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _generatePdfBytes();
      if (bytes != null) {
        final nombreArchivo =
            'reporte_${_tipoReporte.name}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
        await PdfExportService.descargar(bytes, nombreArchivo);
        _showSnack('Reporte guardado correctamente.');
      }
    } catch (e) {
      _showSnack('Error al guardar el documento: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ===========================================================================
  // LISTADOS DE DATOS
  // ===========================================================================
  List<ReporteAlumnoInscrito> get _filteredAlumnos => _alumnos;
  List<ReporteProfesorCurso> get _filteredProfesores => _profesores;
  List<ReporteTemaCurso> get _filteredTemas => _temas;
  List<ReporteAsistenciaDetallada> get _filteredAsistencias => _asistencias;

  // ===========================================================================
  // CONSTRUCCIÓN DE LA INTERFAZ
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dynamicBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.dynamicCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: AppTheme.dynamicText),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/coordinator');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Centro de Reportes y Documentos Oficiales',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.dynamicText,
              ),
            ),
            Text(
              'Emisión directa de matrículas, asistencias y planeaciones académicas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppTheme.dynamicTextMuted,
              ),
            ),
          ],
        ),
        actions: [
          const MiaAssistantHeaderButton(
            moduleContext: 'reportes',
          ),
          IconButton(
            tooltip: 'Ajustes de Impresora',
            icon: Icon(Symbols.print_connect, color: AppTheme.dynamicText),
            onPressed: () => context.push('/printer-settings'),
          ),
          IconButton(
            tooltip: 'Actualizar Datos',
            icon: Icon(Symbols.refresh, color: AppTheme.primary),
            onPressed: _isLoading ? null : _loadReportData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterAndControlPanel(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorView()
                : _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        border: Border(
          bottom: BorderSide(color: AppTheme.dynamicBorder, width: 0.8),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 650;
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTipoReporteDropdown(),
                const SizedBox(height: 8),
                _buildCursoDropdown(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildVerRegistrosButton()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildGuardarButton()),
                  ],
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(flex: 3, child: _buildTipoReporteDropdown()),
                const SizedBox(width: 10),
                Expanded(flex: 4, child: _buildCursoDropdown()),
                const SizedBox(width: 10),
                _buildVerRegistrosButton(),
                const SizedBox(width: 8),
                _buildGuardarButton(),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildTipoReporteDropdown() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.dynamicSurfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TipoReporte>(
          value: _tipoReporte,
          isExpanded: true,
          icon: const Icon(Symbols.keyboard_arrow_down, size: 20),
          dropdownColor: AppTheme.dynamicCard,
          items: TipoReporte.values.map((tipo) {
            return DropdownMenuItem<TipoReporte>(
              value: tipo,
              child: Row(
                children: [
                  const Icon(
                    Symbols.description,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tipo.titulo,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null && val != _tipoReporte) {
              setState(() {
                _tipoReporte = val;
              });
              _loadReportData();
            }
          },
        ),
      ),
    );
  }

  Widget _buildCursoDropdown() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.dynamicSurfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCursoId,
          isExpanded: true,
          icon: const Icon(Symbols.keyboard_arrow_down, size: 20),
          dropdownColor: AppTheme.dynamicCard,
          items: [
            DropdownMenuItem(
              value: 'todos',
              child: Row(
                children: [
                  const Icon(Symbols.school, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Todos los cursos',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ..._cursos.map(
              (c) => DropdownMenuItem(
                value: c['id'],
                child: Row(
                  children: [
                    const Icon(
                      Symbols.school,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c['nombre'] ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.dynamicText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null && val != _selectedCursoId) {
              setState(() {
                _selectedCursoId = val;
              });
              _loadReportData();
            }
          },
        ),
      ),
    );
  }

  Widget _buildVerRegistrosButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _loadReportData,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.onPrimary,
              ),
            )
          : const Icon(Symbols.visibility, size: 18),
      label: const Text('Ver Registros'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        minimumSize: const Size(120, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGuardarButton() {
    return OutlinedButton.icon(
      onPressed: _isGeneratingPdf ? null : _handleGuardar,
      icon: _isGeneratingPdf
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            )
          : const Icon(Symbols.save, size: 18),
      label: const Text('Guardar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        side: const BorderSide(color: AppTheme.primary),
        minimumSize: const Size(110, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Symbols.error, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: AppTheme.dynamicText),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReportData,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    final itemCount = switch (_tipoReporte) {
      TipoReporte.alumnos => _filteredAlumnos.length,
      TipoReporte.asistencia => _filteredAsistencias.length,
      TipoReporte.temario => _filteredTemas.length,
      TipoReporte.profesores => _filteredProfesores.length,
    };

    return Column(
      children: [
        // Barra informativa de resumen
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.dynamicSurfaceContainer,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mostrando $itemCount registro(s) en ${_tipoReporte.titulo} • $_currentCursoNombre',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.dynamicTextMuted,
                ),
              ),
              if (_tipoReporte == TipoReporte.asistencia &&
                  _asistenciasResumen.isNotEmpty)
                _buildAttendanceKpiBadge(),
            ],
          ),
        ),
        // Tabla de datos
        Expanded(
          child: itemCount == 0
              ? _buildEmptyView()
              : switch (_tipoReporte) {
                  TipoReporte.alumnos => _buildAlumnosTable(),
                  TipoReporte.asistencia => _buildAsistenciaTable(),
                  TipoReporte.temario => _buildTemasTable(),
                  TipoReporte.profesores => _buildProfesoresTable(),
                },
        ),
      ],
    );
  }

  Widget _buildAttendanceKpiBadge() {
    final totalPresentes = _asistencias
        .where((a) => a.estado == 'Presente')
        .length;
    final total = _asistencias.length;
    final pct = total > 0
        ? (totalPresentes / total * 100).toStringAsFixed(1)
        : '0';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Presentes: $totalPresentes / $total ($pct%)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF059669),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.folder_open, size: 56, color: AppTheme.dynamicTextMuted),
          const SizedBox(height: 12),
          Text(
            'No se encontraron registros para el filtro seleccionado',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.dynamicText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Prueba seleccionando otro curso o limpiando la búsqueda.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.dynamicTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TABLAS RESPONSIVAS
  // ===========================================================================

  Widget _buildAlumnosTable() {
    final list = _filteredAlumnos;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final a = list[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dynamicBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.nombreCompleto,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'C.I.: ${a.cedula} • ${a.cursoNombre}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppTheme.dynamicTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.correo,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tlf: ${a.telefono.isNotEmpty ? a.telefono : "N/A"}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppTheme.dynamicTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: a.estadoInscripcion == 'activo'
                      ? const Color(0xFF059669).withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  a.estadoInscripcion.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: a.estadoInscripcion == 'activo'
                        ? const Color(0xFF059669)
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAsistenciaTable() {
    final list = _filteredAsistencias;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final a = list[index];
        final isPresente = a.estado == 'Presente';
        final fechaStr = DateFormat('dd/MM/yyyy').format(a.fecha);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dynamicBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isPresente
                    ? const Color(0xFF059669).withValues(alpha: 0.1)
                    : Colors.redAccent.withValues(alpha: 0.1),
                child: Icon(
                  isPresente ? Symbols.check : Symbols.close,
                  size: 18,
                  color: isPresente
                      ? const Color(0xFF059669)
                      : Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.nombreCompleto,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'C.I.: ${a.cedula} • ${a.cursoNombre}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppTheme.dynamicTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  fechaStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dynamicText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPresente
                      ? const Color(0xFF059669).withValues(alpha: 0.15)
                      : Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  a.estado.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isPresente
                        ? const Color(0xFF059669)
                        : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemasTable() {
    final list = _filteredTemas;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final t = list[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dynamicBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Sesión ${t.orden}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.titulo,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.descripcion,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppTheme.dynamicTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                t.cursoNombre,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.dynamicTextMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfesoresTable() {
    final list = _filteredProfesores;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = list[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dynamicBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                child: const Icon(
                  Symbols.person,
                  size: 22,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.profesorNombre,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'C.I.: ${p.cedula ?? "N/A"} • ${p.telefono ?? "Sin teléfono"}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppTheme.dynamicTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.cursoNombre,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.horario,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppTheme.dynamicTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${p.totalAlumnos} Alumnos',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
