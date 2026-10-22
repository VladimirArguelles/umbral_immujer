import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/src/features/coordinadores/data/coordinadores_repository.dart';
import 'package:umbral_immujer/src/features/coordinadores/domain/coordinador_models.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';
import 'package:umbral_immujer/src/features/auth/presentation/login_screen.dart';

class CoordinadorHomeScreen extends StatefulWidget {
  final UserProfile profile;
  const CoordinadorHomeScreen({super.key, required this.profile});

  @override
  State<CoordinadorHomeScreen> createState() => _CoordinadorHomeScreenState();
}

class _CoordinadorHomeScreenState extends State<CoordinadorHomeScreen> {
  int _currentIndex = 0;
  late final CoordinadoresRepository _coordRepo;

  @override
  void initState() {
    super.initState();
    _coordRepo = CoordinadoresRepository(SupabaseConfig.client);
  }

  void _handleSignOut() async {
    await SupabaseConfig.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _DashboardCursosTab(coordRepo: _coordRepo),
      _MonitorRealtimeAusenciasTab(coordRepo: _coordRepo),
      _AsignacionProfesoresTab(coordRepo: _coordRepo),
      _AuditoriaInsumosTab(coordRepo: _coordRepo),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('UMBRAL • Coordinación General', style: TextStyle(fontSize: 16)),
            Text(widget.profile.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
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
            label: 'Cursos',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors),
            label: 'En Vivo',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'Profesores',
          ),
          NavigationDestination(
            icon: Icon(Icons.monetization_on_outlined),
            selectedIcon: Icon(Icons.monetization_on),
            label: 'Insumos',
          ),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------
/// TAB 1: DASHBOARD DE CURSOS Y ESTADÍSTICAS
/// -------------------------------------------------------------
class _DashboardCursosTab extends StatefulWidget {
  final CoordinadoresRepository coordRepo;
  const _DashboardCursosTab({required this.coordRepo});

  @override
  State<_DashboardCursosTab> createState() => _DashboardCursosTabState();
}

class _DashboardCursosTabState extends State<_DashboardCursosTab> {
  late Future<List<DashboardCurso>> _dashboardFuture;
  final String _fechaHoy = Formatters.isoDate(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  void _loadDashboard() {
    setState(() {
      _dashboardFuture = widget.coordRepo.getCursosDashboard(_fechaHoy);
    });
  }

  void _mostrarDialogoReasignar(DashboardCurso curso) async {
    final profesores = await widget.coordRepo.getProfesoresRegistrados();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Asignar Profesor a ${curso.nombre}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (curso.profesorId != null)
                ListTile(
                  leading: const Icon(Icons.person_remove, color: AppTheme.errorRed),
                  title: const Text('Dejar sin profesor asignado'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await widget.coordRepo.desasignarProfesor(cursoId: curso.id);
                    _loadDashboard();
                  },
                ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: profesores.length,
                  itemBuilder: (c, idx) {
                    final p = profesores[idx];
                    final esActual = p.id == curso.profesorId;
                    return ListTile(
                      leading: CircleAvatar(child: Text(p.nombreCompleto.substring(0, 1))),
                      title: Text(p.nombreCompleto),
                      subtitle: Text('C.I: ${p.cedula} ${p.cursoActual != null ? "• Imparte: ${p.cursoActual}" : ""}'),
                      trailing: esActual ? const Icon(Icons.check, color: AppTheme.successGreen) : null,
                      onTap: esActual
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              await widget.coordRepo.asignarProfesorACurso(cursoId: curso.id, profesorId: p.id);
                              _loadDashboard();
                            },
                    );
                  },
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
    return FutureBuilder<List<DashboardCurso>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final cursos = snapshot.data ?? [];
        if (cursos.isEmpty) {
          return const Center(child: Text('No hay cursos activos registrados.'));
        }

        return RefreshIndicator(
          onRefresh: () async => _loadDashboard(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cursos.length,
            itemBuilder: (context, idx) {
              final c = cursos[idx];
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
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
                            tooltip: 'Reasignar Profesor',
                            onPressed: () => _mostrarDialogoReasignar(c),
                          ),
                        ],
                      ),
                      if (c.horario != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 14, color: AppTheme.secondary),
                            const SizedBox(width: 6),
                            Text(c.horario!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person_pin, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Docente: ${c.profesorNombre ?? "Sin asignar"}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Indicadores
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('${c.alumnosInscritos}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                              const Text('Inscritos', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${c.ausenciasHoy}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: c.ausenciasHoy > 0 ? AppTheme.errorRed : AppTheme.successGreen,
                                ),
                              ),
                              const Text('Ausencias Hoy', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            ],
                          ),
                        ],
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
}

/// -------------------------------------------------------------
/// TAB 2: MONITOREO EN TIEMPO REAL DE ASISTENCIAS (SUPABASE REALTIME)
/// -------------------------------------------------------------
class _MonitorRealtimeAusenciasTab extends StatefulWidget {
  final CoordinadoresRepository coordRepo;
  const _MonitorRealtimeAusenciasTab({required this.coordRepo});

  @override
  State<_MonitorRealtimeAusenciasTab> createState() => _MonitorRealtimeAusenciasTabState();
}

class _MonitorRealtimeAusenciasTabState extends State<_MonitorRealtimeAusenciasTab> {
  final String _fechaHoy = Formatters.isoDate(DateTime.now());
  List<AusenciaTiempoReal> _ausencias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAusencias();
    _suscribirRealtime();
  }

  void _loadAusencias() async {
    final list = await widget.coordRepo.getDetalleAusenciasHoy(_fechaHoy);
    if (mounted) {
      setState(() {
        _ausencias = list;
        _isLoading = false;
      });
    }
  }

  void _suscribirRealtime() {
    // Al recibir cambios en la tabla asistencias para hoy, recargar de inmediato
    widget.coordRepo.streamAsistenciasHoy(_fechaHoy).listen((_) {
      _loadAusencias();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Banner Informativo de Supabase Realtime
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0x1AD32F2F),
          child: Row(
            children: [
              const Icon(Icons.circle, color: AppTheme.errorRed, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Monitor en Vivo: Ausencias detectadas hoy ($_fechaHoy): ${_ausencias.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorRed, fontSize: 13),
                ),
              ),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.errorRed),
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _ausencias.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 54, color: AppTheme.successGreen),
                          SizedBox(height: 12),
                          Text('No se registran ausencias en la jornada de hoy.'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _ausencias.length,
                      itemBuilder: (context, idx) {
                        final aus = _ausencias[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: AppTheme.errorRed, width: 1.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppTheme.errorRed,
                              child: Icon(Icons.person_off, color: Colors.white),
                            ),
                            title: Text(aus.alumnoNombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Curso: ${aus.cursoNombre}'),
                                Text('C.I: ${aus.cedula} • ${aus.horaMarcada != null ? Formatters.dateTime(aus.horaMarcada!) : ""}'),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('AUSENTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

/// -------------------------------------------------------------
/// TAB 3: GESTIÓN Y REASIGNACIÓN DE PROFESORES
/// -------------------------------------------------------------
class _AsignacionProfesoresTab extends StatefulWidget {
  final CoordinadoresRepository coordRepo;
  const _AsignacionProfesoresTab({required this.coordRepo});

  @override
  State<_AsignacionProfesoresTab> createState() => _AsignacionProfesoresTabState();
}

class _AsignacionProfesoresTabState extends State<_AsignacionProfesoresTab> {
  late Future<List<ProfesorDisponible>> _profesoresFuture;

  @override
  void initState() {
    super.initState();
    _loadProfesores();
  }

  void _loadProfesores() {
    setState(() {
      _profesoresFuture = widget.coordRepo.getProfesoresRegistrados();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProfesorDisponible>>(
      future: _profesoresFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final profs = snapshot.data ?? [];
        if (profs.isEmpty) {
          return const Center(child: Text('No hay docentes con cuenta activa registrados.'));
        }

        return RefreshIndicator(
          onRefresh: () async => _loadProfesores(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: profs.length,
            itemBuilder: (context, idx) {
              final p = profs[idx];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: AppTheme.primary, child: Icon(Icons.school, color: Colors.white)),
                  title: Text(p.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('C.I: ${p.cedula} • ${p.telefono ?? "Sin teléfono"}\nCurso actual: ${p.cursoActual ?? "Disponible para asignación"}'),
                  isThreeLine: true,
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
/// TAB 4: AUDITORÍA DE ENCUESTAS E INSUMOS
/// -------------------------------------------------------------
class _AuditoriaInsumosTab extends StatelessWidget {
  final CoordinadoresRepository coordRepo;
  const _AuditoriaInsumosTab({required this.coordRepo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AuditoriaEncuesta>>(
      future: coordRepo.getAuditoriaEncuestas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final encuestas = snapshot.data ?? [];
        if (encuestas.isEmpty) {
          return const Center(child: Text('No hay encuestas de insumos registradas.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: encuestas.length,
          itemBuilder: (context, idx) {
            final e = encuestas[idx];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(e.cursoNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        Text('Fecha: ${e.fechaClase}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Presupuesto Total', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            Text(Formatters.currency(e.costoTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Confirmados', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            Text('${e.totalConfirmados}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Cuota por Alumna', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            Text(
                              Formatters.currency(e.montoIndividual),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
