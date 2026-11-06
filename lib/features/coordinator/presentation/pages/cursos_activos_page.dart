import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/src/core/theme/app_colors.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';

/// Pantalla que muestra SOLAMENTE los cursos que se encuentran activos en el momento/jornada actual
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
    final diaHoy = _getNombreDiaHoy();

    // FILTRADO ESTRICTO: SOLAMENTE CURSOS QUE SE ENCUENTRAN ACTIVOS HOY
    final cursosActivosHoy = _cursos.where((c) => c.isActiveToday).toList();
    final totalMatriculadas = cursosActivosHoy.fold<int>(0, (prev, c) => prev + c.alumnosInscritos);

    final filteredList = cursosActivosHoy.where((c) {
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
              'Cursos activos en jornada de hoy ($diaHoy)',
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
          padding: const EdgeInsets.all(16),
          children: [
            // KPI Header Summary
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                    AppTheme.dynamicCard,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Symbols.school,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cursosActivosHoy.length} Cursos Activos Hoy ($diaHoy)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
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
                              decoration: const BoxDecoration(
                                color: AppColors.mintNeon,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'En sesión formativa hoy • $totalMatriculadas alumnas',
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
                        _searchQuery.isNotEmpty ? Icons.search_off_rounded : Symbols.event_busy,
                        size: 48,
                        color: AppTheme.dynamicTextMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No se encontraron cursos activos con ese nombre'
                            : 'No hay cursos con clases programadas para hoy ($diaHoy)',
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
              ...filteredList.map((curso) => _buildCourseCard(curso, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(CourseDashboardItem curso, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
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
                    color: AppColors.mintNeon.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.mintNeon.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 8,
                        color: AppColors.mintNeon,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ACTIVO HOY',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mintNeon,
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
