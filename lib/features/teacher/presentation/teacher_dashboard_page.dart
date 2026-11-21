import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:umbral_immujer/features/assistant/presentation/widgets/mia_assistant_widget.dart';
import 'package:umbral_immujer/features/profile/presentation/profile_header_actions.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_attendance_tab.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_dropdown_nav.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_notification_bell.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_revenue_audit_tab.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_students_tab.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_summary_tab.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_surveys_tab.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/services/app_update_service.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/super_admin_nav_bar.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({
    super.key,
    required this.profile,
    this.initialIndex = 0,
  });

  final UserProfile profile;
  final int initialIndex;

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
    if (_currentProfile.rol == UserRole.profesor &&
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
        _currentProfile.rol != UserRole.profesor) {
      return;
    }
    await AppUpdateService.instance.checkAndShowUpdateModal(context);
  }

  void _handleBackNavigation() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    } else if (_currentProfile.role == UserRole.superAdmin) {
      context.go('/superadmin');
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = _currentProfile.role == UserRole.superAdmin;
    final tabs = [
      TeacherSummaryTab(
        teacherName: _currentProfile.fullName,
        isSuperAdmin: isSuperAdmin,
        teacherRepository: _teacherRepository,
        profile: _currentProfile,
        onNavigate: (idx) => setState(() => _currentIndex = idx),
      ),
      TeacherAttendanceTab(
        teacherRepository: _teacherRepository,
        isSuperAdmin: isSuperAdmin,
      ),
      TeacherSurveysTab(
        teacherRepository: _teacherRepository,
        isSuperAdmin: isSuperAdmin,
        profile: _currentProfile,
      ),
      TeacherRevenueAuditTab(
        teacherRepository: _teacherRepository,
        isSuperAdmin: isSuperAdmin,
      ),
      TeacherStudentsTab(
        teacherRepository: _teacherRepository,
        isSuperAdmin: isSuperAdmin,
        teacherName: _currentProfile.fullName,
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
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: _currentIndex != 0
                ? 'Regresar al inicio del módulo'
                : (isSuperAdmin ? 'Volver a Super Admin' : 'Volver al inicio'),
            onPressed: _handleBackNavigation,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Docente',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
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
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                _currentProfile.fullName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                      fontWeight: FontWeight.normal,
                      fontSize: 11,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            TeacherDropdownNav(
              currentIndex: _currentIndex,
              isSuperAdmin: isSuperAdmin,
              profile: _currentProfile,
              onSelectTab: (idx) => setState(() => _currentIndex = idx),
              onProfileUpdated: (updated) =>
                  setState(() => _currentProfile = updated),
            ),
            TeacherNotificationBell(
              teacherRepository: _teacherRepository,
              isSuperAdmin: isSuperAdmin,
              profile: _currentProfile,
              onNavigateTab: (idx) => setState(() => _currentIndex = idx),
            ),
            const ThemeModeToggleButton(),
            UserProfileAvatarButton(
              profile: _currentProfile,
              onProfileUpdated: (updated) =>
                  setState(() => _currentProfile = updated),
            ),
          ],
        ),
        body: tabs[_currentIndex],
        floatingActionButton: MiaFloatingAssistant(
          profile: _currentProfile,
          currentModule: 'profesores',
        ),
        bottomNavigationBar: isSuperAdmin
            ? const SuperAdminBottomNavBar(currentIndex: 2)
            : null,
      ),
    );
  }
}
