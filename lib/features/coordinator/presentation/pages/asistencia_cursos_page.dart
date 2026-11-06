import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/src/core/theme/app_colors.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';

/// Pantalla detallada de Porcentaje de Asistencia por Curso Activo
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
  bool _isLoading = false;
  String _searchQuery = '';
  int _selectedFilter = 0; // 0 = Todos, 1 = Con Registro Hoy, 2 = Con Faltas

  @override
  void initState() {
    super.initState();
    _cursos = List.from(widget.initialCursos);
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      final todayStr = Formatters.isoDate(DateTime.now());
      final updated = await widget.coordinatorRepository.getCourseDashboard(todayStr);
      if (mounted) {
        setState(() {
          _cursos = updated;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getPercentageColor(double pct) {
    if (pct >= 85) return AppColors.mintNeon;
    if (pct >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    final totalAusencias = _cursos.fold<int>(0, (prev, c) => prev + c.ausenciasHoy);
    final totalPresentes = _cursos.fold<int>(0, (prev, c) => prev + c.presentesHoy);
    final totalMarcadas = totalPresentes + totalAusencias;
    final double promedioGeneral = totalMarcadas == 0
        ? 100.0
        : ((totalPresentes / totalMarcadas) * 100);

    final filteredList = _cursos.where((c) {
      final totalDelCurso = c.presentesHoy + c.ausenciasHoy;
      if (_selectedFilter == 1 && totalDelCurso == 0) return false;
      if (_selectedFilter == 2 && c.ausenciasHoy == 0) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchNombre = c.nombre.toLowerCase().contains(q);
        final matchProf = (c.profesorNombre ?? '').toLowerCase().contains(q);
        return matchNombre || matchProf;
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
              '% Asistencia por Curso',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.dynamicText,
              ),
            ),
            Text(
              'Rendimiento y porcentaje de asistencia por formación',
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
            tooltip: 'Actualizar métricas',
            onPressed: _isLoading ? null : _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
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
                          '${promedioGeneral.toStringAsFixed(1)}% de Asistencia Global',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.dynamicText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalPresentes alumnas presentes • $totalAusencias inasistencias registradas hoy',
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
                hintText: 'Buscar por curso o docente...',
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
                  label: Text('Todos (${_cursos.length})'),
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
                  label: const Text('Con Registro Hoy'),
                  selected: _selectedFilter == 1,
                  onSelected: (_) => setState(() => _selectedFilter = 1),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppTheme.dynamicCard,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _selectedFilter == 1 ? Colors.white : AppTheme.dynamicTextMuted,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                  label: const Text('Con Ausencias'),
                  selected: _selectedFilter == 2,
                  onSelected: (_) => setState(() => _selectedFilter = 2),
                  selectedColor: AppColors.warning,
                  backgroundColor: AppTheme.dynamicCard,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _selectedFilter == 2 ? Colors.white : AppTheme.dynamicTextMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Lista de cursos con su porcentaje de asistencia
            if (filteredList.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: AppTheme.dynamicTextMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No hay cursos activos que coincidan con la búsqueda',
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
              ...filteredList.map((curso) => _buildAttendanceCard(curso, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(CourseDashboardItem curso, bool isDark) {
    final pct = curso.porcentajeAsistencia;
    final color = _getPercentageColor(pct);
    final totalSesion = curso.presentesHoy + curso.ausenciasHoy;
    final tieneRegistroHoy = totalSesion > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dynamicBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      curso.nombre,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prof. ${curso.profesorNombre ?? "Sin asignar"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Badge con % de Asistencia
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barra de progreso visual
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF262335) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),

          // Métricas desglosadas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: AppColors.mintNeon),
                  const SizedBox(width: 4),
                  Text(
                    '${curso.presentesHoy} Presentes',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.dynamicText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.cancel_rounded, size: 14, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text(
                    '${curso.ausenciasHoy} Ausencias',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: curso.ausenciasHoy > 0 ? AppColors.error : AppTheme.dynamicTextMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tieneRegistroHoy
                      ? AppColors.mintNeon.withValues(alpha: 0.1)
                      : AppTheme.dynamicBorder.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tieneRegistroHoy ? 'Pase de lista hoy' : 'Sin lista hoy',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: tieneRegistroHoy ? AppColors.mintNeon : AppTheme.dynamicTextMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
