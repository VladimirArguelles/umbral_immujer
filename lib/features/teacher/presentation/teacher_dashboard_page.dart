import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/src/core/widgets/formation_image_carousel.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';
import 'package:umbral_immujer/src/core/widgets/super_admin_nav_bar.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';
import 'package:umbral_immujer/features/profile/presentation/profile_header_actions.dart';
import 'package:umbral_immujer/features/profile/presentation/profile_modal.dart';

class TeacherDashboardPage extends StatefulWidget {
  final UserProfile profile;
  final int initialIndex;
  const TeacherDashboardPage({
    super.key,
    required this.profile,
    this.initialIndex = 0,
  });

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  late int _currentIndex;
  late final TeacherRepository _teacherRepository;
  late UserProfile _currentProfile;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
    _currentIndex = widget.initialIndex.clamp(0, 4);
    _teacherRepository = TeacherRepository(SupabaseConfig.client);
  }

  Widget _buildDropdownNav(bool isSuperAdmin) {
    const tabTitles = [
      'Inicio',
      'Asistencia',
      'Encuestas',
      'Recaudación',
      'Alumnos',
    ];
    const tabIcons = [
      Icons.dashboard_rounded,
      Icons.playlist_add_check_circle_rounded,
      Icons.add_chart_rounded,
      Icons.payments_rounded,
      Icons.people_alt_rounded,
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: AppTheme.dynamicCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.dynamicBorder),
          ),
        ),
      ),
      child: PopupMenuButton<dynamic>(
        tooltip: 'Menú de opciones y navegación',
        offset: const Offset(0, 48),
        onSelected: (value) async {
          if (value is int) {
            setState(() => _currentIndex = value);
          } else if (value == 'profile') {
            final updated = await ProfileModal.show(
              context,
              profile: _currentProfile,
              onProfileUpdated: (p) => setState(() => _currentProfile = p),
            );
            if (updated != null) {
              setState(() => _currentProfile = updated);
            }
          } else if (value == 'toggle_theme') {
            ThemeController.toggleTheme();
          } else if (value is String) {
            context.go(value);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.dynamicBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tabIcons[_currentIndex],
                size: 15,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 75),
                child: Text(
                  tabTitles[_currentIndex],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dynamicText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: AppTheme.dynamicTextMuted,
              ),
            ],
          ),
        ),
        itemBuilder: (context) => [
          const PopupMenuItem<dynamic>(
            enabled: false,
            child: Text(
              'OPCIONES DE DOCENTE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (int i = 0; i < tabTitles.length; i++)
            PopupMenuItem<dynamic>(
              value: i,
              child: Row(
                children: [
                  Icon(
                    tabIcons[i],
                    size: 18,
                    color: _currentIndex == i
                        ? AppTheme.primary
                        : AppTheme.dynamicTextMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tabTitles[i],
                    style: TextStyle(
                      fontWeight: _currentIndex == i
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _currentIndex == i
                          ? AppTheme.primary
                          : AppTheme.dynamicText,
                    ),
                  ),
                  if (_currentIndex == i) ...[
                    const Spacer(),
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem<dynamic>(
            value: 'profile',
            child: Row(
              children: [
                const Icon(Icons.person_rounded, size: 18, color: AppTheme.mintNeon),
                const SizedBox(width: 10),
                Text('Mi Perfil', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
          PopupMenuItem<dynamic>(
            value: 'toggle_theme',
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.themeMode,
              builder: (context, mode, _) {
                final isDark = mode == ThemeMode.dark;
                return Row(
                  children: [
                    Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isDark ? 'Modo Claro' : 'Modo Nocturno',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                );
              },
            ),
          ),
          if (isSuperAdmin) ...[
            const PopupMenuDivider(),
            const PopupMenuItem<dynamic>(
              enabled: false,
              child: Text(
                'NAVEGACIÓN SUPER ADMIN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const PopupMenuItem<dynamic>(
              value: '/student',
              child: Row(
                children: [
                  Icon(Icons.school_outlined, size: 18, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Text('Módulo Alumnos'),
                ],
              ),
            ),
            const PopupMenuItem<dynamic>(
              value: '/coordinator',
              child: Row(
                children: [
                  Icon(Icons.military_tech_outlined, size: 18, color: AppTheme.tertiary),
                  SizedBox(width: 10),
                  Text('Módulo Coordinación'),
                ],
              ),
            ),
            const PopupMenuItem<dynamic>(
              value: '/superadmin',
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 18, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Text('Centro de Control Super Admin'),
                ],
              ),
            ),
            const PopupMenuItem<dynamic>(
              value: '/superadmin/configuracion',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 18, color: AppTheme.outline),
                  SizedBox(width: 10),
                  Text('Ajustes y Configuración'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleBackNavigation() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    } else if (widget.profile.role == UserRole.superAdmin) {
      context.go('/superadmin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = widget.profile.role == UserRole.superAdmin;

    final tabs = [
      _TeacherSummaryTab(
        teacherName: widget.profile.fullName,
        isSuperAdmin: isSuperAdmin,
        onNavigate: (idx) => setState(() => _currentIndex = idx),
      ),
      _PaseListaTab(teacherRepository: _teacherRepository, isSuperAdmin: isSuperAdmin),
      _EncuestasDocenteTab(teacherRepository: _teacherRepository, isSuperAdmin: isSuperAdmin, profile: _currentProfile),
      _AuditoriaRecaudacionTab(teacherRepository: _teacherRepository, isSuperAdmin: isSuperAdmin),
      _GestionAlumnosTab(
        teacherRepository: _teacherRepository,
        isSuperAdmin: isSuperAdmin,
        teacherName: widget.profile.fullName,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: (isSuperAdmin || _currentIndex != 0)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: _currentIndex != 0
                      ? 'Regresar al inicio del módulo'
                      : 'Volver a Super Admin',
                  onPressed: _handleBackNavigation,
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Módulo Docente',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.primary,
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'SUPER ADMIN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                _currentProfile.fullName,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            _buildDropdownNav(isSuperAdmin),
            const ThemeModeToggleButton(),
            UserProfileAvatarButton(
              profile: _currentProfile,
              onProfileUpdated: (updated) => setState(() => _currentProfile = updated),
            ),
          ],
        ),
        body: tabs[_currentIndex],
        bottomNavigationBar: isSuperAdmin
            ? const SuperAdminBottomNavBar(currentIndex: 2)
            : null,
      ),
    );
  }
}

/// -------------------------------------------------------------

/// -------------------------------------------------------------
/// TAB 0: PANTALLA INICIAL / RESUMEN DEL MÓDULO PROFESOR
/// -------------------------------------------------------------
class _TeacherSummaryTab extends StatelessWidget {
  final String teacherName;
  final bool isSuperAdmin;
  final ValueChanged<int> onNavigate;

  const _TeacherSummaryTab({
    required this.teacherName,
    required this.isSuperAdmin,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.dynamicBackground,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school, color: AppTheme.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, $teacherName',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSuperAdmin
                          ? 'Supervisión de docencia, asistencias y planeación'
                          : 'Panel de gestión académica y control de clases',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FormationImageCarousel(),
          const SizedBox(height: 16),
          Text(
            'HERRAMIENTAS DEL MÓDULO',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.outline,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _TeacherActionCard(
            title: 'PASE DE ASISTENCIA',
            description: 'Toma asistencia diaria de alumnos, visualiza asistencias y confirmaciones.',
            icon: Icons.playlist_add_check_circle_rounded,
            accent: AppTheme.primary,
            actionLabel: 'IR A ASISTENCIA',
            onTap: () => onNavigate(1),
          ),
          const SizedBox(height: 12),
          _TeacherActionCard(
            title: 'CREAR ENCUESTA',
            description: 'Configura encuestas previas para estimar insumos y confirmar participación.',
            icon: Icons.add_chart_rounded,
            accent: AppTheme.secondary,
            actionLabel: 'IR A ENCUESTAS',
            onTap: () => onNavigate(2),
          ),
          const SizedBox(height: 12),
          _TeacherActionCard(
            title: 'AUDITORÍA DE RECAUDACIÓN',
            description: 'Monitorea comprobantes de aportes y saldo de insumos por clase.',
            icon: Icons.payments_rounded,
            accent: AppTheme.tertiary,
            actionLabel: 'IR A RECAUDACIÓN',
            onTap: () => onNavigate(3),
          ),
          const SizedBox(height: 12),
          _TeacherActionCard(
            title: 'GESTIÓN DE ALUMNOS',
            description: 'Listado de alumnos matriculados, temas de clase y solicitudes.',
            icon: Icons.people_alt_rounded,
            accent: AppTheme.successGreen,
            actionLabel: 'IR A GESTIÓN DE ALUMNOS',
            onTap: () => onNavigate(4),
          ),
          if (isSuperAdmin) ...[
            const SizedBox(height: 12),
            _TeacherActionCard(
              title: 'GESTIÓN DE PLANTEL DOCENTE',
              description: 'Administración institucional de profesores, registro y asignación de cursos.',
              icon: Icons.badge_rounded,
              accent: AppTheme.primaryContainer,
              textColor: AppTheme.onPrimaryContainer,
              actionLabel: 'GESTIÓN DE PROFESORES',
              onTap: () => context.go('/superadmin/profesores'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeacherActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final Color? textColor;
  final String actionLabel;
  final VoidCallback onTap;

  const _TeacherActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    this.textColor,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dynamicBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark ? 0.06 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicTextMuted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: textColor ?? AppTheme.pureWhite,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// TAB 1: PASE DE ASISTENCIA (Individual + Lote 'Todos Presentes')
/// -------------------------------------------------------------
class _PaseListaTab extends StatefulWidget {
  final TeacherRepository teacherRepository;
  final bool isSuperAdmin;
  const _PaseListaTab({
    required this.teacherRepository,
    this.isSuperAdmin = false,
  });

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
    final cursos = await widget.teacherRepository.getMyCourses(isSuperAdmin: widget.isSuperAdmin);
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
      return const AttendanceSkeleton();
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
          color: AppTheme.dynamicCard,
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
/// TAB 2: GESTIÓN Y HISTORIAL DE ENCUESTAS DE INSUMOS
/// -------------------------------------------------------------
class _EncuestasDocenteTab extends StatefulWidget {
  final TeacherRepository teacherRepository;
  final bool isSuperAdmin;
  final UserProfile? profile;
  const _EncuestasDocenteTab({
    required this.teacherRepository,
    this.isSuperAdmin = false,
    this.profile,
  });

  @override
  State<_EncuestasDocenteTab> createState() => _EncuestasDocenteTabState();
}

class _EncuestasDocenteTabState extends State<_EncuestasDocenteTab> {
  int _selectedFilter = 0; // 0 = Encuestas Activas, 1 = Historial de Encuestas
  bool _isLoading = false;
  List<TeacherSurvey> _activeSurveys = [];
  List<TeacherSurvey> _historySurveys = [];
  List<TeacherCourse> _cursos = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final courses = await widget.teacherRepository.getMyCourses(isSuperAdmin: widget.isSuperAdmin);
      final actives = await widget.teacherRepository.getTeacherSurveys(
        activeOnly: true,
        isSuperAdmin: widget.isSuperAdmin,
      );
      final history = await widget.teacherRepository.getTeacherSurveys(
        activeOnly: false,
        isSuperAdmin: widget.isSuperAdmin,
      );

      if (!mounted) return;
      setState(() {
        _cursos = courses;
        _activeSurveys = actives;
        _historySurveys = history;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _mostrarCrearEncuestaDialog() async {
    if (_cursos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes cursos activos para asignar una encuesta.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final rateInfo = await widget.teacherRepository.getLatestBcvRateInfo();
    if (!mounted) return;

    TeacherCourse selectedCourse = _cursos.first;
    final costoCtrl = TextEditingController();
    DateTime fechaClase = DateTime.now().add(const Duration(days: 3));
    DateTime fechaLimite = DateTime.now().add(const Duration(days: 2));
    final cedulaPagoCtrl = TextEditingController(text: widget.profile?.cedula ?? '');
    final telefonoPagoCtrl = TextEditingController(text: widget.profile?.telefono ?? '');
    String? bancoSeleccionado = 'Banco de Venezuela (0102)';
    final customBancoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Nueva Encuesta de Insumos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Crea una encuesta para que los alumnos confirmen su asistencia y el presupuesto se prorratee automáticamente.',
                        style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),

                      // Selector de Curso
                      DropdownButtonFormField<TeacherCourse>(
                        isExpanded: true,
                        initialValue: selectedCourse,
                        decoration: const InputDecoration(
                          labelText: 'Curso / Asignatura',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: _cursos
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.nombre, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedCourse = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Costo Total
                      TextFormField(
                        controller: costoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Presupuesto Total de Insumos (USD)',
                          prefixIcon: Icon(Icons.attach_money),
                          hintText: 'Ej. 35.00',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          final numVal = double.tryParse(v.trim());
                          if (numVal == null || numVal <= 0) return 'Monto inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBright,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.mintNeon.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.currency_exchange, size: 15, color: AppTheme.mintNeon),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tasa BCV oficial (Fecha Valor${rateInfo.fechaValor != null ? ": ${rateInfo.fechaValor}" : ""}): Bs. ${rateInfo.tasa.toStringAsFixed(2)} / USD',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.mintNeon,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Fecha Práctica
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: AppTheme.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: AppTheme.surfaceBright,
                        leading: const Icon(Icons.event, color: AppTheme.primary),
                        title: const Text('Fecha de la Práctica', style: TextStyle(fontSize: 13)),
                        subtitle: Text(Formatters.date(fechaClase), style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.edit_calendar_rounded, size: 18),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: fechaClase,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (d != null) setModalState(() => fechaClase = d);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Fecha y Hora Límite
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: AppTheme.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: AppTheme.surfaceBright,
                        leading: const Icon(Icons.timer, color: AppTheme.secondary),
                        title: const Text('Fecha y Hora Límite', style: TextStyle(fontSize: 13)),
                        subtitle: Text(Formatters.dateTime(fechaLimite), style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.edit_calendar_rounded, size: 18),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: fechaLimite,
                            firstDate: DateTime.now(),
                            lastDate: fechaClase,
                          );
                          if (d != null && context.mounted) {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(fechaLimite),
                            );
                            if (t != null) {
                              setModalState(() {
                                fechaLimite = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                              });
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Sección Datos de Pago Móvil para Depósito
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBright,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.phone_android_rounded, size: 18, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Datos de Pago Móvil para Depósito de Alumnos',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Los alumnos verán estos datos para realizar su transferencia o pago móvil de insumos.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Cédula de Identidad
                            TextFormField(
                              controller: cedulaPagoCtrl,
                              keyboardType: TextInputType.text,
                              decoration: const InputDecoration(
                                labelText: 'Cédula de Identidad del Titular',
                                prefixIcon: Icon(Icons.badge_outlined),
                                hintText: 'Ej. V-12345678',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Por favor ingresa la cédula para el Pago Móvil';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            // Teléfono
                            TextFormField(
                              controller: telefonoPagoCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Número de Teléfono Pago Móvil',
                                prefixIcon: Icon(Icons.phone_outlined),
                                hintText: 'Ej. 0414-1234567',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Por favor ingresa el teléfono para el Pago Móvil';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            // Banco
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: bancoSeleccionado,
                              decoration: const InputDecoration(
                                labelText: 'Banco Destino',
                                prefixIcon: Icon(Icons.account_balance_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Banco de Venezuela (0102)', child: Text('Banco de Venezuela (0102)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Banesco (0134)', child: Text('Banesco (0134)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Mercantil (0105)', child: Text('Mercantil (0105)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'BBVA Provincial (0108)', child: Text('BBVA Provincial (0108)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Banco Nacional de Crédito BNC (0191)', child: Text('Banco Nacional de Crédito BNC (0191)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Bancaribe (0114)', child: Text('Bancaribe (0114)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Banco Exterior (0115)', child: Text('Banco Exterior (0115)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Banco Bicentenario (0175)', child: Text('Banco Bicentenario (0175)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Bancamiga (0172)', child: Text('Bancamiga (0172)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Banplus (0174)', child: Text('Banplus (0174)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: '100% Banco (0156)', child: Text('100% Banco (0156)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Otro Banco', child: Text('Otro Banco', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => bancoSeleccionado = val);
                                }
                              },
                            ),
                            if (bancoSeleccionado == 'Otro Banco') ...[
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: customBancoCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre del Banco',
                                  prefixIcon: Icon(Icons.account_balance),
                                  hintText: 'Ej. Banco Activo',
                                ),
                                validator: (v) {
                                  if (bancoSeleccionado == 'Otro Banco' && (v == null || v.trim().isEmpty)) {
                                    return 'Ingresa el nombre del banco';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSubmitting = true);
                                final costo = double.parse(costoCtrl.text.trim());
                                final bancoFinal = bancoSeleccionado == 'Otro Banco'
                                    ? customBancoCtrl.text.trim()
                                    : (bancoSeleccionado ?? '');
                                try {
                                  await widget.teacherRepository.createSurvey(
                                    courseId: selectedCourse.id,
                                    classDate: Formatters.isoDate(fechaClase),
                                    totalSupplyCost: costo,
                                    deadline: fechaLimite,
                                    pagoMovilCedula: cedulaPagoCtrl.text.trim(),
                                    pagoMovilTelefono: telefonoPagoCtrl.text.trim(),
                                    pagoMovilBanco: bancoFinal,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('¡Encuesta creada con éxito!'),
                                        backgroundColor: AppTheme.successGreen,
                                      ),
                                    );
                                  }
                                  _loadAll();
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error al crear encuesta: $e'),
                                        backgroundColor: AppTheme.errorRed,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: AppTheme.onSurface, strokeWidth: 2),
                              )
                            : const Text('Publicar Encuesta a los Alumnos'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirGestionEncuesta(TeacherSurvey survey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gestión de Encuesta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          survey.cursoNombre,
                          style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Opción 1: Modificar Presupuesto y Plazos
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppTheme.outlineVariant),
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: AppTheme.surfaceBright,
                leading: const Icon(Icons.edit_note_rounded, color: AppTheme.mintNeon, size: 26),
                title: const Text('Modificar Presupuesto y Fechas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text(
                  'Ajusta el monto en USD, fecha de práctica o fecha límite con recálculo automático.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  _mostrarEditarEncuestaDialog(survey);
                },
              ),
              const SizedBox(height: 12),

              // Opción 2: Auditoría y Pagos de Alumnos
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppTheme.outlineVariant),
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: AppTheme.surfaceBright,
                leading: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 26),
                title: const Text('Auditoría de Pagos y Confirmaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: Text(
                  '${survey.totalConfirmados} alumnos confirmados. Revisa y aprueba comprobantes.',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  _mostrarAuditoriaPagosDialog(survey);
                },
              ),
              const SizedBox(height: 12),

              // Opción 3: Finalizar / Cerrar Encuesta
              ListTile(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: AppTheme.surfaceBright,
                leading: const Icon(Icons.lock_clock_rounded, color: AppTheme.errorRed, size: 26),
                title: const Text('Finalizar Encuesta (Mover al Historial)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.errorRed)),
                subtitle: const Text(
                  'Cierra la encuesta para no recibir más respuestas de alumnos.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20, color: AppTheme.errorRed),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmarCerrarEncuesta(survey);
                },
              ),
              const SizedBox(height: 12),

              // Opción 4: Eliminar Encuesta
              ListTile(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: AppTheme.surfaceBright,
                leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.errorRed, size: 26),
                title: const Text('Eliminar Encuesta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.errorRed)),
                subtitle: const Text(
                  'Borra permanentemente la encuesta y los registros vinculados.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20, color: AppTheme.errorRed),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmarEliminarEncuesta(survey);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _mostrarEditarEncuestaDialog(TeacherSurvey survey) async {
    final rateInfo = await widget.teacherRepository.getLatestBcvRateInfo();
    if (!mounted) return;

    final costoCtrl = TextEditingController(text: survey.costoTotalInsumos.toStringAsFixed(2));
    DateTime fechaClase = DateTime.tryParse(survey.fechaClase) ?? DateTime.now().add(const Duration(days: 3));
    DateTime fechaLimite = survey.fechaLimite;
    final cedulaPagoCtrl = TextEditingController(text: survey.pagoMovilCedula ?? widget.profile?.cedula ?? '');
    final telefonoPagoCtrl = TextEditingController(text: survey.pagoMovilTelefono ?? widget.profile?.telefono ?? '');
    String? bancoSeleccionado = survey.pagoMovilBanco != null && survey.pagoMovilBanco!.isNotEmpty
        ? survey.pagoMovilBanco!
        : 'Banco de Venezuela (0102)';
    final customBancoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Editar Encuesta • ${survey.cursoNombre}', style: const TextStyle(fontSize: 16)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: costoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Presupuesto Total (USD)',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          final val = double.tryParse(v.trim());
                          if (val == null || val <= 0) return 'Monto inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBright,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.mintNeon.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.currency_exchange, size: 15, color: AppTheme.mintNeon),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tasa BCV oficial (Fecha Valor${rateInfo.fechaValor != null ? ": ${rateInfo.fechaValor}" : ""}): Bs. ${rateInfo.tasa.toStringAsFixed(2)} / USD',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.mintNeon,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: AppTheme.outlineVariant),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        tileColor: AppTheme.surfaceBright,
                        leading: const Icon(Icons.event, color: AppTheme.primary, size: 20),
                        title: const Text('Fecha de Práctica', style: TextStyle(fontSize: 12)),
                        subtitle: Text(Formatters.date(fechaClase), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        trailing: const Icon(Icons.edit_calendar_rounded, size: 16),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: fechaClase,
                            firstDate: DateTime.now().subtract(const Duration(days: 7)),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (d != null) setDialogState(() => fechaClase = d);
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: AppTheme.outlineVariant),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        tileColor: AppTheme.surfaceBright,
                        leading: const Icon(Icons.timer, color: AppTheme.secondary, size: 20),
                        title: const Text('Fecha Límite', style: TextStyle(fontSize: 12)),
                        subtitle: Text(Formatters.dateTime(fechaLimite), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        trailing: const Icon(Icons.edit_calendar_rounded, size: 16),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: fechaLimite,
                            firstDate: DateTime.now().subtract(const Duration(days: 7)),
                            lastDate: fechaClase,
                          );
                          if (d != null && context.mounted) {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(fechaLimite),
                            );
                            if (t != null) {
                              setDialogState(() {
                                fechaLimite = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                              });
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Datos de Pago Móvil
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBright,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.phone_android_rounded, size: 16, color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Pago Móvil del Docente',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: cedulaPagoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cédula de Identidad',
                                prefixIcon: Icon(Icons.badge_outlined, size: 18),
                                hintText: 'Ej. V-12345678',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: telefonoPagoCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono Pago Móvil',
                                prefixIcon: Icon(Icons.phone_outlined, size: 18),
                                hintText: 'Ej. 0414-1234567',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: [
                                'Banco de Venezuela (0102)',
                                'Banesco (0134)',
                                'Mercantil (0105)',
                                'BBVA Provincial (0108)',
                                'Banco Nacional de Crédito BNC (0191)',
                                'Bancaribe (0114)',
                                'Banco Exterior (0115)',
                                'Banco Bicentenario (0175)',
                                'Bancamiga (0172)',
                                'Banplus (0174)',
                                '100% Banco (0156)',
                                'Otro Banco',
                              ].contains(bancoSeleccionado) ? bancoSeleccionado : 'Otro Banco',
                              decoration: const InputDecoration(
                                labelText: 'Banco Destino',
                                prefixIcon: Icon(Icons.account_balance_outlined, size: 18),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Banco de Venezuela (0102)', child: Text('Banco de Venezuela (0102)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Banesco (0134)', child: Text('Banesco (0134)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Mercantil (0105)', child: Text('Mercantil (0105)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'BBVA Provincial (0108)', child: Text('BBVA Provincial (0108)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Banco Nacional de Crédito BNC (0191)', child: Text('Banco Nacional de Crédito BNC (0191)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Bancaribe (0114)', child: Text('Bancaribe (0114)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Banco Exterior (0115)', child: Text('Banco Exterior (0115)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Banco Bicentenario (0175)', child: Text('Banco Bicentenario (0175)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Bancamiga (0172)', child: Text('Bancamiga (0172)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Banplus (0174)', child: Text('Banplus (0174)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: '100% Banco (0156)', child: Text('100% Banco (0156)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Otro Banco', child: Text('Otro Banco', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => bancoSeleccionado = val);
                                }
                              },
                            ),
                            if (bancoSeleccionado == 'Otro Banco') ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: customBancoCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre del Banco',
                                  prefixIcon: Icon(Icons.account_balance, size: 18),
                                ),
                                validator: (v) => (bancoSeleccionado == 'Otro Banco' && (v == null || v.trim().isEmpty)) ? 'Requerido' : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);
                          final costo = double.parse(costoCtrl.text.trim());
                          final bancoFinal = bancoSeleccionado == 'Otro Banco'
                              ? customBancoCtrl.text.trim()
                              : (bancoSeleccionado ?? '');
                          try {
                            await widget.teacherRepository.updateSurveyDetails(
                              surveyId: survey.id,
                              totalSupplyCost: costo,
                              classDate: Formatters.isoDate(fechaClase),
                              deadline: fechaLimite,
                              pagoMovilCedula: cedulaPagoCtrl.text.trim(),
                              pagoMovilTelefono: telefonoPagoCtrl.text.trim(),
                              pagoMovilBanco: bancoFinal,
                            );
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('¡Encuesta actualizada y cuota recalculada exitosamente!'),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                            }
                            _loadAll();
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al actualizar: $e'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmarCerrarEncuesta(TeacherSurvey survey) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('¿Finalizar Encuesta?'),
          content: Text(
            'La encuesta para "${survey.cursoNombre}" pasará al Historial de Encuestas y los alumnos ya no podrán registrar ni cambiar respuestas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Volver'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await widget.teacherRepository.updateSurveyStatus(
                    surveyId: survey.id,
                    status: 'cerrada',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Encuesta finalizada y movida al historial.'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  }
                  _loadAll();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
                    );
                  }
                }
              },
              child: const Text('Finalizar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmarEliminarEncuesta(TeacherSurvey survey) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.delete_forever_rounded, color: AppTheme.errorRed, size: 24),
              SizedBox(width: 8),
              Text('¿Eliminar Encuesta?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar permanentemente la encuesta para "${survey.cursoNombre}"? Se borrarán también las respuestas de los alumnos asociados.',
            style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: AppTheme.pureWhite,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await widget.teacherRepository.deleteSurvey(survey.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Encuesta eliminada correctamente.'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  }
                  _loadAll();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppTheme.errorRed),
                    );
                  }
                }
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarAuditoriaPagosDialog(TeacherSurvey survey) async {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: FutureBuilder<List<PaymentAuditItem>>(
              future: widget.teacherRepository.getSurveyPayments(survey.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snapshot.data ?? [];
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auditoría de Pagos • ${survey.cursoNombre}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${items.length} alumnos confirmaron asistencia',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      if (items.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Aún no hay alumnos confirmados en esta encuesta.',
                              style: TextStyle(color: AppTheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final item = items[i];
                              final isVerificado = item.estadoPago == 'verificado';
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceBright,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.outlineVariant),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.nombreCompleto,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isVerificado
                                                ? AppTheme.successGreen.withValues(alpha: 0.15)
                                                : AppTheme.errorRed.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            item.estadoPago.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isVerificado ? AppTheme.successGreen : AppTheme.errorRed,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text.rich(
                                      TextSpan(
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppTheme.onSurfaceVariant,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Cédula: ${item.cedula} • Cuota: Bs. ',
                                          ),
                                          TextSpan(
                                            text: item.monto.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: AppTheme.successGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (item.comprobanteUrl != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.receipt_rounded, size: 14),
                                            label: const Text('Ver Comprobante', style: TextStyle(fontSize: 11)),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            onPressed: () => _verComprobanteDialog(item.comprobanteUrl!),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!isVerificado)
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.successGreen,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              onPressed: () async {
                                                await widget.teacherRepository.updatePaymentStatus(
                                                  responseId: item.respuestaId,
                                                  status: 'verificado',
                                                );
                                                if (ctx.mounted) {
                                                  Navigator.pop(ctx);
                                                  _mostrarAuditoriaPagosDialog(survey);
                                                }
                                              },
                                              child: const Text('Aprobar', style: TextStyle(fontSize: 11)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _verComprobanteDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Comprobante de Pago'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, prog) =>
                    prog == null ? child : const Center(child: CircularProgressIndicator()),
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No se pudo cargar la imagen del comprobante.'),
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
    return Column(
      children: [
        _buildFilterSelector(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAll,
            child: _isLoading && _activeSurveys.isEmpty && _historySurveys.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _selectedFilter == 0
                        ? _buildActiveSurveysView()
                        : _buildHistorySurveysView(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: AppTheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: AppTheme.primary),
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
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Nueva Encuesta', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  foregroundColor: AppTheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _mostrarCrearEncuestaDialog,
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
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
                dropdownColor: AppTheme.surfaceBright,
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem<int>(
                    value: 0,
                    child: Row(
                      children: [
                        Icon(Icons.assignment_turned_in_rounded, size: 18, color: AppTheme.mintNeon),
                        SizedBox(width: 10),
                        Text(
                          'Encuestas Activas',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem<int>(
                    value: 1,
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, size: 18, color: AppTheme.secondary),
                        SizedBox(width: 10),
                        Text(
                          'Historial de Encuestas',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFilter = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSurveysView() {
    if (_activeSurveys.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_late_outlined, size: 56, color: AppTheme.onSurfaceVariant),
              const SizedBox(height: 14),
              const Text(
                'No tienes encuestas activas actualmente',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Publica una nueva encuesta para estimar y prorratear insumos con tus alumnos.',
                style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_chart_rounded, size: 18),
                label: const Text('Crear Encuesta de Insumos'),
                onPressed: _mostrarCrearEncuestaDialog,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeSurveys.length,
      itemBuilder: (context, index) {
        final survey = _activeSurveys[index];
        final fechaClaseDate = DateTime.tryParse(survey.fechaClase);
        final fechaClaseStr = fechaClaseDate != null ? Formatters.date(fechaClaseDate) : survey.fechaClase;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: survey.hasExpired ? AppTheme.dynamicBorder : AppTheme.mintNeon.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.mintNeon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: AppTheme.mintNeon, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'APORTE PARA COMPRA DE INSUMOS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.mintNeon,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          survey.cursoNombre,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.dynamicText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: survey.hasExpired
                              ? AppTheme.errorRed.withValues(alpha: 0.15)
                              : AppTheme.successGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          survey.hasExpired ? 'Vencida' : 'Activa',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: survey.hasExpired ? AppTheme.errorRed : AppTheme.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Fechas
              Row(
                children: [
                  const Icon(Icons.event_available_rounded, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text('Práctica: $fechaClaseStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  const Icon(Icons.timer_outlined, size: 14, color: AppTheme.secondary),
                  const SizedBox(width: 6),
                  Text('Límite: ${Formatters.dateTime(survey.fechaLimite)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 14),

              // Bloque de Montos
              const Text(
                'Monto del aporte individual a cancelar:',
                style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                survey.totalConfirmados > 0
                    ? 'Bs. ${(survey.montoIndividualCalculado * (survey.tasaBcvUsada ?? 1.0)).toStringAsFixed(2)} Bs.'
                    : 'Pendiente de cálculo',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mintNeon,
                ),
              ),
              if (survey.totalConfirmados > 0)
                Text(
                  '~ \$${survey.montoIndividualCalculado.toStringAsFixed(2)} USD por alumno',
                  style: const TextStyle(fontSize: 12, color: AppTheme.successGreen),
                ),
              const SizedBox(height: 10),

              // Presupuesto y Confirmados
              Row(
                children: [
                  const Icon(Icons.assignment_outlined, size: 14, color: AppTheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Presupuesto: \$${survey.costoTotalInsumos.toStringAsFixed(2)} USD',
                    style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${survey.totalConfirmados} confirmados',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Tasa BCV Oficial
              if (survey.tasaBcvUsada != null && survey.tasaBcvUsada! > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.currency_exchange, size: 13, color: AppTheme.mintNeon),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Tasa BCV (Fecha Valor): Bs. ${survey.tasaBcvUsada!.toStringAsFixed(2)} / USD',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.mintNeon,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // BOTÓN PARA GESTIONAR LA ENCUESTA Y PAPELERA
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text(
                        'Gestionar Encuesta',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryContainer,
                        foregroundColor: AppTheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _abrirGestionEncuesta(survey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 22),
                      tooltip: 'Eliminar Encuesta',
                      onPressed: () => _confirmarEliminarEncuesta(survey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistorySurveysView() {
    if (_historySurveys.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off_rounded, size: 56, color: AppTheme.onSurfaceVariant),
              SizedBox(height: 14),
              Text(
                'No hay encuestas en el historial',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
              ),
              SizedBox(height: 6),
              Text(
                'Las encuestas cerradas o finalizadas aparecerán archivadas aquí.',
                style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historySurveys.length,
      itemBuilder: (context, index) {
        final survey = _historySurveys[index];
        final fechaClaseDate = DateTime.tryParse(survey.fechaClase);
        final fechaClaseStr = fechaClaseDate != null ? Formatters.date(fechaClaseDate) : survey.fechaClase;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.dynamicBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      survey.cursoNombre,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.dynamicText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.dynamicSurfaceHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      survey.estado.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.dynamicTextMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Práctica: $fechaClaseStr • Presupuesto: \$${survey.costoTotalInsumos.toStringAsFixed(2)} USD', style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  children: [
                    TextSpan(
                      text: 'Confirmados: ${survey.totalConfirmados} alumnos • Cuota final: \$',
                    ),
                    TextSpan(
                      text: survey.montoIndividualCalculado.toStringAsFixed(2),
                      style: const TextStyle(color: AppTheme.successGreen),
                    ),
                    const TextSpan(text: ' USD'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('Ver Pagos y Comprobantes', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _mostrarAuditoriaPagosDialog(survey),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// -------------------------------------------------------------
/// TAB 3: AUDITORÍA DE RECAUDACIÓN Y CONTROL DE PAGOS
/// -------------------------------------------------------------
class _AuditoriaRecaudacionTab extends StatefulWidget {
  final TeacherRepository teacherRepository;
  final bool isSuperAdmin;
  const _AuditoriaRecaudacionTab({
    required this.teacherRepository,
    this.isSuperAdmin = false,
  });

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
        .from('encuestas_participacion')
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
              ? const SurveysSkeleton()
              : _recaudacion.isEmpty
              ? const Center(
                  child: Text(
                    'Aún no hay respuestas de alumnos confirmados para esta práctica.',
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
                                    color: AppTheme.successGreen,
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
  final bool isSuperAdmin;
  final String teacherName;
  const _GestionAlumnosTab({
    required this.teacherRepository,
    this.isSuperAdmin = false,
    required this.teacherName,
  });

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
    final cursos = await widget.teacherRepository.getMyCourses(isSuperAdmin: widget.isSuperAdmin);
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
    final hist = await widget.teacherRepository.getCourseStudentHistory(cursoId);
    if (!mounted) return;
    setState(() {
      _historialAlumnos = hist;
      _isLoading = false;
    });
  }

  // ─── Modal para Añadir Nuevo Alumno (+) ────────────────────────────────────
  void _showAddAlumnoModal() {
    if (_selectedCurso == null) return;
    final nombreCtrl = TextEditingController();
    final cedulaCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Añadir Nuevo Alumno', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Sujeto a aprobación de Coordinación', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre y Apellido *', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre completo' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cedulaCtrl,
                    decoration: const InputDecoration(labelText: 'Cédula de Identidad *', prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la cédula' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telefonoCtrl,
                    decoration: const InputDecoration(labelText: 'Teléfono (Opcional)', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: correoCtrl,
                    decoration: const InputDecoration(labelText: 'Correo (Opcional)', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'La solicitud quedará en estado pendiente y se aplicará tras ser aprobada por Coordinación.',
                            style: TextStyle(fontSize: 10.5, color: AppTheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => isSaving = true);
                      try {
                        await widget.teacherRepository.createApprovalRequest(
                          courseId: _selectedCurso!.id,
                          courseName: _selectedCurso!.nombre,
                          requestType: 'crear_alumno',
                          teacherName: widget.teacherName,
                          newValues: {
                            'nombre_completo': nombreCtrl.text.trim(),
                            'cedula': cedulaCtrl.text.trim(),
                            'telefono': telefonoCtrl.text.trim(),
                            'correo': correoCtrl.text.trim(),
                          },
                          reason: 'Incorporación de alumno por el docente',
                        );
                        if (!context.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Solicitud de alumno enviada a Coordinación. Quedará activa al ser aprobada.'),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      } catch (e) {
                        setModalState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
                        );
                      }
                    },
              icon: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.pureWhite))
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('Enviar a Coordinación'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Modal para Gestionar Alumno (Editar datos y Eliminar con Guardar cambios) ─
  void _showGestionAlumnoModal(ArchivedStudentEnrollment al) {
    if (_selectedCurso == null) return;
    final nombreCtrl = TextEditingController(text: al.nombreCompleto);
    final cedulaCtrl = TextEditingController(text: al.cedula);
    final motivoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sbContext, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gestión de Alumno',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'Curso: ${_selectedCurso!.nombre}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre Completo *', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cedulaCtrl,
                    decoration: const InputDecoration(labelText: 'Cédula de Identidad *', prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: motivoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motivo del cambio (Opcional)',
                      hintText: 'Ej. Corrección de datos o desincorporación',
                      prefixIcon: Icon(Icons.comment_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.tertiary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: AppTheme.tertiary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Regla de negocio: Toda acción de modificación o eliminación queda en estado pendiente y no surtirá efecto hasta recibir la aprobación de Coordinación.',
                            style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Botón Guardar cambios
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSaving = true);
                              try {
                                await widget.teacherRepository.createApprovalRequest(
                                  courseId: _selectedCurso!.id,
                                  courseName: _selectedCurso!.nombre,
                                  requestType: 'editar_alumno',
                                  teacherName: widget.teacherName,
                                  oldValues: {
                                    'alumno_id': al.alumnoId,
                                    'nombre_completo': al.nombreCompleto,
                                    'cedula': al.cedula,
                                  },
                                  newValues: {
                                    'alumno_id': al.alumnoId,
                                    'nombre_completo': nombreCtrl.text.trim(),
                                    'cedula': cedulaCtrl.text.trim(),
                                  },
                                  reason: motivoCtrl.text.trim().isNotEmpty ? motivoCtrl.text.trim() : null,
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Modificación enviada a Coordinación. Quedará en estado pendiente.'),
                                    backgroundColor: AppTheme.successGreen,
                                  ),
                                );
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
                                  );
                                }
                              }
                            },
                      icon: isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.pureWhite))
                          : const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Botón Eliminar / Solicitar Desincorporación
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('¿Solicitar Desincorporación?'),
                                  content: Text('¿Deseas enviar a Coordinación la solicitud para desincorporar a ${al.nombreCompleto}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Sí, Solicitar'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              setModalState(() => isSaving = true);
                              try {
                                await widget.teacherRepository.createApprovalRequest(
                                  courseId: _selectedCurso!.id,
                                  courseName: _selectedCurso!.nombre,
                                  requestType: 'eliminar_alumno',
                                  teacherName: widget.teacherName,
                                  newValues: {
                                    'alumno_id': al.alumnoId,
                                    'nombre_completo': al.nombreCompleto,
                                  },
                                  reason: motivoCtrl.text.trim().isNotEmpty ? motivoCtrl.text.trim() : 'Desincorporación solicitada por el docente',
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Solicitud de desincorporación enviada a Coordinación.'),
                                    backgroundColor: AppTheme.tertiary,
                                  ),
                                );
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.person_remove_outlined, size: 18),
                      label: const Text('Solicitar Desincorporación / Eliminar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Modal para Gestión de Temas del Curso ────────────────────────────────
  void _showGestionTemasModal() async {
    if (_selectedCurso == null) return;
    List<String> temas = [];
    bool loadingTemas = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (loadingTemas) {
            widget.teacherRepository.getCourseTemas(_selectedCurso!.id).then((list) {
              setDialogState(() {
                temas = list;
                loadingTemas = false;
              });
            }).catchError((_) {
              setDialogState(() => loadingTemas = false);
            });
          }

          return AlertDialog(
            backgroundColor: AppTheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.topic_rounded, color: AppTheme.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gestión de Temas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(_selectedCurso!.nombre, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                  tooltip: 'Proponer nuevo tema',
                  onPressed: () => _proponerNuevoTema(ctx, () {
                    loadingTemas = true;
                    setDialogState(() {});
                  }),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: loadingTemas
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  : temas.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No hay temas registrados en este curso aún.'),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: temas.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tema = temas[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: AppTheme.secondary.withValues(alpha: 0.2),
                                child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                              ),
                              title: Text(tema, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Editar tema',
                                    onPressed: () => _proponerEditarTema(ctx, tema, () {
                                      loadingTemas = true;
                                      setDialogState(() {});
                                    }),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                                    tooltip: 'Eliminar tema',
                                    onPressed: () => _proponerEliminarTema(ctx, tema, () {
                                      loadingTemas = true;
                                      setDialogState(() {});
                                    }),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _proponerNuevoTema(BuildContext parentCtx, VoidCallback onReload) {
    final ctrl = TextEditingController();
    showDialog(
      context: parentCtx,
      builder: (c) => AlertDialog(
        title: const Text('Añadir Tema'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Título del tema *', hintText: 'Ej. Introducción a Técnicas de Repostería'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isEmpty) return;
              Navigator.pop(c);
              try {
                await widget.teacherRepository.createApprovalRequest(
                  courseId: _selectedCurso!.id,
                  courseName: _selectedCurso!.nombre,
                  requestType: 'crear_tema',
                  teacherName: widget.teacherName,
                  newValues: {'tema': val},
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Solicitud de tema enviada a Coordinación para aprobación.')),
                );
                onReload();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Enviar a Coordinación'),
          ),
        ],
      ),
    );
  }

  void _proponerEditarTema(BuildContext parentCtx, String oldTema, VoidCallback onReload) {
    final ctrl = TextEditingController(text: oldTema);
    showDialog(
      context: parentCtx,
      builder: (c) => AlertDialog(
        title: const Text('Editar Tema'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nuevo título del tema *'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isEmpty || val == oldTema) return;
              Navigator.pop(c);
              try {
                await widget.teacherRepository.createApprovalRequest(
                  courseId: _selectedCurso!.id,
                  courseName: _selectedCurso!.nombre,
                  requestType: 'editar_tema',
                  teacherName: widget.teacherName,
                  oldValues: {'tema': oldTema},
                  newValues: {'tema': val},
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modificación de tema enviada a Coordinación para aprobación.')),
                );
                onReload();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Enviar a Coordinación'),
          ),
        ],
      ),
    );
  }

  void _proponerEliminarTema(BuildContext parentCtx, String tema, VoidCallback onReload) {
    showDialog(
      context: parentCtx,
      builder: (c) => AlertDialog(
        title: const Text('¿Eliminar Tema?'),
        content: Text('¿Deseas enviar a Coordinación la solicitud para eliminar el tema "$tema"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(c);
              try {
                await widget.teacherRepository.createApprovalRequest(
                  courseId: _selectedCurso!.id,
                  courseName: _selectedCurso!.nombre,
                  requestType: 'eliminar_tema',
                  teacherName: widget.teacherName,
                  newValues: {'tema': tema},
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Solicitud de eliminación de tema enviada a Coordinación.')),
                );
                onReload();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Solicitar Eliminación'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<TeacherCourse>(
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
              const SizedBox(height: 12),
              // Botones de Acción: Añadir Alumno (+) y Gestión de Temas
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _showAddAlumnoModal,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Añadir Alumno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.secondary,
                        side: const BorderSide(color: AppTheme.secondary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _showGestionTemasModal,
                      icon: const Icon(Icons.topic_outlined, size: 18),
                      label: const Text('Gestión Temas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Regla institucional banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.pending_actions_rounded, size: 16, color: AppTheme.secondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Regla de negocio: Toda acción de modificación (alumnos y temas) queda en estado pendiente y no surte efecto hasta recibir aprobación de Coordinación.',
                  style: TextStyle(fontSize: 10.5, color: AppTheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? const AttendanceSkeleton()
              : _historialAlumnos.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No hay alumnos inscritos en este curso.')))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.tune_rounded,
                                color: AppTheme.primary,
                              ),
                              tooltip: 'Gestionar datos del alumno (Editar / Eliminar)',
                              onPressed: () => _showGestionAlumnoModal(al),
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