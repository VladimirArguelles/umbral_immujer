import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class SuperAdminDashboardPage extends StatelessWidget {
  const SuperAdminDashboardPage({super.key, this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return SuperAdminDashboard(profile: profile);
  }
}

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key, this.profile});

  final UserProfile? profile;

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _currentIndex = 0;

  // Telemetría en vivo
  int? _totalAlumnos;
  int? _totalCursos;
  int? _totalProfesores;
  int? _totalCoordinadores;
  int? _totalUsuarios;
  int? _totalAsistencias;
  int? _totalPresentes;
  bool _isLoadingMetrics = true;
  Object? _metricsError;

  // Ajustes de configuración
  String _platformName = 'UMBRAL IMMUJER';
  String _activeCycle = '2024-B';
  bool _rlsEnabled = true;
  bool _notificationsEnabled = true;
  bool _maintenanceMode = false;

  // Constantes de diseño según especificación Tailwind
  static const Color cBg = AppTheme.background;
  static const Color cOuterBg = AppTheme.surfaceContainerLowest;
  static const Color cCard = AppTheme.surfaceContainerLow;
  static const Color cCardInner = AppTheme.surfaceContainer;
  static const Color cBorder = AppTheme.outlineVariant;
  static const Color cAccent = AppTheme.primaryContainer;
  static const Color cAccentGlow = Color(0x59FF516A);
  static const Color cMintBright = AppTheme.tertiary;
  static const Color cTextMain = AppTheme.onSurface;
  static const Color cTextMuted = AppTheme.onSurfaceVariant;
  static const Color cTextDim = AppTheme.outline;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final client = SupabaseConfig.client;

      final futures = await Future.wait([
        client.from('alumnos').select('id').count(),
        client.from('cursos').select('id').eq('estado', 'activo').count(),
        client.from('profesores').select('id').count(),
        client.from('profiles').select('id').count(),
        client.from('profiles').select('id').eq('rol', 'coordinador').count(),
        client.from('asistencias').select('id').count(),
        client
            .from('asistencias')
            .select('id')
            .eq('estado', 'Presente')
            .count(),
      ]);

      if (mounted) {
        setState(() {
          _totalAlumnos = futures[0].count;
          _totalCursos = futures[1].count;
          _totalProfesores = futures[2].count;
          _totalUsuarios = futures[3].count;
          _totalCoordinadores = futures[4].count;
          _totalAsistencias = futures[5].count;
          _totalPresentes = futures[6].count;
          _isLoadingMetrics = false;
          _metricsError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingMetrics = false;
          _metricsError = error;
        });
      }
    }
  }

  double? get _attendanceRate {
    final total = _totalAsistencias;
    final present = _totalPresentes;
    if (total == null || present == null || total == 0) return null;
    return present / total;
  }

  Future<void> _handleSignOut() async {
    await SupabaseConfig.client.auth.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ajustes del Sistema',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: cTextMain,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: cTextMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _platformName,
                    style: const TextStyle(color: cTextMain),
                    decoration: InputDecoration(
                      labelText: 'Nombre de la Plataforma',
                      labelStyle: const TextStyle(color: cTextMuted),
                      filled: true,
                      fillColor: cCardInner,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: cBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: cBorder),
                      ),
                    ),
                    onChanged: (val) => _platformName = val,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _activeCycle,
                    dropdownColor: cCardInner,
                    style: const TextStyle(color: cTextMain),
                    decoration: InputDecoration(
                      labelText: 'Ciclo Académico Activo',
                      labelStyle: const TextStyle(color: cTextMuted),
                      filled: true,
                      fillColor: cCardInner,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: cBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: cBorder),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '2024-B',
                        child: Text('Ciclo 2024-B (Agosto - Diciembre)'),
                      ),
                      DropdownMenuItem(
                        value: '2025-A',
                        child: Text('Ciclo 2025-A (Enero - Junio)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _activeCycle = val);
                        setState(() => _activeCycle = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text(
                      'Políticas Institucionales y RLS',
                      style: TextStyle(
                        color: cTextMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Reglas de acceso por sede institucional y cifrado en reposo activo.',
                      style: TextStyle(color: cTextMuted, fontSize: 12),
                    ),
                    value: _rlsEnabled,
                    activeThumbColor: cAccent,
                    onChanged: (val) {
                      setModalState(() => _rlsEnabled = val);
                      setState(() => _rlsEnabled = val);
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Notificaciones Push y Alertas',
                      style: TextStyle(
                        color: cTextMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Avisos automáticos a facilitadores y alumnas por WhatsApp/Push.',
                      style: TextStyle(color: cTextMuted, fontSize: 12),
                    ),
                    value: _notificationsEnabled,
                    activeThumbColor: cAccent,
                    onChanged: (val) {
                      setModalState(() => _notificationsEnabled = val);
                      setState(() => _notificationsEnabled = val);
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Modo Mantenimiento',
                      style: TextStyle(
                        color: cTextMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Suspender temporalmente ingresos al portal de alumnas.',
                      style: TextStyle(color: cTextMuted, fontSize: 12),
                    ),
                    value: _maintenanceMode,
                    activeThumbColor: cAccent,
                    onChanged: (val) {
                      setModalState(() => _maintenanceMode = val);
                      setState(() => _maintenanceMode = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cAccent,
                        side: const BorderSide(color: cAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleSignOut();
                      },
                      icon: const Icon(Symbols.logout),
                      label: const Text('Cerrar Sesión'),
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

  void _showQuickAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Acción Rápida',
          style: GoogleFonts.plusJakartaSans(
            color: cTextMain,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.school, color: cAccent),
              title: const Text(
                'Nuevo Alumno',
                style: TextStyle(color: cTextMain),
              ),
              onTap: () {
                Navigator.pop(ctx);
                context.go('/student');
              },
            ),
            ListTile(
              leading: const Icon(Symbols.menu_book, color: cAccent),
              title: const Text(
                'Nuevo Curso/Taller',
                style: TextStyle(color: cTextMain),
              ),
              onTap: () {
                Navigator.pop(ctx);
                context.go('/coordinator');
              },
            ),
            ListTile(
              leading: const Icon(Symbols.badge, color: cAccent),
              title: const Text(
                'Nuevo Profesor',
                style: TextStyle(color: cTextMain),
              ),
              onTap: () {
                Navigator.pop(ctx);
                context.go('/teacher');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: cTextMuted)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme.copyWith(scaffoldBackgroundColor: cOuterBg),
      child: Scaffold(
        backgroundColor: cOuterBg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              color: cBg,
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 12,
                          bottom: 100,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderSection(),
                            const SizedBox(height: 20),
                            _buildKeyMetricsSection(),
                            const SizedBox(height: 20),
                            _buildManagementModulesSection(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: _buildBottomNavigationBar(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- BEGIN: HeaderSection ---
  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xD9181B24), // cCard.withValues(alpha: 0.85)
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Color(0xB3252936),
        ), // cBorder.withValues(alpha: 0.7)
        boxShadow: [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicador de estado operativo
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isLoadingMetrics
                            ? AppTheme.secondary
                            : _metricsError == null
                            ? cMintBright
                            : AppTheme.errorRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isLoadingMetrics
                                        ? AppTheme.secondary
                                        : _metricsError == null
                                        ? cMintBright
                                        : AppTheme.errorRed)
                                    .withValues(alpha: 0.45),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isLoadingMetrics
                            ? 'CARGANDO MÉTRICAS'
                            : _metricsError == null
                            ? 'RESUMEN DISPONIBLE'
                            : 'MÉTRICAS NO DISPONIBLES',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _isLoadingMetrics
                              ? AppTheme.secondary
                              : _metricsError == null
                              ? cMintBright
                              : AppTheme.errorRed,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Título
                Text(
                  'Centro de Control Super Admin',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: cTextMain,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                // Subtítulo con separador dim
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: cTextMuted,
                    ),
                    children: const [
                      TextSpan(text: 'Administración institucional '),
                      TextSpan(
                        text: '• ',
                        style: TextStyle(color: cTextDim),
                      ),
                      TextSpan(text: 'Resumen general'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Botón de acción rápida '+'
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showQuickAddDialog,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [cAccent, AppTheme.primary],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cAccentGlow,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: AppTheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BEGIN: KeyMetricsSection ---
  Widget _buildKeyMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de encabezado de sección
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MÉTRICAS GENERALES',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryFixed,
                letterSpacing: 0.8,
              ),
            ),
            Tooltip(
              message: _metricsError == null
                  ? 'Las métricas se consultan desde Supabase.'
                  : 'Error al cargar las métricas: $_metricsError',
              child: Text(
                _isLoadingMetrics
                    ? 'Consultando…'
                    : _metricsError == null
                    ? 'Consulta completada'
                    : 'Datos no disponibles',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _metricsError == null ? cTextMuted : AppTheme.errorRed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid 2x2
        Row(
          children: [
            Expanded(child: _buildMetricCardUsers()),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCardCourses()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMetricCardAttendance()),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCardRevenue()),
          ],
        ),
      ],
    );
  }

  // Card 1: Usuarios Activos
  Widget _buildMetricCardUsers() {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cBorder.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Usuarios Registrados',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cTextMuted,
                ),
              ),
              const Icon(Symbols.verified_user, size: 16, color: cMintBright),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatMetric(_totalUsuarios),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: cTextMain,
            ),
          ),
          const Spacer(),
          Text(
            'Perfiles registrados en la plataforma',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: cTextMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Card 2: Cursos Activos
  Widget _buildMetricCardCourses() {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cBorder.withValues(alpha: 0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cursos Activos',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cTextMuted,
                ),
              ),
              const Icon(Symbols.menu_book, size: 16, color: AppTheme.primary),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatMetric(_totalCursos),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: cTextMain,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'talleres',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cTextMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: cAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Talleres en operación',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: cTextMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 3: Tasa Asistencia
  Widget _buildMetricCardAttendance() {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cBorder.withValues(alpha: 0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Asistencia registrada',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cTextMuted,
                ),
              ),
              const Icon(Symbols.check_circle, size: 16, color: cMintBright),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _attendanceRate == null
                ? '—'
                : '${(_attendanceRate! * 100).toStringAsFixed(1)}%',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: cMintBright,
            ),
          ),
          const Spacer(),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cBorder.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _attendanceRate?.clamp(0, 1) ?? 0,
              child: Container(
                decoration: BoxDecoration(
                  color: cMintBright,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: cMintBright.withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card 4: Recaudación
  Widget _buildMetricCardRevenue() {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cBorder.withValues(alpha: 0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recaudación',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cTextMuted,
                ),
              ),
              const Icon(Symbols.wallet, size: 16, color: AppTheme.primary),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'No disponible',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cTextMuted,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sin agregado contable',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: cTextMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- BEGIN: ManagementModulesSection ---
  Widget _buildManagementModulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Módulo 1: Alumnos
        _buildModuleCard(
          icon: Symbols.school,
          iconColor: AppTheme.primary,
          title: 'Módulo Alumnos',
          badgeText: '${_formatMetric(_totalAlumnos)} alumnas',
          badgeBg: AppTheme.secondaryContainer,
          badgeTextColor: AppTheme.onSecondaryContainer,
          subtitle: 'Matrícula y seguimiento de asistencias.',
          bottomLeftWidget: _buildStudentCount(),
          isPrimaryAction: true,
          onEnter: () => context.go('/student'),
        ),
        const SizedBox(height: 14),

        // Módulo 2: Profesores
        _buildModuleCard(
          icon: Symbols.badge,
          iconColor: AppTheme.secondary,
          title: 'Módulo Profesores',
          badgeText: '${_formatMetric(_totalProfesores)} docentes',
          badgeBg: AppTheme.secondaryContainer,
          badgeTextColor: AppTheme.onSecondaryContainer,
          subtitle: 'Plantel docente y programación de sesiones.',
          bottomLeftWidget: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cMintBright,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: cMintBright.withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${_formatMetric(_totalProfesores)} docentes registrados',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: cTextMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          isPrimaryAction: false,
          onEnter: () => context.go('/teacher'),
        ),
        const SizedBox(height: 14),

        // Módulo 3: Coordinadores
        _buildModuleCard(
          icon: Symbols.military_tech,
          iconColor: AppTheme.tertiary,
          title: 'Módulo Coordinadores',
          badgeText: '${_formatMetric(_totalCoordinadores)} coordinadores',
          badgeBg: AppTheme.tertiaryContainer,
          badgeTextColor: AppTheme.onTertiaryContainer,
          subtitle: 'Supervisión institucional y reportes.',
          bottomLeftWidget: Row(
            children: [
              const Icon(Symbols.verified_user, size: 14, color: cMintBright),
              const SizedBox(width: 6),
              Text(
                'Gestión institucional',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cTextMuted,
                ),
              ),
            ],
          ),
          isPrimaryAction: false,
          onEnter: () => context.go('/coordinator'),
        ),
      ],
    );
  }

  Widget _buildModuleCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badgeText,
    required Color badgeBg,
    required Color badgeTextColor,
    required String subtitle,
    required Widget bottomLeftWidget,
    required bool isPrimaryAction,
    required VoidCallback onEnter,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cBorder.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Frame
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cCardInner,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cBorder),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: cTextMain,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.secondary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: badgeTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: cTextMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: bottomLeftWidget,
                ),
              ),
              const SizedBox(width: 8),
              // Botón Entrar al Módulo
              InkWell(
                onTap: onEnter,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: isPrimaryAction
                        ? const LinearGradient(
                            colors: [cAccent, AppTheme.primary],
                          )
                        : null,
                    color: isPrimaryAction ? null : cCardInner,
                    borderRadius: BorderRadius.circular(12),
                    border: isPrimaryAction ? null : Border.all(color: cBorder),
                    boxShadow: isPrimaryAction
                        ? const [
                            BoxShadow(
                              color: cAccentGlow,
                              blurRadius: 12,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ENTRAR AL MÓDULO',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isPrimaryAction
                              ? AppTheme.onPrimaryContainer
                              : cTextMain,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward,
                        size: 13,
                        color: isPrimaryAction
                            ? AppTheme.onPrimaryContainer
                            : cTextMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCount() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Symbols.groups, size: 16, color: cTextMuted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${_formatMetric(_totalAlumnos)} alumnas',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cTextMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // --- BEGIN: BottomNavigation ---
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: cCard.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: cBorder.withValues(alpha: 0.8))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Symbols.dashboard, 'General'),
          _buildNavItem(1, Symbols.school, 'Alumnos'),
          _buildNavItem(2, Symbols.badge, 'Profesores'),
          _buildNavItem(3, Symbols.military_tech, 'Coord.'),
          _buildNavItem(4, Symbols.settings, 'Ajustes'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 1) {
          context.go('/student');
        } else if (index == 2) {
          context.go('/teacher');
        } else if (index == 3) {
          context.go('/coordinator');
        } else if (index == 4) {
          _showSettingsModal();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? cAccent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: cAccent.withValues(alpha: 0.25))
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isSelected ? cAccent : cTextMuted),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? cAccent : cTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMetric(int? number) {
    if (number == null || _metricsError != null) return '—';
    return _formatNumber(number);
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
