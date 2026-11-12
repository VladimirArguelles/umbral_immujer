import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:umbral_immujer/features/assistant/presentation/widgets/mia_assistant_widget.dart';
import 'package:umbral_immujer/features/coordinator/data/coordinator_repository.dart';
import 'package:umbral_immujer/features/coordinator/presentation/widgets/coordinator_courses_tab.dart';
import 'package:umbral_immujer/features/coordinator/presentation/widgets/coordinator_dropdown_nav.dart';
import 'package:umbral_immujer/features/coordinator/presentation/widgets/coordinator_live_absences_tab.dart';
import 'package:umbral_immujer/features/coordinator/presentation/widgets/coordinator_supplies_audit_tab.dart';
import 'package:umbral_immujer/features/coordinator/presentation/widgets/coordinator_teachers_tab.dart';
import 'package:umbral_immujer/features/profile/presentation/profile_header_actions.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/services/app_update_service.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/responsive.dart';
import 'package:umbral_immujer/src/core/widgets/super_admin_nav_bar.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class CoordinatorDashboardPage extends StatefulWidget {
  const CoordinatorDashboardPage({super.key, required this.profile});

  final UserProfile profile;

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
    if (_currentProfile.rol == UserRole.coordinador &&
        !AppUpdateService.instance.hasCheckedUpdate &&
        !AppUpdateService.instance.isUpdateDialogDismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAppUpdateSilently();
      });
    }
  }

  Future<void> _checkAppUpdateSilently() async {
    if (!mounted ||
        _currentIndex != 0 ||
        _currentProfile.rol != UserRole.coordinador) {
      return;
    }
    await AppUpdateService.instance.checkAndShowUpdateModal(context);
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
      CoordinatorCoursesTab(coordinatorRepository: _coordinatorRepository),
      CoordinatorLiveAbsencesTab(coordinatorRepository: _coordinatorRepository),
      CoordinatorTeachersTab(coordinatorRepository: _coordinatorRepository),
      CoordinatorSuppliesAuditTab(
        coordinatorRepository: _coordinatorRepository,
      ),
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
            IconButton(
              tooltip: 'Módulo Inscripciones',
              icon: const Icon(
                Icons.how_to_reg_rounded,
                color: AppTheme.successGreen,
              ),
              onPressed: () => context.go('/inscripciones'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: const Text(
                  'Ver Registros',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => context.go('/reports'),
              ),
            ),
            CoordinatorDropdownNav(
              currentIndex: _currentIndex,
              isSuperAdmin: isSuperAdmin,
              profile: _currentProfile,
              onSelectTab: (index) => setState(() => _currentIndex = index),
              onProfileUpdated: (updated) =>
                  setState(() => _currentProfile = updated),
            ),
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
                    _SuperAdminBanner(
                      onReturn: () => context.go('/superadmin'),
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
        floatingActionButton: MiaFloatingAssistant(
          profile: _currentProfile,
          currentModule: 'coordinacion',
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

class _SuperAdminBanner extends StatelessWidget {
  const _SuperAdminBanner({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer.withValues(alpha: 0.25),
        border: const Border(
          bottom: BorderSide(color: AppTheme.outlineVariant, width: 0.5),
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
            onTap: onReturn,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }
}
