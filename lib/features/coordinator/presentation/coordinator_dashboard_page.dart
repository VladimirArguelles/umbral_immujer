import 'package:umbral_immujer/src/core/widgets/formation_image_carousel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/superadmin/presentation/gestion_cursos_page.dart';
import 'package:umbral_immujer/features/superadmin/presentation/gestion_profesores_page.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/src/core/utils/responsive.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';
import 'package:umbral_immujer/features/coordinator/domain/coordinator_models.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';
import 'package:umbral_immujer/src/core/widgets/super_admin_nav_bar.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';
import 'package:umbral_immujer/features/profile/presentation/profile_header_actions.dart';
import 'package:umbral_immujer/features/profile/presentation/profile_modal.dart';

class CoordinatorDashboardPage extends StatefulWidget {
  final UserProfile profile;
  const CoordinatorDashboardPage({super.key, required this.profile});

  @override
  State<CoordinatorDashboardPage> createState() =>
      _CoordinatorDashboardPageState();
}

class _CoordinatorDashboardPageState extends State<CoordinatorDashboardPage> {
  int _currentIndex = 0;
  late final CoordinatorRepository _coordinatorRepository;
  late UserProfile _currentProfile;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
    _coordinatorRepository = CoordinatorRepository(SupabaseConfig.client);
  }

  Widget _buildDropdownNav(bool isSuperAdmin) {
    const tabTitles = [
      'Cursos',
      'En Vivo',
      'Profesores',
      'Insumos',
    ];
    const tabIcons = [
      Icons.dashboard_rounded,
      Icons.sensors_rounded,
      Icons.badge_rounded,
      Icons.monetization_on_rounded,
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
              'OPCIONES DE COORDINACIÓN',
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
            value: '/reports',
            child: Row(
              children: [
                const Icon(Icons.visibility_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(width: 10),
                Text('Ver Registros', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
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
              value: '/teacher',
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, size: 18, color: AppTheme.secondary),
                  SizedBox(width: 10),
                  Text('Módulo Docente (Profesores)'),
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
    final tabs = [
      _DashboardCursosTab(coordinatorRepository: _coordinatorRepository),
      _MonitorRealtimeAusenciasTab(
        coordinatorRepository: _coordinatorRepository,
      ),
      _AsignacionProfesoresTab(coordinatorRepository: _coordinatorRepository),
      _AuditoriaInsumosTab(coordinatorRepository: _coordinatorRepository),
    ];

    final isSuperAdmin = widget.profile.role == UserRole.superAdmin;
    final isDesktopOrTablet =
        Responsive.isTablet(context) || Responsive.isDesktop(context);

    return PopScope(
      canPop: _currentIndex == 0 && !isSuperAdmin,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: (_currentIndex != 0 || isSuperAdmin)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: _currentIndex != 0
                      ? 'Regresar al inicio de Coordinación'
                      : 'Volver a Super Admin',
                  onPressed: _handleBackNavigation,
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSuperAdmin
                    ? 'UMBRAL • Coordinación (Super Admin)'
                    : 'UMBRAL • Coordinación General',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                _currentProfile.fullName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: const Text('Ver Registros', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => context.go('/reports'),
              ),
            ),
            _buildDropdownNav(isSuperAdmin),
            const ThemeModeToggleButton(),
            UserProfileAvatarButton(
              profile: _currentProfile,
              onProfileUpdated: (updated) =>
                  setState(() => _currentProfile = updated),
            ),
          ],
        ),
        body: Row(
          children: [
            if (isDesktopOrTablet)
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: (val) =>
                    setState(() => _currentIndex = val),
                labelType: NavigationRailLabelType.all,
                backgroundColor: AppTheme.dynamicCard,
                minWidth: 76,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: Text('Cursos'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.sensors_outlined),
                    selectedIcon: Icon(Icons.sensors_rounded),
                    label: Text('En Vivo'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.badge_outlined),
                    selectedIcon: Icon(Icons.badge_rounded),
                    label: Text('Profesores'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.monetization_on_outlined),
                    selectedIcon: Icon(Icons.monetization_on_rounded),
                    label: Text('Insumos'),
                  ),
                ],
              ),
            if (isDesktopOrTablet)
              const VerticalDivider(
                thickness: 1,
                width: 1,
                color: AppTheme.outlineVariant,
              ),
            Expanded(
              child: Column(
                children: [
                  if (isSuperAdmin)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                              'Modo Super Admin • Módulo Coordinación',
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
                  Expanded(
                    child: Responsive.constrainedContainer(
                      maxWidth: 1400,
                      child: tabs[_currentIndex],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: !isDesktopOrTablet
            ? (isSuperAdmin
                ? const SuperAdminBottomNavBar(currentIndex: 3)
                : NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (val) =>
                        setState(() => _currentIndex = val),
                    backgroundColor: AppTheme.dynamicCard,
                    indicatorColor: AppTheme.primary.withValues(alpha: 0.2),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(
                          Icons.dashboard_rounded,
                          color: AppTheme.primary,
                        ),
                        label: 'Cursos',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.sensors_outlined),
                        selectedIcon: Icon(
                          Icons.sensors_rounded,
                          color: AppTheme.primary,
                        ),
                        label: 'En Vivo',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.badge_outlined),
                        selectedIcon: Icon(
                          Icons.badge_rounded,
                          color: AppTheme.primary,
                        ),
                        label: 'Profesores',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.monetization_on_outlined),
                        selectedIcon: Icon(
                          Icons.monetization_on_rounded,
                          color: AppTheme.primary,
                        ),
                        label: 'Insumos',
                      ),
                    ],
                  ))
            : null,
      ),
    );
  }
}

/// -------------------------------------------------------------
/// -------------------------------------------------------------
/// TAB 1: DASHBOARD DE CURSOS Y ESTADÍSTICAS
/// -------------------------------------------------------------
class _DashboardCursosTab extends StatefulWidget {
  final CoordinatorRepository coordinatorRepository;
  const _DashboardCursosTab({required this.coordinatorRepository});

  @override
  State<_DashboardCursosTab> createState() => _DashboardCursosTabState();
}

class _DashboardCursosTabState extends State<_DashboardCursosTab> {
  late Future<List<CourseDashboardItem>> _dashboardFuture;
  late Future<List<SolicitudNotificacionItem>> _notificacionesFuture;
  late Future<List<AporteCursoBsItem>> _aportesFuture;
  late Future<List<JustificativoRevisionItem>> _justificativosFuture;
  final String _fechaHoy = Formatters.isoDate(DateTime.now());
  int _filtroDinamicoIndex = 0; // 0: Aportes en Bs, 1: Justificativos

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    setState(() {
      _dashboardFuture = widget.coordinatorRepository.getCourseDashboard(_fechaHoy);
      _notificacionesFuture = widget.coordinatorRepository.getPendingApprovalRequests();
      _aportesFuture = widget.coordinatorRepository.getAportesCursosEnBs();
      _justificativosFuture = widget.coordinatorRepository.getJustificativosRevision();
    });
  }

  bool _isCourseActiveNow(String? horario) {
    if (horario == null || horario.trim().isEmpty) return false;
    final now = DateTime.now();
    final hLower = horario.toLowerCase();
    final diasMap = {
      1: ['lunes', 'lun'],
      2: ['martes', 'mar'],
      3: ['miercoles', 'miércoles', 'mie', 'mié'],
      4: ['jueves', 'jue'],
      5: ['viernes', 'vie'],
      6: ['sabado', 'sábado', 'sab', 'sáb'],
      7: ['domingo', 'dom'],
    };
    final todayTokens = diasMap[now.weekday] ?? [];
    if (hLower.contains('lunes a viernes') && now.weekday >= 1 && now.weekday <= 5) {
      return true;
    }
    return todayTokens.any((t) => hLower.contains(t));
  }

  void _abrirCentroNotificaciones(List<SolicitudNotificacionItem> solicitudes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Centro de Notificaciones y Aprobaciones',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            Text(
                              '${solicitudes.length} gestiones docentes pendientes de revisión',
                              style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
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
                  const Divider(height: 24),
                  if (solicitudes.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No hay notificaciones ni gestiones pendientes.',
                          style: TextStyle(color: AppTheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: solicitudes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final item = solicitudes[index];
                          final tipoLegible = item.tipoLabel.toUpperCase();
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        tipoLegible,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      Formatters.date(item.createdAt),
                                      style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Profesor: ${item.profesorNombre}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'Curso: ${item.cursoNombre}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${item.datosNuevos.entries.map((e) => '${e.key}: ${e.value}').join('\n')}${item.motivo != null ? '\nMotivo: ${item.motivo}' : ''}',
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.errorRed),
                                      label: const Text('Rechazar', style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppTheme.errorRed),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                      onPressed: () async {
                                        final obsCtrl = TextEditingController();
                                        final bool? confirmar = await showDialog<bool>(
                                          context: context,
                                          builder: (dCtx) => AlertDialog(
                                            title: const Text('Rechazar Solicitud'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text('Indique la razón u observación del rechazo:'),
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller: obsCtrl,
                                                  decoration: const InputDecoration(
                                                    hintText: 'Motivo del rechazo',
                                                    border: OutlineInputBorder(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(dCtx).pop(false),
                                                child: const Text('Cancelar'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.of(dCtx).pop(true),
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                                                child: const Text('Rechazar'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmar == true) {
                                          await widget.coordinatorRepository.rejectApprovalRequest(
                                            item.id,
                                            observacion: obsCtrl.text.trim(),
                                          );
                                          if (!ctx.mounted) return;
                                          Navigator.of(ctx).pop();
                                          _loadAll();
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Solicitud rechazada.')),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check_rounded, size: 16),
                                      label: const Text('Aprobar', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.successGreen,
                                        foregroundColor: AppTheme.pureWhite,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      ),
                                      onPressed: () async {
                                        await widget.coordinatorRepository.approveApprovalRequest(
                                          item.id,
                                          observacion: 'Aprobado por Coordinación',
                                        );
                                        if (!ctx.mounted) return;
                                        Navigator.of(ctx).pop();
                                        _loadAll();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Solicitud aprobada y aplicada con éxito.')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data ?? {};
              final alumnosList = (data['alumnos'] as List? ?? []);
              final temasList = (data['temas'] as List<String>? ?? []);

              return StatefulBuilder(
                builder: (modalCtx, setSheetState) => Padding(
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
                                  ),
                                ),
                                const Text(
                                  'Gestión directa de plantilla de Alumnos y Temas',
                                  style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
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
                          Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Alumnos'),
                          Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Temas'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // TAB ALUMNOS
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Alumnos Registrados (${alumnosList.length})',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Añadir Alumno'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      onPressed: () => _mostrarModalAddAlumno(curso, () {
                                        setSheetState(() {});
                                        _loadAll();
                                      }),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: alumnosList.isEmpty
                                      ? const Center(child: Text('No hay alumnos inscritos en este curso.'))
                                      : ListView.separated(
                                          itemCount: alumnosList.length,
                                          separatorBuilder: (_, _) => const Divider(height: 1),
                                          itemBuilder: (_, aIdx) {
                                            final item = alumnosList[aIdx];
                                            final al = item['alumnos'] as Map<String, dynamic>?;
                                            final studentId = item['alumno_id'] as String;
                                            final nombre = al?['nombre_completo'] ?? 'Sin nombre';
                                            final cedula = al?['cedula'] ?? '';
                                            final telefono = al?['telefono'] ?? '';

                                            return ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: AppTheme.primaryContainer,
                                                child: Text(nombre.isNotEmpty ? nombre[0] : 'A'),
                                              ),
                                              title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              subtitle: Text('C.I: $cedula ${telefono.isNotEmpty ? "• Tlf: $telefono" : ""}'),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.person_remove_rounded, color: AppTheme.errorRed),
                                                tooltip: 'Desincorporar Alumno',
                                                onPressed: () async {
                                                  final conf = await showDialog<bool>(
                                                    context: context,
                                                    builder: (d) => AlertDialog(
                                                      title: const Text('Desincorporar Alumno'),
                                                      content: Text('¿Desea desincorporar a $nombre de este curso?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(d).pop(false),
                                                          child: const Text('Cancelar'),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () => Navigator.of(d).pop(true),
                                                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                                                          child: const Text('Desincorporar'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (conf == true) {
                                                    await widget.coordinatorRepository.coordinatorDeleteStudent(
                                                      courseId: curso.id,
                                                      studentId: studentId,
                                                    );
                                                    setSheetState(() {
                                                      alumnosList.removeAt(aIdx);
                                                    });
                                                    _loadAll();
                                                  }
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),

                            // TAB TEMAS
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Temas del Curso (${temasList.length})',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Añadir Tema'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      onPressed: () => _mostrarModalAddTema(curso, (nuevoTema) {
                                        setSheetState(() {
                                          temasList.add(nuevoTema);
                                        });
                                      }),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: temasList.isEmpty
                                      ? const Center(child: Text('No hay temas registrados para este curso.'))
                                      : ListView.separated(
                                          itemCount: temasList.length,
                                          separatorBuilder: (_, _) => const Divider(height: 1),
                                          itemBuilder: (_, tIdx) {
                                            final tema = temasList[tIdx];
                                            return ListTile(
                                              leading: CircleAvatar(
                                                radius: 14,
                                                backgroundColor: AppTheme.secondaryContainer,
                                                child: Text('${tIdx + 1}', style: const TextStyle(fontSize: 11)),
                                              ),
                                              title: Text(tema),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.primary),
                                                    tooltip: 'Editar Tema',
                                                    onPressed: () => _mostrarModalEditTema(curso, tema, (actualizado) {
                                                      setSheetState(() {
                                                        temasList[tIdx] = actualizado;
                                                      });
                                                    }),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.errorRed),
                                                    tooltip: 'Eliminar Tema',
                                                    onPressed: () async {
                                                      final conf = await showDialog<bool>(
                                                        context: context,
                                                        builder: (d) => AlertDialog(
                                                          title: const Text('Eliminar Tema'),
                                                          content: Text('¿Desea eliminar el tema "$tema"?'),
                                                          actions: [
                                                            TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancelar')),
                                                            ElevatedButton(
                                                              onPressed: () => Navigator.of(d).pop(true),
                                                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                                                              child: const Text('Eliminar'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (conf == true) {
                                                        await widget.coordinatorRepository.coordinatorDeleteTema(
                                                          courseId: curso.id,
                                                          tema: tema,
                                                        );
                                                        setSheetState(() {
                                                          temasList.removeAt(tIdx);
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
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
              );
            },
          ),
        ),
      ),
    );
  }

  void _mostrarModalAddAlumno(CourseDashboardItem curso, VoidCallback onSuccess) {
    final nombreCtrl = TextEditingController();
    final cedulaCtrl = TextEditingController();
    final tlfCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Añadir Alumno a ${curso.nombre}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre Completo *')),
              const SizedBox(height: 8),
              TextField(controller: cedulaCtrl, decoration: const InputDecoration(labelText: 'Cédula de Identidad *')),
              const SizedBox(height: 8),
              TextField(controller: tlfCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Correo Electrónico')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty || cedulaCtrl.text.trim().isEmpty) return;
              Navigator.of(dCtx).pop();
              await widget.coordinatorRepository.coordinatorAddStudent(
                courseId: curso.id,
                courseName: curso.nombre,
                nombre: nombreCtrl.text.trim(),
                cedula: cedulaCtrl.text.trim(),
                telefono: tlfCtrl.text.trim(),
                email: emailCtrl.text.trim(),
              );
              onSuccess();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarModalAddTema(CourseDashboardItem curso, Function(String) onSuccess) {
    final temaCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Añadir Tema al Curso'),
        content: TextField(
          controller: temaCtrl,
          decoration: const InputDecoration(labelText: 'Título del Tema *'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (temaCtrl.text.trim().isEmpty) return;
              Navigator.of(dCtx).pop();
              await widget.coordinatorRepository.coordinatorAddTema(
                courseId: curso.id,
                tema: temaCtrl.text.trim(),
              );
              onSuccess(temaCtrl.text.trim());
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  void _mostrarModalEditTema(CourseDashboardItem curso, String oldTema, Function(String) onSuccess) {
    final temaCtrl = TextEditingController(text: oldTema);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Editar Tema'),
        content: TextField(
          controller: temaCtrl,
          decoration: const InputDecoration(labelText: 'Título del Tema *'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (temaCtrl.text.trim().isEmpty) return;
              Navigator.of(dCtx).pop();
              await widget.coordinatorRepository.coordinatorEditTema(
                courseId: curso.id,
                oldTema: oldTema,
                newTema: temaCtrl.text.trim(),
              );
              onSuccess(temaCtrl.text.trim());
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _dashboardFuture,
        _notificacionesFuture,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CoursesSkeleton();
        }

        final cursos = (snapshot.data?[0] as List<CourseDashboardItem>?) ?? [];
        final notificaciones = (snapshot.data?[1] as List<SolicitudNotificacionItem>?) ?? [];

        // Métricas
        final totalAusencias = cursos.fold<int>(0, (prev, c) => prev + c.ausenciasHoy);
        final totalPresentes = cursos.fold<int>(0, (prev, c) => prev + c.presentesHoy);
        final totalAsistenciasMarcadas = totalPresentes + totalAusencias;
        final double asistenciaPromedio = totalAsistenciasMarcadas == 0
            ? 100.0
            : ((totalPresentes / totalAsistenciasMarcadas) * 100);

        final cursosOperandoHoy = cursos.where((c) => _isCourseActiveNow(c.horario)).length;

        return RefreshIndicator(
          onRefresh: () async => _loadAll(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Carrusel Formativo de Alumnos
              const FormationImageCarousel(),
              const SizedBox(height: 16),

              // Barra de Acciones Globales
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.school_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Gestión Cursos',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryContainer,
                        foregroundColor: AppTheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GestionCursosPage()),
                        ).then((_) => _loadAll());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.badge_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Gestión Profesores',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryContainer,
                        foregroundColor: AppTheme.onSecondaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GestionProfesoresPage()),
                        ).then((_) => _loadAll());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: notificaciones.isNotEmpty,
                    label: Text('${notificaciones.length}'),
                    backgroundColor: AppTheme.errorRed,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outlineVariant),
                      ),
                      child: IconButton(
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        icon: const Icon(Icons.notifications_active_rounded, size: 20, color: AppTheme.onTertiaryContainer),
                        tooltip: 'Centro de Notificaciones y Aprobaciones',
                        onPressed: () => _abrirCentroNotificaciones(notificaciones),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // KPI CARDS
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 420;
                  final cards = [
                    _buildMetricCard(
                      title: 'Cursos Activos',
                      value: '${cursos.length}',
                      subtitle: '$cursosOperandoHoy activos hoy',
                      icon: Icons.calendar_today_rounded,
                      color: AppTheme.primary,
                    ),
                    _buildMetricCard(
                      title: '% Asistencia',
                      value: '${asistenciaPromedio.toStringAsFixed(1)}%',
                      subtitle: '$totalPresentes presentes',
                      icon: Icons.pie_chart_rounded,
                      color: AppTheme.successGreen,
                    ),
                    _buildMetricCard(
                      title: 'Ausencias Hoy',
                      value: '$totalAusencias',
                      subtitle: totalAusencias > 0 ? 'Alerta activa' : 'Sin faltas',
                      icon: Icons.warning_amber_rounded,
                      color: totalAusencias > 0 ? AppTheme.errorRed : AppTheme.outlineVariant,
                    ),
                  ];

                  if (isCompact) {
                    return Column(
                      children: cards
                          .map((card) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: card,
                              ))
                          .toList(),
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 10),
                      Expanded(child: cards[1]),
                      const SizedBox(width: 10),
                      Expanded(child: cards[2]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // WIDGET PARA VISUALIZACIÓN DEL MONTO TOTAL DE APORTE POR CURSOS
              _buildResumenTotalAportesWidget(),
              const SizedBox(height: 20),

              // SECCIÓN: CURSOS ACTIVOS Y PLANTILLAS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cursos en Sistema y Tiempo Real',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.dynamicText,
                    ),
                  ),
                  Text(
                    '${cursos.length} cursos',
                    style: TextStyle(fontSize: 12, color: AppTheme.dynamicTextMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (cursos.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No hay cursos registrados en el sistema.')),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 720) {
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth >= 1050 ? 3 : 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 310,
                        ),
                        itemCount: cursos.length,
                        itemBuilder: (context, index) =>
                            _buildCourseCard(cursos[index]),
                      );
                    }
                    return Column(
                      children: cursos.map((c) => _buildCourseCard(c)).toList(),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // WIDGET CON FILTROS DINÁMICOS
              Text(
                'Supervisión Detallada & Filtros Dinámicos',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),

              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Aportes por Curso (Bs)', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.currency_exchange_rounded, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Justificativos Alumnos', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.assignment_late_rounded, size: 16),
                  ),
                ],
                selected: {_filtroDinamicoIndex},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _filtroDinamicoIndex = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Contenido Dinámico según Filtro
              if (_filtroDinamicoIndex == 0)
                _buildAportesEnBsWidget()
              else
                _buildJustificativosWidget(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResumenTotalAportesWidget() {
    return FutureBuilder<List<AporteCursoBsItem>>(
      future: _aportesFuture,
      builder: (context, snapshot) {
        final aportes = snapshot.data ?? [];
        final granTotalBs = aportes.fold<double>(0.0, (prev, a) => prev + a.totalAporteBs);
        final granTotalUsd = aportes.fold<double>(0.0, (prev, a) => prev + a.costoTotalUsd);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
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
                      color: AppTheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monto Total de Aportes por Cursos',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.dynamicText,
                          ),
                        ),
                        Text(
                          'Recaudación global consolidada en Bolívares (Tasa Oficial BCV)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppTheme.dynamicTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bs. ${Formatters.currency(granTotalBs)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.mintNeon,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '~ \$${granTotalUsd.toStringAsFixed(2)} USD',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ),
                ],
              ),
              if (aportes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: aportes.map((a) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '${a.cursoNombre}: Bs. ${Formatters.currency(a.totalAporteBs)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseCard(CourseDashboardItem c) {
    final isActiveNow = _isCourseActiveNow(c.horario);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: c.ausenciasHoy > 0
              ? AppTheme.errorRed.withValues(alpha: 0.5)
              : AppTheme.dynamicBorder,
          width: c.ausenciasHoy > 0 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActiveNow
                        ? AppTheme.successGreen.withValues(alpha: 0.2)
                        : AppTheme.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActiveNow
                            ? Icons.sensors_rounded
                            : Icons.calendar_month_rounded,
                        size: 14,
                        color: isActiveNow
                            ? AppTheme.successGreen
                            : AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActiveNow ? 'EN CURSO HOY' : 'PROGRAMADO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isActiveNow
                              ? AppTheme.successGreen
                              : AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              c.nombre,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.dynamicText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (c.horario != null && c.horario!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 14, color: AppTheme.secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      c.horario!,
                      style: TextStyle(
                          fontSize: 12.5, color: AppTheme.dynamicTextMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_pin, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Docente: ${c.profesorNombre ?? "Sin asignar"}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Alerta de Ausencias
            if (c.ausenciasHoy > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.errorRed.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppTheme.errorRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${c.ausenciasHoy} alumno(s) ausente(s) registrados hoy',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Barra de Asistencia
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (c.porcentajeAsistencia / 100).clamp(0.0, 1.0),
                      backgroundColor: AppTheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        c.porcentajeAsistencia >= 80
                            ? AppTheme.successGreen
                            : AppTheme.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${c.porcentajeAsistencia.toStringAsFixed(0)}% Asistencia',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),

            // Botón Plantilla Alumnos y Temas
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.menu_book_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Plantilla Alumnos y Temas'),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: AppTheme.primary),
                ),
                onPressed: () => _abrirPlantillaAlumnosYTemas(c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: AppTheme.dynamicTextMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: AppTheme.dynamicTextMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAportesEnBsWidget() {
    return FutureBuilder<List<AporteCursoBsItem>>(
      future: _aportesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        }
        final aportes = snapshot.data ?? [];
        if (aportes.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No hay aportes ni encuestas registradas para cálculo en Bolívares.'),
              ),
            ),
          );
        }

        return Column(
          children: aportes.map((a) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            a.cursoNombre,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Clase: ${a.fechaClase}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Costo Insumos: \$${a.costoTotalUsd.toStringAsFixed(2)} USD', style: const TextStyle(fontSize: 12)),
                        Text('Tasa BCV: ${a.tasaBcvUsada.toStringAsFixed(2)} Bs/USD', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Alumnos Confirmados: ${a.totalConfirmados}', style: const TextStyle(fontSize: 12)),
                    const Divider(height: 16),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Cuota por Alumno: Bs. ${Formatters.currency(a.cuotaBs)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successGreen,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Total: Bs. ${Formatters.currency(a.totalAporteBs)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildJustificativosWidget() {
    return FutureBuilder<List<JustificativoRevisionItem>>(
      future: _justificativosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No hay justificativos de alumnos pendientes de revisión.'),
              ),
            ),
          );
        }

        return Column(
          children: list.map((j) {
            Color badgeColor = AppTheme.primaryContainer;
            if (j.estado == 'aprobado') badgeColor = AppTheme.successGreen.withValues(alpha: 0.2);
            if (j.estado == 'rechazado') badgeColor = AppTheme.errorRed.withValues(alpha: 0.2);

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            j.alumnoNombre,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            j.estado.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'C.I: ${j.cedula} • Curso: ${j.cursoNombre}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                    ),
                    Text(
                      'Fecha de inasistencia: ${j.fecha}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.secondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Motivo: ${j.motivo}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (j.comprobanteUrl != null && j.comprobanteUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: const Text('Ver Comprobante Adjunto', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (d) => Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppBar(
                                    title: const Text('Comprobante Médico / Justificativo', style: TextStyle(fontSize: 14)),
                                    automaticallyImplyLeading: false,
                                    actions: [
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.of(d).pop(),
                                      ),
                                    ],
                                  ),
                                  Image.network(
                                    j.comprobanteUrl!,
                                    errorBuilder: (_, _, _) => const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('No fue posible cargar el comprobante.'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    if (j.estado == 'pendiente') ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.errorRed),
                            ),
                            onPressed: () async {
                              await widget.coordinatorRepository.updateJustificativoEstado(j.id, 'rechazado');
                              _loadAll();
                            },
                            child: const Text('Rechazar', style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successGreen,
                              foregroundColor: AppTheme.pureWhite,
                            ),
                            onPressed: () async {
                              await widget.coordinatorRepository.updateJustificativoEstado(j.id, 'aprobado');
                              _loadAll();
                            },
                            child: const Text('Aprobar Justificativo', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// TAB 2: MONITOREO EN TIEMPO REAL DE ASISTENCIAS (SUPABASE REALTIME)
/// -------------------------------------------------------------
class _MonitorRealtimeAusenciasTab extends StatefulWidget {
  final CoordinatorRepository coordinatorRepository;
  const _MonitorRealtimeAusenciasTab({required this.coordinatorRepository});

  @override
  State<_MonitorRealtimeAusenciasTab> createState() =>
      _MonitorRealtimeAusenciasTabState();
}

class _MonitorRealtimeAusenciasTabState
    extends State<_MonitorRealtimeAusenciasTab> {
  final String _fechaHoy = Formatters.isoDate(DateTime.now());
  List<LiveAbsence> _ausencias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAusencias();
    _suscribirRealtime();
  }

  void _loadAusencias() async {
    final list = await widget.coordinatorRepository.getTodayAbsences(_fechaHoy);
    if (mounted) {
      setState(() {
        _ausencias = list;
        _isLoading = false;
      });
    }
  }

  void _suscribirRealtime() {
    // Al recibir cambios en la tabla asistencias para hoy, recargar de inmediato
    widget.coordinatorRepository.streamTodayAttendance(_fechaHoy).listen((_) {
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
          color: AppTheme.errorRed.withValues(alpha: 0.12),
          child: Row(
            children: [
              const Icon(Icons.circle, color: AppTheme.errorRed, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Monitor en Vivo: Ausencias detectadas hoy ($_fechaHoy): ${_ausencias.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorRed,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.errorRed,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? const AttendanceSkeleton()
              : _ausencias.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 54,
                        color: AppTheme.successGreen,
                      ),
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
                        side: const BorderSide(
                          color: AppTheme.errorRed,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.errorRed,
                          child: Icon(
                            Icons.person_off,
                            color: AppTheme.onError,
                          ),
                        ),
                        title: Text(
                          aus.alumnoNombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Curso: ${aus.cursoNombre}'),
                            Text(
                              'C.I: ${aus.cedula} • ${aus.horaMarcada != null ? Formatters.dateTime(aus.horaMarcada!) : ""}',
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'AUSENTE',
                            style: TextStyle(
                              color: AppTheme.onError,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
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
  final CoordinatorRepository coordinatorRepository;
  const _AsignacionProfesoresTab({required this.coordinatorRepository});

  @override
  State<_AsignacionProfesoresTab> createState() =>
      _AsignacionProfesoresTabState();
}

class _AsignacionProfesoresTabState extends State<_AsignacionProfesoresTab> {
  late Future<List<AvailableTeacher>> _profesoresFuture;

  @override
  void initState() {
    super.initState();
    _loadProfesores();
  }

  void _loadProfesores() {
    setState(() {
      _profesoresFuture = widget.coordinatorRepository.getRegisteredTeachers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AvailableTeacher>>(
      future: _profesoresFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AttendanceSkeleton();
        }
        final profs = snapshot.data ?? [];
        if (profs.isEmpty) {
          return const Center(
            child: Text('No hay docentes con cuenta activa registrados.'),
          );
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
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: Icon(Icons.school, color: AppTheme.onPrimary),
                  ),
                  title: Text(
                    p.nombreCompleto,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'C.I: ${p.cedula} • ${p.telefono ?? "Sin teléfono"}\nCurso actual: ${p.cursoActual ?? "Disponible para asignación"}',
                  ),
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
  final CoordinatorRepository coordinatorRepository;
  const _AuditoriaInsumosTab({required this.coordinatorRepository});

  Widget _buildAuditCard(SurveyAudit e) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    e.cursoNombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Clase: ${e.fechaClase}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Presupuesto Total',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Formatters.currency(e.costoTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Confirmados',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${e.totalConfirmados}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Cuota por Alumno',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Formatters.currency(e.montoIndividual),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SurveyAudit>>(
      future: coordinatorRepository.getSurveyAudits(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SurveysSkeleton();
        }
        final encuestas = snapshot.data ?? [];
        if (encuestas.isEmpty) {
          return const Center(
            child: Text('No hay encuestas de insumos registradas.'),
          );
        }

        return Responsive.constrainedContainer(
          maxWidth: 1200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= Responsive.tabletBreakpoint) {
                return GridView.builder(
                  padding: Responsive.screenPadding(context),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 140,
                  ),
                  itemCount: encuestas.length,
                  itemBuilder: (context, idx) => _buildAuditCard(encuestas[idx]),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: encuestas.length,
                itemBuilder: (context, idx) => _buildAuditCard(encuestas[idx]),
              );
            },
          ),
        );
      },
    );
  }
}
