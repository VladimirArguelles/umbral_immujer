import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/src/core/theme/app_colors.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';

/// Pantalla que proporciona SOLAMENTE información de asistencia y ausentes relacionados a los cursos activos
class AsistenciaCursosPage extends StatefulWidget {
  final List<CourseDashboardItem> initialCursos;
  final CoordinatorRepository coordinatorRepository;

  const AsistenciaCursosPage({
    super.key,
    required this.initialCursos,
    required this.coordinatorRepository,
  });

  @override
  State<AsistenciaCursosPage> createState() => _AsistenciaCursosPageState();
}

class _AsistenciaCursosPageState extends State<AsistenciaCursosPage> {
  late List<CourseDashboardItem> _cursos;
  List<LiveAbsence> _ausencias = [];
  bool _isLoading = true;
  String _searchQuery = '';
  StreamSubscription? _attendanceSub;
  late final String _todayIso;

  @override
  void initState() {
    super.initState();
    _cursos = List.from(widget.initialCursos);
    _todayIso = Formatters.isoDate(DateTime.now());
    _loadData();
    _suscribirRealtime();
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        widget.coordinatorRepository.getCourseDashboard(_todayIso),
        widget.coordinatorRepository.getTodayAbsences(_todayIso),
      ]);
      if (mounted) {
        setState(() {
          _cursos = futures[0] as List<CourseDashboardItem>;
          _ausencias = futures[1] as List<LiveAbsence>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _suscribirRealtime() {
    _attendanceSub = widget.coordinatorRepository.streamTodayAttendance(_todayIso).listen((_) {
      _loadData();
    });
  }

  String _getNombreDiaHoy() {
    final dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return dias[DateTime.now().weekday - 1];
  }

  Color _getPercentageColor(double pct) {
    if (pct >= 85) return AppColors.mintNeon;
    if (pct >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    final diaHoy = _getNombreDiaHoy();

    // FILTRADO ESTRICTO: SOLAMENTE CURSOS ACTIVOS HOY
    final cursosActivosHoy = _cursos.where((c) => c.isActiveToday).toList();

    // Agrupar ausencias registradas hoy por nombre de curso
    final Map<String, List<LiveAbsence>> ausenciasPorCurso = {};
    for (final a in _ausencias) {
      final cKey = a.cursoNombre.trim().toLowerCase();
      ausenciasPorCurso.putIfAbsent(cKey, () => []).add(a);
    }

    final totalAusenciasEnActivos = cursosActivosHoy.fold<int>(0, (prev, c) {
      final cKey = c.nombre.trim().toLowerCase();
      return prev + (ausenciasPorCurso[cKey]?.length ?? c.ausenciasHoy);
    });

    final totalPresentesEnActivos = cursosActivosHoy.fold<int>(
      0,
      (prev, c) => prev + c.presentesHoy,
    );

    final totalMarcadas = totalPresentesEnActivos + totalAusenciasEnActivos;
    final double promedioGeneral = totalMarcadas == 0
        ? 100.0
        : ((totalPresentesEnActivos / totalMarcadas) * 100);

    final filteredList = cursosActivosHoy.where((c) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchNombre = c.nombre.toLowerCase().contains(q);
        final matchProf = (c.profesorNombre ?? '').toLowerCase().contains(q);
        final cKey = c.nombre.trim().toLowerCase();
        final ausentes = ausenciasPorCurso[cKey] ?? [];
        final matchAlumno = ausentes.any(
          (a) => a.alumnoNombre.toLowerCase().contains(q) || a.cedula.toLowerCase().contains(q),
        );
        return matchNombre || matchProf || matchAlumno;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.dynamicBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.dynamicCard,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '% Asistencia & Ausencias',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppTheme.dynamicText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Cursos activos hoy ($diaHoy)',
              style: TextStyle(fontSize: 11.5, color: AppTheme.dynamicTextMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar asistencia y ausentes',
            onPressed: _isLoading ? null : _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
          children: [
            // KPI Summary Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.mintNeon.withValues(alpha: isDark ? 0.2 : 0.1),
                    AppTheme.dynamicCard,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.mintNeon.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.mintNeon.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Symbols.pie_chart,
                      color: AppColors.mintNeon,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${promedioGeneral.toStringAsFixed(1)}% de Asistencia en Cursos Activos',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.dynamicText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalPresentesEnActivos presentes • $totalAusenciasEnActivos ausentes en los ${cursosActivosHoy.length} cursos activos hoy',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.dynamicTextMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Buscador
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Buscar por curso, docente o alumna ausente...',
                hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.dynamicTextMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: AppTheme.dynamicCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dynamicBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dynamicBorder),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lista de cursos activos con información detallada de sus ausentes
            if (filteredList.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty ? Icons.search_off_rounded : Symbols.event_busy,
                        size: 48,
                        color: AppTheme.dynamicTextMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No se encontraron resultados con ese criterio'
                            : 'No hay cursos activos con clases hoy ($diaHoy)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.dynamicTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredList.map((curso) {
                final cKey = curso.nombre.trim().toLowerCase();
                final ausentesCurso = ausenciasPorCurso[cKey] ?? [];
                return _buildActiveCourseAttendanceCard(curso, ausentesCurso, isDark);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCourseAttendanceCard(
    CourseDashboardItem curso,
    List<LiveAbsence> ausentes,
    bool isDark,
  ) {
    final pct = curso.porcentajeAsistencia;
    final color = _getPercentageColor(pct);
    final countAusencias = ausentes.isNotEmpty ? ausentes.length : curso.ausenciasHoy;
    final tieneAusentes = countAusencias > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tieneAusentes
              ? AppColors.error.withValues(alpha: 0.45)
              : AppColors.mintNeon.withValues(alpha: 0.45),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: Nombre del curso y Porcentaje
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.mintNeon.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ACTIVO HOY',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mintNeon,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (curso.horario != null && curso.horario!.isNotEmpty)
                          Text(
                            curso.horario!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.dynamicTextMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      curso.nombre,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prof. ${curso.profesorNombre ?? "Sin asignar"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Badge de porcentaje
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    Text(
                      'Asistencia',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 7,
              backgroundColor: isDark ? const Color(0xFF262335) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),

          // Conteo de presentes y ausencias
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.mintNeon),
              const SizedBox(width: 4),
              Text(
                '${curso.presentesHoy} Presentes',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.cancel_rounded,
                size: 14,
                color: tieneAusentes ? AppColors.error : AppTheme.dynamicTextMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '$countAusencias Ausencias',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: tieneAusentes ? AppColors.error : AppTheme.dynamicTextMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // SECCIÓN ESPECÍFICA: INFORMACIÓN DE LOS AUSENTES RELACIONADOS A ESTE CURSO ACTIVO
          if (!tieneAusentes)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.mintNeon.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.mintNeon.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, size: 16, color: AppColors.mintNeon),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '100% de asistencia. Sin ausencias registradas en este curso activo hoy.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mintNeon,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              'ALUMNAS AUSENTES EN ESTE CURSO ACTIVO ($countAusencias):',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.error,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            if (ausentes.isNotEmpty)
              ...ausentes.map((alumna) => _buildAbsentStudentItem(alumna))
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$countAusencias alumnas marcadas ausentes en el pase de lista de hoy.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.error),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAbsentStudentItem(LiveAbsence alumna) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.dynamicBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.error.withValues(alpha: 0.15),
            child: Text(
              alumna.alumnoNombre.isNotEmpty ? alumna.alumnoNombre[0].toUpperCase() : 'A',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alumna.alumnoNombre,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'C.I: ${alumna.cedula.isNotEmpty ? alumna.cedula : "N/A"}'
                  '${alumna.horaMarcada != null ? " • Hora: ${Formatters.dateTime(alumna.horaMarcada!)}" : ""}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.dynamicTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Ausente',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
