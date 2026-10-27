import 'dart:io';

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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('UMBRAL • Alumna/o', style: TextStyle(fontSize: 16)),
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
      body: tabs[_currentIndex],
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
          unselectedLabelColor: Colors.black54,
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
                style: const TextStyle(color: Colors.black54),
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
                                color: AppTheme.primaryDark,
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
                                  ? const Color(0x26388E3C)
                                  : const Color(0x33000000),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              c.estado.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActivo
                                    ? AppTheme.successGreen
                                    : Colors.black54,
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
                            color: Colors.black87,
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
  bool _isLoading = true;

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
    if (mounted) {
      setState(() => _resumen = resumen);
    }
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
              initialValue: _selectedCurso,
              decoration: const InputDecoration(
                labelText: 'Selecciona el Curso',
                prefixIcon: Icon(Icons.class_outlined),
              ),
              items: _misCursos.map((c) {
                return DropdownMenuItem(value: c, child: Text(c.nombre));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCurso = val);
                  _loadAsistenciasCurso(val.id);
                }
              },
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
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59D32F2F),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
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
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Inasistencias registradas: ${resumen.inasistencias}. Te recomendamos comunicarte con tu docente o coordinación de IMMUJER para evitar comprometer tu certificación.',
                            style: const TextStyle(
                              color: Colors.white,
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
                    color: AppTheme.successGreen,
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
              const Text(
                'Registro Detallado por Clase',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 10),

              if (resumen.historial.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: Text(
                        'Aún no se han registrado asistencias para este curso.',
                      ),
                    ),
                  ),
                )
              else
                ...resumen.historial.map((reg) {
                  final esPresente = reg.estado.toLowerCase() == 'presente';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: esPresente
                            ? const Color(0x26388E3C)
                            : const Color(0x26D32F2F),
                        child: Icon(
                          esPresente ? Icons.check : Icons.close,
                          color: esPresente
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                        ),
                      ),
                      title: Text(
                        'Fecha: ${reg.fecha}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: esPresente
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          reg.estado.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
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
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------
/// TAB 3: ENCUESTAS Y APORTES (Confirmación + Comprobante)
/// -------------------------------------------------------------
class _EncuestasAportesTab extends StatefulWidget {
  final StudentRepository studentRepository;
  const _EncuestasAportesTab({required this.studentRepository});

  @override
  State<_EncuestasAportesTab> createState() => _EncuestasAportesTabState();
}

class _EncuestasAportesTabState extends State<_EncuestasAportesTab> {
  late Future<List<StudentSurvey>> _encuestasFuture;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadEncuestas();
  }

  void _loadEncuestas() {
    setState(() {
      _encuestasFuture = widget.studentRepository.getActiveSurveys();
    });
  }

  Future<void> _responder(StudentSurvey enc, bool asistira) async {
    try {
      await widget.studentRepository.respondToSurvey(
        surveyId: enc.id,
        willAttend: asistira,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              asistira
                  ? '¡Participación confirmada!'
                  : 'Respuesta registrada: No asistirás.',
            ),
            backgroundColor: asistira ? AppTheme.successGreen : Colors.black87,
          ),
        );
        _loadEncuestas();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _seleccionarYSubirComprobante(
    StudentSurvey enc,
    ImageSource source,
  ) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      await widget.studentRepository.uploadPaymentProof(
        surveyId: enc.id,
        imageFile: File(picked.path),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Comprobante subido exitosamente! En espera de verificación docente.',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _loadEncuestas();
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

  void _mostrarSelectorComprobante(StudentSurvey enc) {
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
                _seleccionarYSubirComprobante(enc, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppTheme.secondary,
              ),
              title: const Text('Seleccionar de la Galería'),
              onTap: () {
                Navigator.of(ctx).pop();
                _seleccionarYSubirComprobante(enc, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudentSurvey>>(
      future: _encuestasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final encuestas = snapshot.data ?? [];
        if (encuestas.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.black26,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No hay encuestas de insumos activas en este momento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadEncuestas(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: encuestas.length,
            itemBuilder: (context, idx) {
              final enc = encuestas[idx];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado de Encuesta
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              enc.cursoNombre,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: enc.estaVencida
                                  ? const Color(0x1AD32F2F)
                                  : const Color(0x1A388E3C),
                              borderRadius: BorderRadius.circular(10),
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
                      const SizedBox(height: 8),
                      Text(
                        'Fecha de Clase Práctica: ${enc.fechaClase}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Límite de Confirmación: ${Formatters.dateTime(enc.fechaLimite)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const Divider(height: 24),

                      // Montos y Cálculos Dinámicos
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'Presupuesto Total',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.currency(enc.costoTotalInsumos),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'Confirmados',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${enc.totalConfirmados}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'Tu Aporte Aprox.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                enc.montoIndividual > 0
                                    ? Formatters.currency(enc.montoIndividual)
                                    : r'$0.00',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // PREGUNTA DE CONFIRMACIÓN
                      if (enc.respondio != true) ...[
                        const Text(
                          '¿Asistirás a la próxima clase y compartirás el costo de insumos?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: enc.estaVencida
                                    ? null
                                    : () => _responder(enc, false),
                                child: const Text('No Asistiré'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: enc.estaVencida
                                    ? null
                                    : () => _responder(enc, true),
                                child: const Text('Confirmar Asistencia'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: enc.asistira == true
                                ? const Color(0x1A388E3C)
                                : const Color(0x1A000000),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                enc.asistira == true
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: enc.asistira == true
                                    ? AppTheme.successGreen
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  enc.asistira == true
                                      ? 'Has confirmado que ASISTIRÁS a esta clase'
                                      : 'Has indicado que NO ASISTIRÁS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: enc.asistira == true
                                        ? AppTheme.successGreen
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // SUBIR COMPROBANTE DE PAGO
                        if (enc.asistira == true) ...[
                          if (enc.comprobanteUrl == null ||
                              enc.comprobanteUrl!.isEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x1FF57C00),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.warningOrange,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppTheme.warningOrange,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Capture pendiente: Recuerda adjuntar la imagen de tu pago para que el profesor verifique tu aporte.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.warningOrange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondary,
                              ),
                              onPressed: _isUploading
                                  ? null
                                  : () => _mostrarSelectorComprobante(enc),
                              icon: const Icon(Icons.upload_file),
                              label: _isUploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Subir Comprobante de Pago'),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Comprobante enviado',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: enc.estadoPago == 'verificado'
                                        ? const Color(0x26388E3C)
                                        : const Color(0x26F57C00),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    enc.estadoPago?.toUpperCase() ??
                                        'PENDIENTE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: enc.estadoPago == 'verificado'
                                          ? AppTheme.successGreen
                                          : AppTheme.warningOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
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
