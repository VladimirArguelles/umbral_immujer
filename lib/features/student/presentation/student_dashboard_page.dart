import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/features/student/data/student_repository.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';
import 'package:umbral_immujer/features/student/presentation/student_summary_tab.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class StudentDashboardPage extends StatefulWidget {
  final UserProfile profile;
  final int initialIndex;
  const StudentDashboardPage({
    super.key,
    required this.profile,
    this.initialIndex = 0,
  });

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  late int _currentIndex;
  late final StudentRepository _studentRepository;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _studentRepository = StudentRepository(SupabaseConfig.client);
  }

  void _handleSignOut() async {
    await SupabaseConfig.client.auth.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      StudentSummaryTab(
        studentName: widget.profile.fullName,
        onNavigate: (index) => setState(() => _currentIndex = index),
      ),
      _MisCursosTab(studentRepository: _studentRepository),
      _MisAsistenciasTab(studentRepository: _studentRepository),
      _EncuestasAportesTab(studentRepository: _studentRepository),
    ];

    final isSuperAdmin = widget.profile.role == UserRole.superAdmin;

    return Scaffold(
      appBar: AppBar(
        leading: isSuperAdmin
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Volver a Super Admin',
                onPressed: () => context.go('/superadmin'),
              )
            : null,
        title: Column(
          children: [
            Text(
              isSuperAdmin ? 'UMBRAL • Alumna/o (Super Admin)' : 'UMBRAL • Alumna/o',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.profile.fullName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: Column(
        children: [
          if (isSuperAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer.withValues(alpha: 0.25),
                border: const Border(
                  bottom: BorderSide(
                    color: AppTheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Modo Super Admin • Módulo Alumnos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => context.go('/superadmin'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            size: 14,
                            color: AppTheme.onPrimary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Volver al Panel',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: tabs[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Mis Cursos',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            selectedIcon: Icon(Icons.event_available),
            label: 'Asistencias',
          ),
          NavigationDestination(
            icon: Icon(Icons.poll_outlined),
            selectedIcon: Icon(Icons.poll),
            label: 'Encuestas',
          ),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------
/// TAB 1: MIS CURSOS (Activos e Historial de Cursos)
/// -------------------------------------------------------------
class _MisCursosTab extends StatefulWidget {
  final StudentRepository studentRepository;
  const _MisCursosTab({required this.studentRepository});

  @override
  State<_MisCursosTab> createState() => _MisCursosTabState();
}

class _MisCursosTabState extends State<_MisCursosTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<StudentCourse>> _cursosActivosFuture;
  late Future<List<StudentCourse>> _cursosHistorialFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCursos();
  }

  void _loadCursos() {
    setState(() {
      _cursosActivosFuture = widget.studentRepository.getMyCourses(
        statusFilter: 'activo',
      );
      _cursosHistorialFuture = widget.studentRepository.getMyCourses(
        statusFilter: 'finalizado',
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.onSurfaceVariant,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Cursos Activos', icon: Icon(Icons.play_circle_outline)),
            Tab(text: 'Historial / Finalizados', icon: Icon(Icons.history_edu)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildListaCursos(
                _cursosActivosFuture,
                'No estás inscrita en ningún curso activo actualmente.',
              ),
              _buildListaCursos(
                _cursosHistorialFuture,
                'No tienes cursos finalizados en tu historial.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListaCursos(
    Future<List<StudentCourse>> future,
    String emptyMsg,
  ) {
    return FutureBuilder<List<StudentCourse>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final cursos = snapshot.data ?? [];
        if (cursos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                emptyMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.onSurfaceVariant),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadCursos(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cursos.length,
            itemBuilder: (context, idx) {
              final c = cursos[idx];
              final isActivo = c.estado == 'activo';
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              c.nombre,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActivo
                                  ? AppTheme.tertiary.withValues(alpha: 0.15)
                                  : AppTheme.surfaceBright,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              c.estado.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActivo
                                    ? AppTheme.successGreen
                                    : AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (c.descripcion != null &&
                          c.descripcion!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          c.descripcion!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Profesor: ${c.profesorNombre ?? "Por asignar"}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      if (c.horario != null && c.horario!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 16,
                              color: AppTheme.secondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              c.horario!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// -------------------------------------------------------------
/// TAB 2: MIS ASISTENCIAS (Alerta Roja 2da Ausencia + Métricas)
/// -------------------------------------------------------------
class _MisAsistenciasTab extends StatefulWidget {
  final StudentRepository studentRepository;
  const _MisAsistenciasTab({required this.studentRepository});

  @override
  State<_MisAsistenciasTab> createState() => _MisAsistenciasTabState();
}

class _MisAsistenciasTabState extends State<_MisAsistenciasTab> {
  List<StudentCourse> _misCursos = [];
  StudentCourse? _selectedCurso;
  AttendanceSummary? _resumen;
  List<JustificativoAsistencia> _justificativos = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCursos();
  }

  void _loadCursos() async {
    setState(() => _isLoading = true);
    final cursos = await widget.studentRepository.getMyCourses(
      statusFilter: 'activo',
    );
    if (!mounted) return;
    setState(() {
      _misCursos = cursos;
      if (cursos.isNotEmpty) {
        _selectedCurso = cursos.first;
      }
      _isLoading = false;
    });
    if (_selectedCurso != null) {
      _loadAsistenciasCurso(_selectedCurso!.id);
    }
  }

  void _loadAsistenciasCurso(String cursoId) async {
    final resumen = await widget.studentRepository.getAttendanceByCourse(
      cursoId,
    );
    final justificativos = await widget.studentRepository.getJustificativos(
      cursoId: cursoId,
    );
    if (mounted) {
      setState(() {
        _resumen = resumen;
        _justificativos = justificativos;
      });
    }
  }

  JustificativoAsistencia? _getJustificativoForDate(String fecha) {
    try {
      return _justificativos.firstWhere((j) => j.fecha == fecha);
    } catch (_) {
      return null;
    }
  }

  void _mostrarDialogoJustificativo({String? initialFecha}) {
    if (_selectedCurso == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalJustificarAusencia(
        curso: _selectedCurso!,
        initialFecha: initialFecha,
        studentRepository: widget.studentRepository,
        picker: _picker,
        onSubmitted: () {
          _loadAsistenciasCurso(_selectedCurso!.id);
        },
      ),
    );
  }

  void _verComprobanteGrande(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.anthraciteCard,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.image_outlined, color: AppTheme.coralFuchsia, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Comprobante Médico Adjunto',
                    style: TextStyle(
                      color: AppTheme.pureWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.mutedGray),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.outlineVariant),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Padding(
                        padding: EdgeInsets.all(30),
                        child: Text(
                          'No se pudo cargar la vista previa de la imagen.',
                          style: TextStyle(color: AppTheme.errorRed),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_misCursos.isEmpty) {
      return const Center(
        child: Text(
          'No estás inscrito en cursos activos para consultar asistencias.',
        ),
      );
    }

    final resumen = _resumen;

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedCurso != null) _loadAsistenciasCurso(_selectedCurso!.id);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selector de Curso
            DropdownButtonFormField<StudentCourse>(
              isExpanded: true,
              initialValue: _selectedCurso,
              decoration: const InputDecoration(
                labelText: 'Selecciona el Curso',
                prefixIcon: Icon(Icons.class_outlined),
              ),
              selectedItemBuilder: (BuildContext context) {
                return _misCursos.map((c) {
                  return Text(
                    c.nombre,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }).toList();
              },
              items: _misCursos.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(
                    c.nombre,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCurso = val);
                  _loadAsistenciasCurso(val.id);
                }
              },
            ),
            const SizedBox(height: 14),

            // BOTÓN PRINCIPAL DE LLAMADA A LA ACCIÓN (CTA): JUSTIFICAR AUSENCIA MÉDICA
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.coralFuchsia,
                    AppTheme.coralFuchsia.withValues(alpha: 0.85),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.coralFuchsia.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _mostrarDialogoJustificativo(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.medical_services_rounded, color: AppTheme.pureWhite, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Justificar Ausencia Médica',
                          style: TextStyle(
                            color: AppTheme.pureWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ALERTA AUTOMÁTICA A LA 2DA AUSENCIA
            if (resumen != null && resumen.tieneAlertaDosAusencias) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.errorRed.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.onError,
                      size: 36,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Atención: Has acumulado 2 inasistencias en este curso',
                            style: TextStyle(
                              color: AppTheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Inasistencias registradas: ${resumen.inasistencias}. Puedes justificar tus ausencias por causa médica adjuntando tu reposo en el botón superior.',
                            style: const TextStyle(
                              color: AppTheme.onErrorContainer,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Tarjetas de Métricas de Asistencia
            if (resumen != null) ...[
              Row(
                children: [
                  _buildMetricaCard(
                    title: 'Clases Totales',
                    count: '${resumen.totalClases}',
                    color: AppTheme.primary,
                    icon: Icons.calendar_month,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricaCard(
                    title: 'Presente',
                    count: '${resumen.presentes}',
                    color: AppTheme.mintNeon,
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricaCard(
                    title: 'Inasistencias',
                    count: '${resumen.inasistencias}',
                    color: resumen.tieneAlertaDosAusencias
                        ? AppTheme.errorRed
                        : AppTheme.warningOrange,
                    icon: Icons.cancel_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Historial Detallado de Clases
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registro Detallado por Clase',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  Text(
                    '${resumen.historial.length} sesiones',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (resumen.historial.isEmpty)
                Card(
                  color: AppTheme.anthraciteCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.outlineVariant),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: Text(
                        'Aún no se han registrado asistencias para este curso.',
                        style: TextStyle(color: AppTheme.mutedGray),
                      ),
                    ),
                  ),
                )
              else
                ...resumen.historial.map((reg) {
                  final esPresente = reg.estado.toLowerCase() == 'presente';
                  final just = _getJustificativoForDate(reg.fecha);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: AppTheme.anthraciteCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: just != null && just.isAprobado
                            ? AppTheme.mintNeon.withValues(alpha: 0.4)
                            : AppTheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: esPresente
                                    ? AppTheme.mintNeon.withValues(alpha: 0.15)
                                    : (just != null && just.isAprobado
                                        ? AppTheme.mintNeon.withValues(alpha: 0.15)
                                        : AppTheme.errorRed.withValues(alpha: 0.15)),
                                child: Icon(
                                  esPresente
                                      ? Icons.check
                                      : (just != null && just.isAprobado
                                          ? Icons.verified_user_outlined
                                          : Icons.close),
                                  size: 20,
                                  color: esPresente || (just != null && just.isAprobado)
                                      ? AppTheme.mintNeon
                                      : AppTheme.errorRed,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fecha: ${reg.fecha}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.pureWhite,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (!esPresente && just != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Justificativo: ${just.isAprobado ? "Aprobado (Justificada)" : just.isRechazado ? "Rechazado" : "En Revisión"}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: just.isAprobado
                                              ? AppTheme.mintNeon
                                              : just.isRechazado
                                                  ? AppTheme.errorRed
                                                  : AppTheme.warningOrange,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: esPresente
                                      ? AppTheme.mintNeon
                                      : (just != null && just.isAprobado
                                          ? AppTheme.mintNeon
                                          : AppTheme.errorRed),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  (just != null && just.isAprobado)
                                      ? 'JUSTIFICADA'
                                      : reg.estado.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.anthraciteDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!esPresente) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: AppTheme.outlineVariant),
                            const SizedBox(height: 6),
                            if (just == null) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.coralFuchsia,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                                  label: const Text(
                                    'Subir justificativo para esta falta',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => _mostrarDialogoJustificativo(
                                    initialFecha: reg.fecha,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Motivo: "${just.motivo}"',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: AppTheme.mutedGray,
                                      ),
                                    ),
                                  ),
                                  if (just.comprobanteUrl != null && just.comprobanteUrl!.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                      color: AppTheme.mintNeon,
                                      tooltip: 'Ver comprobante médico adjunto',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _verComprobanteGrande(just.comprobanteUrl!),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),

              // SECCIÓN: JUSTIFICATIVOS MÉDICOS REGISTRADOS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Historial de Justificativos Médicos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.pureWhite,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.anthraciteElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_justificativos.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.coralFuchsia,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_justificativos.isEmpty)
                Card(
                  color: AppTheme.anthraciteCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.outlineVariant),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No has enviado justificativos médicos para este curso.',
                        style: TextStyle(
                          color: AppTheme.mutedGray,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                )
              else
                ..._justificativos.map((just) {
                  final chipColor = just.isAprobado
                      ? AppTheme.mintNeon
                      : just.isRechazado
                          ? AppTheme.errorRed
                          : AppTheme.warningOrange;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: AppTheme.anthraciteCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppTheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.event_note, color: AppTheme.coralFuchsia, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Fecha de falta: ${just.fecha}',
                                    style: const TextStyle(
                                      color: AppTheme.pureWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: chipColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: chipColor.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  just.estado.toUpperCase(),
                                  style: TextStyle(
                                    color: chipColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            just.motivo,
                            style: const TextStyle(
                              color: AppTheme.pureWhite,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                          if (just.comentariosRevision != null &&
                              just.comentariosRevision!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.anthraciteElevated,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.rate_review_outlined,
                                      size: 16, color: AppTheme.mutedGray),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Respuesta de Coordinación: ${just.comentariosRevision}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.mutedGray,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (just.comprobanteUrl != null &&
                              just.comprobanteUrl!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.mintNeon,
                                side: const BorderSide(color: AppTheme.mintNeon),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.attachment, size: 16),
                              label: const Text(
                                'Ver imagen del justificativo médico',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _verComprobanteGrande(just.comprobanteUrl!),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricaCard({
    required String title,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        color: AppTheme.anthraciteCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalJustificarAusencia extends StatefulWidget {
  final StudentCourse curso;
  final String? initialFecha;
  final StudentRepository studentRepository;
  final ImagePicker picker;
  final VoidCallback onSubmitted;

  const _ModalJustificarAusencia({
    required this.curso,
    this.initialFecha,
    required this.studentRepository,
    required this.picker,
    required this.onSubmitted,
  });

  @override
  State<_ModalJustificarAusencia> createState() =>
      _ModalJustificarAusenciaState();
}

class _ModalJustificarAusenciaState extends State<_ModalJustificarAusencia> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fechaController;
  final _motivoController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageExtension;
  String? _imageName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final defaultDate = widget.initialFecha ?? Formatters.isoDate(DateTime.now());
    _fechaController = TextEditingController(text: defaultDate);
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    DateTime parsedInitial;
    try {
      parsedInitial = DateTime.parse(_fechaController.text);
    } catch (_) {
      parsedInitial = hoy;
    }

    final seleccionada = await showDatePicker(
      context: context,
      initialDate: parsedInitial.isAfter(hoy) ? hoy : parsedInitial,
      firstDate: DateTime(hoy.year - 1),
      lastDate: hoy,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.coralFuchsia,
              surface: AppTheme.anthraciteCard,
              onSurface: AppTheme.pureWhite,
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccionada != null) {
      setState(() {
        _fechaController.text = Formatters.isoDate(seleccionada);
      });
    }
  }

  Future<void> _capturarImagen(ImageSource source) async {
    try {
      final picked = await widget.picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext =
          picked.name.contains('.') ? picked.name.split('.').last : 'jpg';

      setState(() {
        _imageBytes = bytes;
        _imageExtension = ext;
        _imageName = picked.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al capturar la imagen: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _enviarJustificativo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes adjuntar la foto o imagen del justificativo médico.',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.studentRepository.submitAbsenceJustification(
        cursoId: widget.curso.id,
        fecha: _fechaController.text.trim(),
        motivo: _motivoController.text.trim(),
        imageBytes: _imageBytes,
        fileExtension: _imageExtension,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Justificativo médico registrado! En espera de revisión por el docente o coordinación.',
            ),
            backgroundColor: AppTheme.mintNeon,
          ),
        );
        widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar justificativo: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.anthraciteCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppTheme.outlineVariant),
          left: BorderSide(color: AppTheme.outlineVariant),
          right: BorderSide(color: AppTheme.outlineVariant),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra superior de agarre
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cabecera del modal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.coralFuchsia.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.medical_services_rounded,
                      color: AppTheme.coralFuchsia,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Justificar Ausencia Médica',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.pureWhite,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Curso: ${widget.curso.nombre}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.mutedGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.mutedGray),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Selector de Fecha
              const Text(
                'Fecha de la Falta / Ausencia',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.pureWhite,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _fechaController,
                readOnly: true,
                style: const TextStyle(color: AppTheme.pureWhite, fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.calendar_today, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: _seleccionarFecha,
                  ),
                  hintText: 'YYYY-MM-DD',
                ),
                onTap: _seleccionarFecha,
              ),
              const SizedBox(height: 16),

              // Argumento / Motivo de la Ausencia
              const Text(
                'Motivo y Argumento de la Ausencia',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.pureWhite,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _motivoController,
                maxLines: 4,
                style: const TextStyle(color: AppTheme.pureWhite, fontSize: 14),
                decoration: const InputDecoration(
                  hintText:
                      'Explica detalladamente la causa médica (ej. Reposo médico por cuadro viral certificado por el Dr. Pérez, consulta de emergencia...)',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa el motivo de tu ausencia médica';
                  }
                  if (val.trim().length < 8) {
                    return 'El argumento debe contener al menos 8 caracteres explicativos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Imagen del Justificativo Médico
              const Text(
                'Soporte Médico (Foto del Justificativo / Reposo)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.pureWhite,
                ),
              ),
              const SizedBox(height: 8),

              if (_imageBytes == null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.anthraciteElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.outlineVariant,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 38,
                        color: AppTheme.coralFuchsia,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Adjunta la foto legible de tu reposo o constancia',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.mutedGray,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.pureWhite,
                                side: const BorderSide(color: AppTheme.outline),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Cámara', style: TextStyle(fontSize: 12)),
                              onPressed: () => _capturarImagen(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.pureWhite,
                                side: const BorderSide(color: AppTheme.outline),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: const Text('Galería', style: TextStyle(fontSize: 12)),
                              onPressed: () => _capturarImagen(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.anthraciteElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.mintNeon.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _imageBytes!,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Comprobante adjuntado',
                              style: TextStyle(
                                color: AppTheme.mintNeon,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _imageName ?? 'comprobante.jpg',
                              style: const TextStyle(
                                color: AppTheme.mutedGray,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${(_imageBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(
                                color: AppTheme.mutedGray,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                        tooltip: 'Eliminar imagen',
                        onPressed: () {
                          setState(() {
                            _imageBytes = null;
                            _imageExtension = null;
                            _imageName = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Botón de Envío
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coralFuchsia,
                  foregroundColor: AppTheme.pureWhite,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _enviarJustificativo,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.pureWhite,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _isSubmitting ? 'Enviando a Coordinación...' : 'Enviar Justificativo',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// -------------------------------------------------------------
/// TAB 3: ENCUESTAS Y APORTES (Filtro de Selección, Card de Insumos y Capture)
/// -------------------------------------------------------------
class _EncuestasAportesTab extends StatefulWidget {
  final StudentRepository studentRepository;
  const _EncuestasAportesTab({required this.studentRepository});

  @override
  State<_EncuestasAportesTab> createState() => _EncuestasAportesTabState();
}

class _EncuestasAportesTabState extends State<_EncuestasAportesTab> {
  // Filtro de Selección: 0 = Encuestas Disponibles, 1 = Historial de Encuestas, 2 = Historial de Pago
  int _selectedFilter = 0;

  late Future<List<StudentSurvey>> _encuestasDisponiblesFuture;
  late Future<List<StudentSurvey>> _historialEncuestasFuture;
  late Future<List<StudentPaymentRecord>> _historialPagosFuture;

  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    setState(() {
      _encuestasDisponiblesFuture = widget.studentRepository.getActiveSurveys();
      _historialEncuestasFuture = widget.studentRepository.getSurveysHistory();
      _historialPagosFuture = widget.studentRepository.getPaymentHistory();
    });
  }


  Future<void> _seleccionarYSubirComprobante(
    String surveyId,
    ImageSource source,
  ) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      await widget.studentRepository.uploadPaymentProof(
        surveyId: surveyId,
        imageFile: File(picked.path),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Capture del pago subido exitosamente! En espera de verificación docente.',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir capture: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _mostrarSelectorComprobante(String surveyId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
              title: const Text('Tomar foto con la Cámara'),
              onTap: () {
                Navigator.of(ctx).pop();
                _seleccionarYSubirComprobante(surveyId, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppTheme.secondary,
              ),
              title: const Text('Seleccionar capture de la Galería'),
              onTap: () {
                Navigator.of(ctx).pop();
                _seleccionarYSubirComprobante(surveyId, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarModalComprobante(
    BuildContext context, {
    required String url,
    required String curso,
    required String fecha,
    required String estadoPago,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppTheme.surfaceContainerLow,
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            curso,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Clase: $fecha • Estado: ${estadoPago.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  color: Colors.black87,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.network(
                        url,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image,
                                  size: 48, color: Colors.white70),
                              SizedBox(height: 8),
                              Text(
                                'No se pudo cargar la imagen del comprobante',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtro de Selección (Encuestas Disponibles, Historial de Encuestas, Historial de Pago)
        _buildFilterSelector(),
        // Contenido según el filtro activo
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildCurrentFilteredView(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: const Border(
          bottom: BorderSide(
            color: AppTheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: AppTheme.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Filtro de Selección:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBright,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedFilter,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.primary,
                ),
                dropdownColor: AppTheme.surfaceBright,
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem<int>(
                    value: 0,
                    child: Row(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Encuestas Disponibles',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem<int>(
                    value: 1,
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: AppTheme.secondary,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Historial de Encuestas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem<int>(
                    value: 2,
                    child: Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: AppTheme.tertiary,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Historial de Pago',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (newVal) {
                  if (newVal != null) {
                    setState(() => _selectedFilter = newVal);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentFilteredView() {
    switch (_selectedFilter) {
      case 0:
        return _buildEncuestasDisponiblesView();
      case 1:
        return _buildHistorialEncuestasView();
      case 2:
        return _buildHistorialPagosView();
      default:
        return _buildEncuestasDisponiblesView();
    }
  }

  /// OPCIÓN 0: ENCUESTAS DISPONIBLES (Card de Monto de Insumos + Botón de Capture de Pago)
  Widget _buildEncuestasDisponiblesView() {
    return FutureBuilder<List<StudentSurvey>>(
      key: const ValueKey('encuestas_disponibles'),
      future: _encuestasDisponiblesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final rawData = snapshot.data ?? [];
        final encuestas = rawData.where((e) => e.estadoEncuesta == 'activa' && !e.estaVencida).toList();

        if (encuestas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay encuestas de insumos activas en este momento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedFilter = 1),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Ver Historial de Encuestas'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadAll(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: encuestas.length,
            itemBuilder: (context, idx) {
              final enc = encuestas[idx];

              return Card(
                margin: const EdgeInsets.only(bottom: 18),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppTheme.mintNeon.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                color: AppTheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado del Curso, Próxima Clase y Estado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'CURSO ASIGNADO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        enc.cursoNombre,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (enc.profesorNombre != null && enc.profesorNombre!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.secondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Docente: ${enc.profesorNombre}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.mintNeon),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Próxima Clase Práctica: ${enc.fechaClase}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.mintNeon,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: enc.estaVencida
                                  ? AppTheme.errorRed.withValues(alpha: 0.12)
                                  : AppTheme.tertiary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: enc.estaVencida ? AppTheme.errorRed : AppTheme.successGreen,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              enc.estaVencida ? 'CERRADA' : 'ACTIVA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: enc.estaVencida
                                    ? AppTheme.errorRed
                                    : AppTheme.successGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Límite de Confirmación: ${Formatters.dateTime(enc.fechaLimite)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // WIDGET CARD: MONTO DEL APORTE COLOCADO POR EL PROFESOR PARA INSUMOS
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.anthraciteElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.mintNeon.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.mintNeon.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mintNeon.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppTheme.mintNeon,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'APORTE PARA COMPRA DE INSUMOS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                          color: AppTheme.mintNeon,
                                        ),
                                      ),
                                      Text(
                                        'Monto fijado por el docente para la próxima clase',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Monto del aporte individual a cancelar:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              enc.cuotaACancelar > 0
                                  ? Formatters.currency(enc.cuotaACancelar)
                                  : Formatters.currency(0),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.mintNeon,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(
                              height: 1,
                              thickness: 0.5,
                              color: AppTheme.outlineVariant,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.receipt_outlined, size: 14, color: AppTheme.secondary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Presupuesto Total Insumos: ${Formatters.currency(enc.costoTotalInsumos)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.onSurfaceVariant,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryContainer.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${enc.totalConfirmados} confirmados',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // BOTÓN PARA SUBIR LA IMAGEN DEL CAPTURE DEL PAGO REALIZADO
                      if (enc.comprobanteUrl == null || enc.comprobanteUrl!.isEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryContainer,
                              foregroundColor: AppTheme.pureWhite,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isUploading
                                ? null
                                : () => _mostrarSelectorComprobante(enc.id),
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_photo_alternate_rounded, size: 20),
                            label: Text(
                              _isUploading
                                  ? 'Subiendo comprobante...'
                                  : 'Subir Imagen del Capture de Pago Realizado',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            'Comprobantes aceptados: Pago Móvil o Transferencia en Bolívares (Bs.)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceBright,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.mintNeon.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.mintNeon,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Capture de Pago Adjuntado',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Estado: ${(enc.estadoPago ?? "pendiente").toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: enc.estadoPago == 'verificado'
                                            ? AppTheme.successGreen
                                            : enc.estadoPago == 'rechazado'
                                                ? AppTheme.errorRed
                                                : AppTheme.warningOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: () => _mostrarModalComprobante(
                                  context,
                                  url: enc.comprobanteUrl!,
                                  curso: enc.cursoNombre,
                                  fecha: enc.fechaClase,
                                  estadoPago: enc.estadoPago ?? 'pendiente',
                                ),
                                icon: const Icon(Icons.visibility_outlined, size: 14),
                                label: const Text('Ver Capture', style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.secondary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: _isUploading
                                    ? null
                                    : () => _mostrarSelectorComprobante(enc.id),
                                icon: const Icon(Icons.sync, size: 14),
                                label: const Text('Cambiar', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// OPCIÓN 1: HISTORIAL DE ENCUESTAS (Encuestas Pasadas/Cerradas)
  Widget _buildHistorialEncuestasView() {
    return FutureBuilder<List<StudentSurvey>>(
      key: const ValueKey('historial_encuestas'),
      future: _historialEncuestasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final encuestas = snapshot.data ?? [];

        if (encuestas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.history_toggle_off,
                    size: 64,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay encuestas anteriores o finalizadas registradas en el historial.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _selectedFilter = 0),
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('Ver Encuestas Disponibles'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadAll(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: encuestas.length,
            itemBuilder: (context, idx) {
              final enc = encuestas[idx];
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              enc.cursoNombre,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'FINALIZADA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Fecha de Clase: ${enc.fechaClase}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Cerrada el: ${Formatters.dateTime(enc.fechaLimite)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: 20),

                      // Desglose de montos finales
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'Costo Total Insumos',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.currency(enc.costoTotalInsumos),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'Confirmadas',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${enc.totalConfirmados}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'Cuota Final',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.currency(enc.cuotaACancelar),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Estado de participación del alumno
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: enc.asistira == true
                              ? AppTheme.tertiary.withValues(alpha: 0.1)
                              : AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: enc.asistira == true
                                ? AppTheme.tertiary.withValues(alpha: 0.3)
                                : AppTheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              enc.asistira == true
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              size: 18,
                              color: enc.asistira == true
                                  ? AppTheme.successGreen
                                  : AppTheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                enc.respondio != true
                                    ? 'No participaste en esta encuesta'
                                    : (enc.asistira == true
                                        ? 'Asististe • Aporte: ${Formatters.currency(enc.cuotaACancelar)} (${enc.estadoPago?.toUpperCase() ?? "SIN PAGO"})'
                                        : 'Marcaste que no asistirías'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: enc.asistira == true
                                      ? AppTheme.successGreen
                                      : AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (enc.comprobanteUrl != null &&
                                enc.comprobanteUrl!.isNotEmpty)
                              InkWell(
                                onTap: () => _mostrarModalComprobante(
                                  context,
                                  url: enc.comprobanteUrl!,
                                  curso: enc.cursoNombre,
                                  fecha: enc.fechaClase,
                                  estadoPago: enc.estadoPago ?? 'pendiente',
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.receipt_long,
                                          size: 14, color: AppTheme.primary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Ver Capture',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// OPCIÓN 2: HISTORIAL DE PAGO (Historial de Pagos Realizados)
  Widget _buildHistorialPagosView() {
    return FutureBuilder<List<StudentPaymentRecord>>(
      key: const ValueKey('historial_pagos'),
      future: _historialPagosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final pagos = snapshot.data ?? [];

        if (pagos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No tienes pagos realizados registrados aún.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cuando confirmes asistencia a una clase práctica y subas tu comprobante de aporte para insumos, se mostrará aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _selectedFilter = 0),
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('Ir a Encuestas Disponibles'),
                  ),
                ],
              ),
            ),
          );
        }

        final verificados = pagos.where((p) => p.isVerificado).length;
        final pendientes = pagos.where((p) => p.isPendiente).length;

        return RefreshIndicator(
          onRefresh: () async => _loadAll(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Tarjeta Resumen Superior de Pagos
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCol(
                      label: 'Total Pagos',
                      value: '${pagos.length}',
                      color: AppTheme.primary,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppTheme.outlineVariant,
                    ),
                    _buildMetricCol(
                      label: 'Verificados',
                      value: '$verificados',
                      color: AppTheme.successGreen,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppTheme.outlineVariant,
                    ),
                    _buildMetricCol(
                      label: 'Pendientes',
                      value: '$pendientes',
                      color: AppTheme.warningOrange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Listado de Comprobantes y Aportes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),

              // Lista de Pagos Realizados
              ...pagos.map((pago) {
                Color statusBg;
                Color statusText;
                String statusLabel;
                IconData statusIcon;

                if (pago.isVerificado) {
                  statusBg = AppTheme.tertiary.withValues(alpha: 0.15);
                  statusText = AppTheme.successGreen;
                  statusLabel = 'VERIFICADO';
                  statusIcon = Icons.check_circle_outline;
                } else if (pago.isRechazado) {
                  statusBg = AppTheme.errorRed.withValues(alpha: 0.15);
                  statusText = AppTheme.errorRed;
                  statusLabel = 'RECHAZADO';
                  statusIcon = Icons.cancel_outlined;
                } else {
                  statusBg = AppTheme.warningOrange.withValues(alpha: 0.15);
                  statusText = AppTheme.warningOrange;
                  statusLabel = 'PENDIENTE';
                  statusIcon = Icons.hourglass_top_outlined;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encabezado del pago
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.school_outlined,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pago.cursoNombre,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.onSurface,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon,
                                      size: 13, color: statusText),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Monto y Fecha
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cuota Cancelada',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  Formatters.currency(pago.montoCancelado),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Clase Práctica',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pago.fechaClase,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        if (pago.comprobanteSubidoAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Comprobante cargado el: ${Formatters.dateTime(pago.comprobanteSubidoAt!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Acciones: Ver o Actualizar Comprobante
                        Row(
                          children: [
                            if (pago.comprobanteUrl != null &&
                                pago.comprobanteUrl!.isNotEmpty) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _mostrarModalComprobante(
                                    context,
                                    url: pago.comprobanteUrl!,
                                    curso: pago.cursoNombre,
                                    fecha: pago.fechaClase,
                                    estadoPago: pago.estadoPago,
                                  ),
                                  icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 16),
                                  label: const Text('Ver Comprobante'),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (!pago.isVerificado)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: pago.comprobanteUrl != null
                                        ? AppTheme.surfaceContainerHighest
                                        : AppTheme.primary,
                                    foregroundColor: pago.comprobanteUrl != null
                                        ? AppTheme.onSurface
                                        : AppTheme.onPrimary,
                                  ),
                                  onPressed: _isUploading
                                      ? null
                                      : () => _mostrarSelectorComprobante(
                                          pago.encuestaId),
                                  icon: Icon(
                                    pago.comprobanteUrl != null
                                        ? Icons.sync
                                        : Icons.upload_file,
                                    size: 16,
                                  ),
                                  label: Text(
                                    pago.comprobanteUrl != null
                                        ? 'Actualizar Capture'
                                        : 'Subir Capture',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCol({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
