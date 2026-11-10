import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/core/utils/schedule_parser.dart';
import 'package:umbral_immujer/src/core/theme/app_colors.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';

enum FiltroCursosActivos {
  enClaseAhora,
  todosHoy,
}

/// Pantalla que muestra en tiempo real los cursos que se encuentran activos según la hora de consulta
class CursosActivosPage extends StatefulWidget {
  final List<CourseDashboardItem> initialCursos;
  final CoordinatorRepository coordinatorRepository;

  const CursosActivosPage({
    super.key,
    required this.initialCursos,
    required this.coordinatorRepository,
  });

  @override
  State<CursosActivosPage> createState() => _CursosActivosPageState();
}

class _CursosActivosPageState extends State<CursosActivosPage> {
  late List<CourseDashboardItem> _cursos;
  bool _isLoading = false;
  String _searchQuery = '';
  FiltroCursosActivos _filtro = FiltroCursosActivos.enClaseAhora;
  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    _cursos = List.from(widget.initialCursos);
    // Refresco reactivo en tiempo real cada 30 segundos según la hora actual
    _realtimeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
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

  String _getNombreDiaHoy() {
    final dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return dias[DateTime.now().weekday - 1];
  }

  void _abrirPlantillaAlumnosYTemas(CourseDashboardItem curso) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => FutureBuilder<Map<String, dynamic>>(
            future: widget.coordinatorRepository.getCourseStudentsAndTemas(curso.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              final data = snapshot.data ?? {};
              final alumnosList = (data['alumnos'] as List? ?? []);
              final temasList = (data['temas'] as List<String>? ?? []);

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                curso.nombre,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.dynamicText,
                                ),
                              ),
                              Text(
                                'Plantilla de Alumnos y Temas del Curso',
                                style: TextStyle(fontSize: 12, color: AppTheme.dynamicTextMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const TabBar(
                      tabs: [
                        Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Alumnas'),
                        Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Temas'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab Alumnas
                          alumnosList.isEmpty
                              ? Center(
                                  child: Text(
                                    'No hay alumnas inscritas en este curso.',
                                    style: TextStyle(color: AppTheme.dynamicTextMuted),
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  itemCount: alumnosList.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final a = alumnosList[i];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                        child: Text(
                                          (a['nombre_completo'] as String? ?? 'A')[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        a['nombre_completo'] ?? 'Sin Nombre',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                      ),
                                      subtitle: Text(
                                        'C.I: ${a['cedula'] ?? 'N/A'} • Tlf: ${a['telefono'] ?? 'N/A'}',
                                        style: TextStyle(fontSize: 11.5, color: AppTheme.dynamicTextMuted),
                                      ),
                                    );
                                  },
                                ),

                          // Tab Temas
                          temasList.isEmpty
                              ? Center(
                                  child: Text(
                                    'No hay temas registrados para este curso.',
                                    style: TextStyle(color: AppTheme.dynamicTextMuted),
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  itemCount: temasList.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (_, i) => ListTile(
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      temasList[i],
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    final now = DateTime.now();
    final diaHoy = _getNombreDiaHoy();
    final horaActualStr = DateFormat('h:mm a').format(now);

    // Cursos programados para hoy en cualquier hora
    final cursosProgramadosHoy = _cursos.where((c) => c.isActiveToday).toList();

    // Cursos activos en clase en este momento exacto
    final cursosActivosAhora = cursosProgramadosHoy.where((c) => c.isActiveNow).toList();

    // Lista según el filtro activo (por defecto: en clase ahora en tiempo real)
    final cursosSegunFiltro = _filtro == FiltroCursosActivos.enClaseAhora
        ? cursosActivosAhora
        : cursosProgramadosHoy;

    final totalMatriculadas = cursosSegunFiltro.fold<int>(0, (prev, c) => prev + c.alumnosInscritos);

    final filteredList = cursosSegunFiltro.where((c) {
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
              'Cursos Activos',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.dynamicText,
              ),
            ),
            Text(
              _filtro == FiltroCursosActivos.enClaseAhora
                  ? 'En clase ahora ($diaHoy, $horaActualStr)'
                  : 'Cursos programados hoy ($diaHoy)',
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
            tooltip: 'Actualizar cursos activos',
            onPressed: _isLoading ? null : _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
          children: [
            // Selector de Modo: En Clase Ahora (Tiempo Real) vs Jornada Hoy
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.dynamicCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dynamicBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterTab(
                      label: 'En Clase Ahora (${cursosActivosAhora.length})',
                      icon: Icons.access_time_filled_rounded,
                      isSelected: _filtro == FiltroCursosActivos.enClaseAhora,
                      isRealtime: true,
                      onTap: () => setState(() => _filtro = FiltroCursosActivos.enClaseAhora),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildFilterTab(
                      label: 'Jornada Hoy (${cursosProgramadosHoy.length})',
                      icon: Icons.calendar_today_rounded,
                      isSelected: _filtro == FiltroCursosActivos.todosHoy,
                      isRealtime: false,
                      onTap: () => setState(() => _filtro = FiltroCursosActivos.todosHoy),
                    ),
                  ),
                ],
              ),
            ),

            // KPI Header Summary
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (_filtro == FiltroCursosActivos.enClaseAhora
                            ? const Color(0xFF0BD984)
                            : AppColors.primary)
                        .withValues(alpha: isDark ? 0.20 : 0.10),
                    AppTheme.dynamicCard,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (_filtro == FiltroCursosActivos.enClaseAhora
                          ? const Color(0xFF0BD984)
                          : AppColors.primary)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_filtro == FiltroCursosActivos.enClaseAhora
                              ? const Color(0xFF0BD984)
                              : AppColors.primary)
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _filtro == FiltroCursosActivos.enClaseAhora
                          ? Symbols.schedule
                          : Symbols.school,
                      color: _filtro == FiltroCursosActivos.enClaseAhora
                          ? const Color(0xFF0BD984)
                          : AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _filtro == FiltroCursosActivos.enClaseAhora
                              ? '${cursosActivosAhora.length} ${cursosActivosAhora.length == 1 ? 'Curso Activo Ahora' : 'Cursos Activos Ahora'} ($diaHoy)'
                              : '${cursosProgramadosHoy.length} Cursos Programados Hoy ($diaHoy)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.dynamicText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _filtro == FiltroCursosActivos.enClaseAhora
                                    ? const Color(0xFF0BD984)
                                    : AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _filtro == FiltroCursosActivos.enClaseAhora
                                    ? 'En sesión formativa a las $horaActualStr • $totalMatriculadas alumnas'
                                    : 'Jornada completa de hoy • $totalMatriculadas alumnas',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.dynamicTextMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                hintText: 'Buscar curso activo o docente...',
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

            // Lista de cursos activos
            if (filteredList.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty
                            ? Icons.search_off_rounded
                            : (_filtro == FiltroCursosActivos.enClaseAhora
                                ? Symbols.schedule
                                : Symbols.event_busy),
                        size: 48,
                        color: AppTheme.dynamicTextMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No se encontraron cursos activos con ese nombre o docente'
                            : (_filtro == FiltroCursosActivos.enClaseAhora
                                ? 'No hay cursos en clase activa en este momento ($horaActualStr).'
                                : 'No hay cursos con clases programadas para hoy ($diaHoy).'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.dynamicTextMuted,
                        ),
                      ),
                      if (_filtro == FiltroCursosActivos.enClaseAhora &&
                          _searchQuery.isEmpty &&
                          cursosProgramadosHoy.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _filtro = FiltroCursosActivos.todosHoy),
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text('Ver los ${cursosProgramadosHoy.length} cursos de hoy ($diaHoy)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              ...filteredList.map((curso) => _buildCourseCard(curso, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isRealtime,
    required VoidCallback onTap,
  }) {
    final activeColor = isRealtime ? const Color(0xFF0BD984) : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: isSelected ? Border.all(color: activeColor, width: 1.2) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeColor : AppTheme.dynamicTextMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeColor : AppTheme.dynamicTextMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(CourseDashboardItem curso, bool isDark) {
    final status = curso.timeStatus;
    final isActiveNow = status == CourseTimeStatus.activeNow;

    Color badgeBg;
    Color badgeBorder;
    Color badgeText;
    String badgeLabel;
    IconData badgeIcon;

    switch (status) {
      case CourseTimeStatus.activeNow:
        badgeBg = const Color(0xFF0BD984).withValues(alpha: 0.15);
        badgeBorder = const Color(0xFF0BD984).withValues(alpha: 0.6);
        badgeText = const Color(0xFF0BD984);
        badgeLabel = 'EN CLASE AHORA';
        badgeIcon = Icons.circle;
        break;
      case CourseTimeStatus.upcomingToday:
        badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        badgeBorder = const Color(0xFFF59E0B).withValues(alpha: 0.6);
        badgeText = const Color(0xFFF59E0B);
        badgeLabel = 'INICIA MÁS TARDE';
        badgeIcon = Icons.schedule_rounded;
        break;
      case CourseTimeStatus.endedToday:
        badgeBg = Colors.grey.withValues(alpha: 0.15);
        badgeBorder = Colors.grey.withValues(alpha: 0.4);
        badgeText = AppTheme.dynamicTextMuted;
        badgeLabel = 'FINALIZADO HOY';
        badgeIcon = Icons.check_circle_outline;
        break;
      case CourseTimeStatus.notToday:
        badgeBg = Colors.grey.withValues(alpha: 0.1);
        badgeBorder = Colors.grey.withValues(alpha: 0.3);
        badgeText = AppTheme.dynamicTextMuted;
        badgeLabel = 'OTRO DÍA';
        badgeIcon = Icons.event_note_rounded;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActiveNow
              ? const Color(0xFF0BD984).withValues(alpha: 0.7)
              : AppTheme.dynamicBorder,
          width: isActiveNow ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isActiveNow
                ? const Color(0xFF0BD984).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isActiveNow ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    curso.nombre,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.dynamicText,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeBorder, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 8, color: badgeText),
                      const SizedBox(width: 4),
                      Text(
                        badgeLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: badgeText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Docente
            Row(
              children: [
                Icon(Icons.badge_outlined, size: 15, color: AppTheme.dynamicTextMuted),
                const SizedBox(width: 6),
                Text(
                  curso.profesorNombre ?? 'Sin profesor asignado',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Horario
            if (curso.horario != null && curso.horario!.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 15, color: AppTheme.dynamicTextMuted),
                  const SizedBox(width: 6),
                  Text(
                    curso.horario!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.dynamicTextMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            const Divider(height: 16),

            // Métricas y botón de detalle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, size: 16, color: AppColors.mintNeon),
                    const SizedBox(width: 6),
                    Text(
                      '${curso.alumnosInscritos} matriculadas',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '• ${curso.presentesHoy} presentes hoy',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.dynamicTextMuted,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _abrirPlantillaAlumnosYTemas(curso),
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text('Ver Plantilla', style: TextStyle(fontSize: 11.5)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
