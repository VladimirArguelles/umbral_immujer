import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/src/core/theme/app_colors.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';

/// Pantalla detallada de Ausencias Hoy por Curso Activo para Coordinación
class AusenciasHoyPage extends StatefulWidget {
  final List<CourseDashboardItem> initialCursos;
  final CoordinatorRepository coordinatorRepository;

  const AusenciasHoyPage({
    super.key,
    required this.initialCursos,
    required this.coordinatorRepository,
  });

  @override
  State<AusenciasHoyPage> createState() => _AusenciasHoyPageState();
}

class _AusenciasHoyPageState extends State<AusenciasHoyPage> {
  late List<CourseDashboardItem> _cursos;
  List<LiveAbsence> _ausencias = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _selectedFilter = 0; // 0 = Todos, 1 = Solo con Ausencias, 2 = Sin Ausencias
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

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    final totalAusencias = _ausencias.length;

    // Agrupar ausencias por nombre de curso
    final Map<String, List<LiveAbsence>> ausenciasPorCurso = {};
    for (final a in _ausencias) {
      final cKey = a.cursoNombre.trim().toLowerCase();
      ausenciasPorCurso.putIfAbsent(cKey, () => []).add(a);
    }

    // Filtrar estrictamente cursos activos hoy
    final cursosActivosHoy = _cursos.where((c) => c.isActiveToday).toList();

    final filteredCursos = cursosActivosHoy.where((c) {
      final cKey = c.nombre.trim().toLowerCase();
      final ausenciasList = ausenciasPorCurso[cKey] ?? [];

      if (_selectedFilter == 1 && ausenciasList.isEmpty) return false;
      if (_selectedFilter == 2 && ausenciasList.isNotEmpty) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCurso = c.nombre.toLowerCase().contains(q);
        final matchProf = (c.profesorNombre ?? '').toLowerCase().contains(q);
        final matchAlumno = ausenciasList.any(
          (a) => a.alumnoNombre.toLowerCase().contains(q) || a.cedula.toLowerCase().contains(q),
        );
        return matchCurso || matchProf || matchAlumno;
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
          children: [
            Text(
              'Ausencias Hoy',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.dynamicText,
              ),
            ),
            Text(
              'Alumnas ausentes en cada curso activo • $_todayIso',
              style: TextStyle(fontSize: 11.5, color: AppTheme.dynamicTextMuted),
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
            tooltip: 'Actualizar ausencias',
            onPressed: _isLoading ? null : _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI Summary Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (totalAusencias > 0 ? AppColors.error : AppColors.mintNeon)
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    AppTheme.dynamicCard,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (totalAusencias > 0 ? AppColors.error : AppColors.mintNeon)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (totalAusencias > 0 ? AppColors.error : AppColors.mintNeon)
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      totalAusencias > 0 ? Symbols.warning : Symbols.check_circle,
                      color: totalAusencias > 0 ? AppColors.error : AppColors.mintNeon,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          totalAusencias > 0
                              ? '$totalAusencias Inasistencias Registradas Hoy'
                              : 'Sin Ausencias Hoy en Cursos Activos',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.dynamicText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.radio_button_checked, size: 12, color: AppColors.mintNeon),
                            const SizedBox(width: 6),
                            Text(
                              'Monitor en tiempo real • ${_cursos.length} cursos supervisados',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.dynamicTextMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
                hintText: 'Buscar por curso, alumna o cédula...',
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
            const SizedBox(height: 12),

            // Filtros rápidos
            Row(
              children: [
                ChoiceChip(
                  label: Text('Activos (${cursosActivosHoy.length})'),
                  selected: _selectedFilter == 0,
                  onSelected: (_) => setState(() => _selectedFilter = 0),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppTheme.dynamicCard,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _selectedFilter == 0 ? Colors.white : AppTheme.dynamicTextMuted,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                  label: const Text('Con Ausencias'),
                  selected: _selectedFilter == 1,
                  onSelected: (_) => setState(() => _selectedFilter = 1),
                  selectedColor: AppColors.error,
                  backgroundColor: AppTheme.dynamicCard,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _selectedFilter == 1 ? Colors.white : AppTheme.dynamicTextMuted,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.mintNeon),
                  label: const Text('Sin Ausencias'),
                  selected: _selectedFilter == 2,
                  onSelected: (_) => setState(() => _selectedFilter = 2),
                  selectedColor: AppColors.mintNeon,
                  backgroundColor: AppTheme.dynamicCard,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _selectedFilter == 2 ? Colors.black : AppTheme.dynamicTextMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Lista agrupada por curso
            if (filteredCursos.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: AppTheme.dynamicTextMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No hay cursos que coincidan con el criterio seleccionado',
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
              ...filteredCursos.map((curso) {
                final cKey = curso.nombre.trim().toLowerCase();
                final listaAusentes = ausenciasPorCurso[cKey] ?? [];
                return _buildCourseAbsenceGroup(curso, listaAusentes, isDark);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseAbsenceGroup(
    CourseDashboardItem curso,
    List<LiveAbsence> ausentes,
    bool isDark,
  ) {
    final tieneFaltas = ausentes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tieneFaltas
              ? AppColors.error.withValues(alpha: 0.5)
              : AppTheme.dynamicBorder,
          width: tieneFaltas ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: tieneFaltas,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tieneFaltas
                  ? AppColors.error.withValues(alpha: 0.15)
                  : AppColors.mintNeon.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tieneFaltas ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
              color: tieneFaltas ? AppColors.error : AppColors.mintNeon,
              size: 20,
            ),
          ),
          title: Text(
            curso.nombre,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.dynamicText,
            ),
          ),
          subtitle: Text(
            'Prof. ${curso.profesorNombre ?? "Sin asignar"} • ${curso.alumnosInscritos} alumnas',
            style: TextStyle(fontSize: 11.5, color: AppTheme.dynamicTextMuted),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tieneFaltas
                  ? AppColors.error.withValues(alpha: 0.15)
                  : AppColors.mintNeon.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tieneFaltas
                    ? AppColors.error.withValues(alpha: 0.5)
                    : AppColors.mintNeon.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              tieneFaltas ? '${ausentes.length} Ausentes' : '0 Ausencias',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: tieneFaltas ? AppColors.error : AppColors.mintNeon,
              ),
            ),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (!tieneFaltas)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mintNeon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.mintNeon.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 18, color: AppColors.mintNeon),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '100% de asistencia registrada en este curso hoy. No hay ausencias reportadas.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.dynamicText,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALUMNAS CON INASISTENCIA REGISTRADA:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...ausentes.map((alumna) => _buildAbsentStudentTile(alumna)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsentStudentTile(LiveAbsence alumna) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dynamicBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.error.withValues(alpha: 0.15),
            child: Text(
              alumna.alumnoNombre.isNotEmpty ? alumna.alumnoNombre[0].toUpperCase() : 'A',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alumna.alumnoNombre,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'C.I: ${alumna.cedula.isNotEmpty ? alumna.cedula : "N/A"}'
                  '${alumna.horaMarcada != null ? " • Hora: ${Formatters.dateTime(alumna.horaMarcada!)}" : ""}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.dynamicTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: const Text(
              'Ausente',
              style: TextStyle(
                fontSize: 10,
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
