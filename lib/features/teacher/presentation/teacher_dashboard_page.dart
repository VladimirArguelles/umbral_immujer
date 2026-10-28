import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class TeacherDashboardPage extends StatefulWidget {
  final UserProfile profile;
  const TeacherDashboardPage({super.key, required this.profile});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  int _currentIndex = 0;
  late final TeacherRepository _teacherRepository;

  @override
  void initState() {
    super.initState();
    _teacherRepository = TeacherRepository(SupabaseConfig.client);
  }

  void _handleSignOut() async {
    await SupabaseConfig.client.auth.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _PaseListaTab(teacherRepository: _teacherRepository),
      _CrearEncuestaTab(teacherRepository: _teacherRepository),
      _AuditoriaRecaudacionTab(teacherRepository: _teacherRepository),
      _GestionAlumnosTab(teacherRepository: _teacherRepository),
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
              isSuperAdmin ? 'UMBRAL • Docente (Super Admin)' : 'UMBRAL • Docente',
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
                      'Modo Super Admin • Módulo Profesores',
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
            icon: Icon(Icons.playlist_add_check_circle_outlined),
            selectedIcon: Icon(Icons.playlist_add_check_circle),
            label: 'Asistencia',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_chart_outlined),
            selectedIcon: Icon(Icons.add_chart),
            label: 'Crear Encuesta',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Recaudación',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'Alumnos & Papelera',
          ),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------
/// TAB 1: PASE DE ASISTENCIA (Individual + Lote 'Todos Presentes')
/// -------------------------------------------------------------
class _PaseListaTab extends StatefulWidget {
  final TeacherRepository teacherRepository;
  const _PaseListaTab({required this.teacherRepository});

  @override
  State<_PaseListaTab> createState() => _PaseListaTabState();
}

class _PaseListaTabState extends State<_PaseListaTab> {
  List<TeacherCourse> _cursos = [];
  TeacherCourse? _selectedCurso;
  final String _fechaSeleccionada = Formatters.isoDate(DateTime.now());
  List<StudentAttendanceItem> _alumnos = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCursos();
  }

  void _loadCursos() async {
    setState(() => _isLoading = true);
    final cursos = await widget.teacherRepository.getMyCourses();
    if (!mounted) return;
    setState(() {
      _cursos = cursos;
      if (cursos.isNotEmpty) {
        _selectedCurso = cursos.first;
      }
      _isLoading = false;
    });
    if (_selectedCurso != null) {
      _loadAlumnosParaLista(_selectedCurso!.id);
    }
  }

  void _loadAlumnosParaLista(String cursoId) async {
    setState(() => _isLoading = true);
    final lista = await widget.teacherRepository.getStudentsForAttendance(
      courseId: cursoId,
      date: _fechaSeleccionada,
    );
    if (!mounted) return;
    setState(() {
      _alumnos = lista;
      _isLoading = false;
    });
  }

  void _marcarTodosComoPresentes() {
    setState(() {
      for (final a in _alumnos) {
        a.estadoAsistencia = 'Presente';
      }
    });
  }

  void _toggleAsistencia(StudentAttendanceItem alumno) {
    setState(() {
      alumno.estadoAsistencia = alumno.isPresente ? 'Ausente' : 'Presente';
    });
  }

  Future<void> _guardarAsistencia() async {
    if (_selectedCurso == null) return;
    setState(() => _isSaving = true);
    try {
      await widget.teacherRepository.saveAttendance(
        courseId: _selectedCurso!.id,
        date: _fechaSeleccionada,
        students: _alumnos,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Asistencia sincronizada y guardada exitosamente!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar asistencia: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _cursos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cursos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No tienes cursos asignados actualmente. Contacta al coordinador de IMMUJER.',
          ),
        ),
      );
    }

    final presentesCount = _alumnos.where((a) => a.isPresente).length;
    final ausentesCount = _alumnos.where((a) => !a.isPresente).length;

    return Column(
      children: [
        // Panel de Control Superior
        Container(
          padding: const EdgeInsets.all(16.0),
          color: AppTheme.surfaceContainerLow,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TeacherCourse>(
                      isExpanded: true,
                      initialValue: _selectedCurso,
                      decoration: const InputDecoration(
                        labelText: 'Curso',
                        prefixIcon: Icon(Icons.class_outlined),
                      ),
                      selectedItemBuilder: (BuildContext context) {
                        return _cursos.map((c) {
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
                      items: _cursos
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c.nombre,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCurso = val);
                          _loadAlumnosParaLista(val.id);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.today,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _fechaSeleccionada,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Botón de Acción en Lote y Métricas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Presentes: $presentesCount | Ausentes: $ausentesCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _alumnos.isEmpty
                        ? null
                        : _marcarTodosComoPresentes,
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text(
                      'Todos Presentes',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Lista de Alumnos para Asistencia
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _alumnos.isEmpty
              ? const Center(
                  child: Text('No hay alumnos inscritos en este curso.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _alumnos.length,
                  itemBuilder: (context, idx) {
                    final a = _alumnos[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: a.isPresente
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                          child: Icon(
                            a.isPresente ? Icons.check : Icons.close,
                            color: AppTheme.onTertiary,
                          ),
                        ),
                        title: Text(
                          a.nombreCompleto,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'C.I: ${a.cedula} • Tel: ${a.telefono ?? "N/A"}',
                            ),
                            if (a.confirmoEncuesta == true) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Encuesta: Confirmó asistencia (${a.estadoPago ?? "Sin pago"})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Switch(
                          value: a.isPresente,
                          activeThumbColor: AppTheme.successGreen,
                          inactiveThumbColor: AppTheme.errorRed,
                          onChanged: (_) => _toggleAsistencia(a),
                        ),
                        onTap: () => _toggleAsistencia(a),
                      ),
                    );
                  },
                ),
        ),

        // Botón Inferior para Guardar Lista
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceContainerLow,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _guardarAsistencia,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: AppTheme.onSurface,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('Confirmar y Guardar Asistencia'),
            ),
          ),
        ),
      ],
    );
  }
}

/// -------------------------------------------------------------
/// TAB 2: CREACIÓN DE ENCUESTA DE INSUMOS
/// -------------------------------------------------------------
class _CrearEncuestaTab extends StatefulWidget {
  final TeacherRepository teacherRepository;
  const _CrearEncuestaTab({required this.teacherRepository});

  @override
  State<_CrearEncuestaTab> createState() => _CrearEncuestaTabState();
}

class _CrearEncuestaTabState extends State<_CrearEncuestaTab> {
  final _formKey = GlobalKey<FormState>();
  List<TeacherCourse> _cursos = [];
  TeacherCourse? _selectedCurso;
  final _costoController = TextEditingController();
  DateTime _fechaClase = DateTime.now().add(const Duration(days: 3));
  DateTime _fechaLimite = DateTime.now().add(const Duration(days: 2));
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCursos();
  }

  void _loadCursos() async {
    final cursos = await widget.teacherRepository.getMyCourses();
    if (!mounted) return;
    setState(() {
      _cursos = cursos;
      if (cursos.isNotEmpty) _selectedCurso = cursos.first;
    });
  }

  Future<void> _crearEncuesta() async {
    if (!_formKey.currentState!.validate() || _selectedCurso == null) return;

    final costo = double.tryParse(_costoController.text.trim()) ?? 0.0;
    if (costo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un monto de presupuesto válido'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.teacherRepository.createSurvey(
        courseId: _selectedCurso!.id,
        classDate: Formatters.isoDate(_fechaClase),
        totalSupplyCost: costo,
        deadline: _fechaLimite,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Encuesta creada con éxito! Disponible para las alumnas del curso.',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _costoController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear encuesta: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Programar Práctica y Presupuesto de Insumos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Crea una encuesta para que las alumnas confirmen su asistencia y el costo de los insumos se divida automáticamente.',
              style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // Selector de Curso
            DropdownButtonFormField<TeacherCourse>(
              isExpanded: true,
              initialValue: _selectedCurso,
              decoration: const InputDecoration(
                labelText: 'Curso / Asignatura',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              selectedItemBuilder: (BuildContext context) {
                return _cursos.map((c) {
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
              items: _cursos
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c.nombre,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedCurso = val),
            ),
            const SizedBox(height: 16),

            // Costo Total Insumos
            TextFormField(
              controller: _costoController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto Total del Presupuesto (USD)',
                prefixIcon: Icon(Icons.attach_money),
                hintText: 'Ej. 50.00',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),

            // Fecha de Clase
            ListTile(
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppTheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: AppTheme.surfaceContainerLow,
              leading: const Icon(Icons.event, color: AppTheme.primary),
              title: const Text('Fecha de la Práctica'),
              subtitle: Text(Formatters.date(_fechaClase)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _fechaClase,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (d != null) setState(() => _fechaClase = d);
              },
            ),
            const SizedBox(height: 16),

            // Fecha y Hora Límite
            ListTile(
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppTheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: AppTheme.surfaceContainerLow,
              leading: const Icon(Icons.timer, color: AppTheme.secondary),
              title: const Text('Fecha y Hora Límite para Responder'),
              subtitle: Text(Formatters.dateTime(_fechaLimite)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _fechaLimite,
                  firstDate: DateTime.now(),
                  lastDate: _fechaClase,
                );
                if (d != null && context.mounted) {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_fechaLimite),
                  );
                  if (t != null) {
                    setState(() {
                      _fechaLimite = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      );
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _isLoading ? null : _crearEncuesta,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppTheme.onSurface,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Publicar Encuesta a las Alumnas'),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------
/// TAB 3: AUDITORÍA DE RECAUDACIÓN Y CONTROL DE PAGOS
/// -------------------------------------------------------------
class _AuditoriaRecaudacionTab extends StatefulWidget {
  final TeacherRepository teacherRepository;
  const _AuditoriaRecaudacionTab({required this.teacherRepository});

  @override
  State<_AuditoriaRecaudacionTab> createState() =>
      _AuditoriaRecaudacionTabState();
}

class _AuditoriaRecaudacionTabState extends State<_AuditoriaRecaudacionTab> {
  List<Map<String, dynamic>> _encuestas = [];
  String? _selectedEncuestaId;
  List<PaymentAuditItem> _recaudacion = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEncuestasDocente();
  }

  void _loadEncuestasDocente() async {
    setState(() => _isLoading = true);
    final data = await SupabaseConfig.client
        .from('encuestas')
        .select(
          'id, fecha_clase, costo_total_insumos, monto_individual_calculado, total_confirmados, cursos(nombre)',
        )
        .order('fecha_clase', ascending: false);

    if (!mounted) return;
    setState(() {
      _encuestas = List<Map<String, dynamic>>.from(data as List);
      if (_encuestas.isNotEmpty) {
        _selectedEncuestaId = _encuestas.first['id'] as String;
      }
      _isLoading = false;
    });

    if (_selectedEncuestaId != null) {
      _loadRecaudacion(_selectedEncuestaId!);
    }
  }

  void _loadRecaudacion(String encuestaId) async {
    setState(() => _isLoading = true);
    final items = await widget.teacherRepository.getSurveyPayments(encuestaId);
    if (!mounted) return;
    setState(() {
      _recaudacion = items;
      _isLoading = false;
    });
  }

  Future<void> _cambiarEstadoPago(
    PaymentAuditItem item,
    String nuevoEstado,
  ) async {
    await widget.teacherRepository.updatePaymentStatus(
      responseId: item.respuestaId,
      status: nuevoEstado,
    );
    if (_selectedEncuestaId != null) {
      _loadRecaudacion(_selectedEncuestaId!);
    }
  }

  void _verComprobanteDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text(
                'Capture de Comprobante',
                style: TextStyle(fontSize: 16),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (c, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (c, error, stack) => const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No se pudo cargar la imagen del capture'),
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
    if (_isLoading && _encuestas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_encuestas.isEmpty) {
      return const Center(
        child: Text('No hay encuestas registradas para auditar.'),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceContainerLow,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedEncuestaId,
            decoration: const InputDecoration(
              labelText: 'Seleccionar Encuesta',
              prefixIcon: Icon(Icons.receipt_long),
            ),
            selectedItemBuilder: (BuildContext context) {
              return _encuestas.map((e) {
                final c = e['cursos'] as Map<String, dynamic>?;
                return Text(
                  '${c?['nombre'] ?? "Curso"} • Clase: ${e['fecha_clase']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              }).toList();
            },
            items: _encuestas.map((e) {
              final c = e['cursos'] as Map<String, dynamic>?;
              return DropdownMenuItem<String>(
                value: e['id'] as String,
                child: Text(
                  '${c?['nombre'] ?? "Curso"} • Clase: ${e['fecha_clase']}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedEncuestaId = val);
                _loadRecaudacion(val);
              }
            },
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _recaudacion.isEmpty
              ? const Center(
                  child: Text(
                    'Aún no hay respuestas de alumnas confirmadas para esta práctica.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recaudacion.length,
                  itemBuilder: (context, idx) {
                    final item = _recaudacion[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.nombreCompleto,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  Formatters.currency(item.monto),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'C.I: ${item.cedula}',
                              style: const TextStyle(
                                color: AppTheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                if (item.comprobanteUrl != null &&
                                    item.comprobanteUrl!.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: () => _verComprobanteDialog(
                                      item.comprobanteUrl!,
                                    ),
                                    icon: const Icon(Icons.image, size: 16),
                                    label: const Text(
                                      'Ver Capture',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  )
                                else
                                  const Text(
                                    'Capture pendiente',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.warningOrange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const Spacer(),

                                // Botones de Acción Verificación
                                if (item.estadoPago != 'verificado')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successGreen,
                                    ),
                                    onPressed: () =>
                                        _cambiarEstadoPago(item, 'verificado'),
                                    child: const Text(
                                      'Verificar',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.tertiary.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      'VERIFICADO',
                                      style: TextStyle(
                                        color: AppTheme.successGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
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
/// TAB 4: GESTIÓN DE ALUMNOS Y HISTORIAL / PAPELERA
/// -------------------------------------------------------------
class _GestionAlumnosTab extends StatefulWidget {
  final TeacherRepository teacherRepository;
  const _GestionAlumnosTab({required this.teacherRepository});

  @override
  State<_GestionAlumnosTab> createState() => _GestionAlumnosTabState();
}

class _GestionAlumnosTabState extends State<_GestionAlumnosTab> {
  List<TeacherCourse> _cursos = [];
  TeacherCourse? _selectedCurso;
  List<ArchivedStudentEnrollment> _historialAlumnos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCursos();
  }

  void _loadCursos() async {
    final cursos = await widget.teacherRepository.getMyCourses();
    if (!mounted) return;
    setState(() {
      _cursos = cursos;
      if (cursos.isNotEmpty) _selectedCurso = cursos.first;
    });
    if (_selectedCurso != null) {
      _loadHistorial(_selectedCurso!.id);
    }
  }

  void _loadHistorial(String cursoId) async {
    setState(() => _isLoading = true);
    final hist = await widget.teacherRepository.getCourseStudentHistory(
      cursoId,
    );
    if (!mounted) return;
    setState(() {
      _historialAlumnos = hist;
      _isLoading = false;
    });
  }

  Future<void> _retirarAlumno(ArchivedStudentEnrollment a) async {
    await widget.teacherRepository.withdrawStudent(
      enrollmentId: a.inscripcionId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${a.nombreCompleto} enviado a la papelera/retirado.'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _restaurarAlumno(a),
        ),
      ),
    );
    if (_selectedCurso != null) _loadHistorial(_selectedCurso!.id);
  }

  Future<void> _restaurarAlumno(ArchivedStudentEnrollment a) async {
    await widget.teacherRepository.restoreStudent(
      enrollmentId: a.inscripcionId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${a.nombreCompleto} restaurado al curso exitosamente.'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
    if (_selectedCurso != null) _loadHistorial(_selectedCurso!.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceContainerLow,
          child: DropdownButtonFormField<TeacherCourse>(
            isExpanded: true,
            initialValue: _selectedCurso,
            decoration: const InputDecoration(
              labelText: 'Curso',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            selectedItemBuilder: (BuildContext context) {
              return _cursos.map((c) {
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
            items: _cursos
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(
                      c.nombre,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedCurso = val);
                _loadHistorial(val.id);
              }
            },
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _historialAlumnos.length,
                  itemBuilder: (context, idx) {
                    final al = _historialAlumnos[idx];
                    final enPapelera = al.estaEliminado;

                    return Card(
                      color: enPapelera
                          ? AppTheme.surfaceContainerHigh
                          : AppTheme.surfaceContainerLow,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: enPapelera
                              ? AppTheme.onSurfaceVariant
                              : AppTheme.primary,
                          child: Icon(
                            enPapelera ? Icons.delete_outline : Icons.person,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        title: Text(
                          al.nombreCompleto,
                          style: TextStyle(
                            decoration: enPapelera
                                ? TextDecoration.lineThrough
                                : null,
                            color: enPapelera
                                ? AppTheme.onSurfaceVariant
                                : AppTheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'C.I: ${al.cedula} • Estado: ${enPapelera ? "En Papelera / Retirado" : "Activo"}',
                        ),
                        trailing: enPapelera
                            ? ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.successGreen,
                                ),
                                onPressed: () => _restaurarAlumno(al),
                                icon: const Icon(Icons.restore, size: 16),
                                label: const Text(
                                  'Restablecer',
                                  style: TextStyle(fontSize: 12),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.errorRed,
                                ),
                                tooltip: 'Eliminar del curso',
                                onPressed: () => _retirarAlumno(al),
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
