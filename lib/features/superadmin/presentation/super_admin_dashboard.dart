import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:umbral_immujer/features/superadmin/data/supabase_super_admin_repository.dart';
import 'package:umbral_immujer/features/superadmin/domain/super_admin_metrics.dart';
import 'package:umbral_immujer/features/superadmin/domain/super_admin_repository.dart';
import 'package:umbral_immujer/features/superadmin/presentation/gestion_usuarios_page.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_headers.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_metrics_grid.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_modules_grid.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_quick_add_dialog.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_settings_sheet.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_side_nav.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_theme_tokens.dart';
import 'package:umbral_immujer/src/core/services/app_update_service.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/super_admin_nav_bar.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

// ─── Responsive breakpoints ───────────────────────────────────────────────────
// < 600 px  → mobile  : bottom-nav + single column
// 600-1023  → tablet  : bottom-nav + single column (wider)
// ≥ 1024 px → desktop : side-nav + two-column grid

class SuperAdminDashboardPage extends StatelessWidget {
  const SuperAdminDashboardPage({super.key, this.profile, this.repository});

  final UserProfile? profile;
  final SuperAdminRepository? repository;

  @override
  Widget build(BuildContext context) {
    return SuperAdminDashboard(profile: profile, repository: repository);
  }
}

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key, this.profile, this.repository});

  final UserProfile? profile;
  final SuperAdminRepository? repository;

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  late final SuperAdminRepository _repository;

  int _currentIndex = 0;
  SuperAdminMetrics _metrics = const SuperAdminMetrics();
  bool _isLoadingMetrics = true;
  Object? _metricsError;

  SuperAdminQuickSettings _quickSettings = const SuperAdminQuickSettings(
    platformName: 'UMBRAL IMMUJER',
    activeCycle: '2024-B',
    rlsEnabled: true,
    notificationsEnabled: true,
    maintenanceMode: false,
  );

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseSuperAdminRepository();
    _loadMetrics();
    if (!AppUpdateService.instance.hasCheckedUpdate &&
        !AppUpdateService.instance.isUpdateDialogDismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAppUpdateSilently();
      });
    }
  }

  Future<void> _checkAppUpdateSilently() async {
    if (!mounted) return;
    await AppUpdateService.instance.checkAndShowUpdateModal(context);
  }

  Future<void> _loadMetrics() async {
    try {
      final result = await _repository.fetchMetrics();
      if (!mounted) return;
      setState(() {
        _metrics = result.metrics;
        _isLoadingMetrics = false;
        _metricsError = result.partialError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingMetrics = false;
        _metricsError = error;
      });
    }
  }

  Future<void> _handleSignOut() async {
    AppUpdateService.resetSessionCheck();
    await _repository.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  void _openUsersManagement() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(builder: (_) => const GestionUsuariosPage()),
        )
        .then((_) => _loadMetrics());
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 1) {
      context.go('/student');
    } else if (index == 2) {
      context.go('/teacher');
    } else if (index == 3) {
      context.go('/coordinator');
    } else if (index == 4) {
      context.go('/superadmin/configuracion');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: SuperAdminTokens.bg,
      ),
      child: Scaffold(
        backgroundColor: SuperAdminTokens.bg,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            final isTablet =
                constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

            if (isDesktop) {
              return SizedBox.expand(child: _buildDesktopLayout(constraints));
            }
            return _buildMobileLayout(isTablet: isTablet);
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuperAdminSideNav(
          screenHeight: constraints.maxHeight,
          currentIndex: _currentIndex,
          onSelectIndex: _onNavTap,
          onSignOut: _handleSignOut,
        ),
        Expanded(
          child: Container(
            color: SuperAdminTokens.bg,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SuperAdminDesktopHeader(
                    isLoadingMetrics: _isLoadingMetrics,
                    hasMetricsError: _metricsError != null,
                    onRefreshMetrics: _loadMetrics,
                    onOpenQuickAdd: () => showSuperAdminQuickAddDialog(
                      context,
                      onRefreshMetrics: _loadMetrics,
                    ),
                    onOpenSettings: () => showSuperAdminSettingsSheet(
                      context,
                      settings: _quickSettings,
                      onSettingsChanged: (updated) =>
                          setState(() => _quickSettings = updated),
                      onSignOut: _handleSignOut,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SuperAdminMetricsGrid(
                    metrics: _metrics,
                    onOpenUsers: _openUsersManagement,
                    spacing: 16,
                  ),
                  const SizedBox(height: 28),
                  SuperAdminModulesSection(
                    metrics: _metrics,
                    isDesktop: true,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout({required bool isTablet}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? 720 : 430),
        child: Container(
          color: SuperAdminTokens.bg,
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
                        SuperAdminMobileHeader(
                          isLoadingMetrics: _isLoadingMetrics,
                          hasMetricsError: _metricsError != null,
                          onOpenQuickAdd: () => showSuperAdminQuickAddDialog(
                            context,
                            onRefreshMetrics: _loadMetrics,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SuperAdminMetricsGrid(
                          metrics: _metrics,
                          onOpenUsers: _openUsersManagement,
                          spacing: 12,
                          onlineUsersFontSize: 11,
                          forceColumns: isTablet ? 4 : 2,
                        ),
                        const SizedBox(height: 20),
                        SuperAdminModulesSection(
                          metrics: _metrics,
                          isDesktop: false,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SuperAdminBottomNavBar(currentIndex: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
