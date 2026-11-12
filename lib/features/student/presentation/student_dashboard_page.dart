import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:umbral_immujer/features/assistant/presentation/widgets/mia_assistant_widget.dart';
import 'package:umbral_immujer/features/profile/presentation/profile_header_actions.dart';
import 'package:umbral_immujer/features/student/data/student_repository.dart';
import 'package:umbral_immujer/features/student/presentation/student_summary_tab.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_attendance_tab.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_courses_tab.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_dropdown_nav.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_surveys_tab.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/services/app_update_service.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/super_admin_nav_bar.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({
    super.key,
    required this.profile,
    this.initialIndex = 0,
  });

  final UserProfile profile;
  final int initialIndex;

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  late int _currentIndex;
  late final StudentRepository _studentRepository;
  late UserProfile _currentProfile;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _studentRepository = StudentRepository(SupabaseConfig.client);
    if (_currentProfile.rol == UserRole.alumno &&
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
        _currentProfile.rol != UserRole.alumno) {
      return;
    }
    await AppUpdateService.instance.checkAndShowUpdateModal(context);
  }

  void _handleBackNavigation() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    } else if (_currentProfile.role == UserRole.superAdmin) {
      context.go('/superadmin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSuperAdmin = _currentProfile.role == UserRole.superAdmin;
    final tabs = [
      StudentSummaryTab(
        studentName: _currentProfile.fullName,
        onNavigate: (index) => setState(() => _currentIndex = index),
      ),
      StudentCoursesTab(
        studentRepository: _studentRepository,
        isSuperAdmin: isSuperAdmin,
      ),
      StudentAttendanceTab(
        studentRepository: _studentRepository,
        isSuperAdmin: isSuperAdmin,
      ),
      StudentSurveysTab(
        studentRepository: _studentRepository,
        isSuperAdmin: isSuperAdmin,
      ),
    ];

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
                      ? 'Regresar al inicio'
                      : 'Volver a Super Admin',
                  onPressed: _handleBackNavigation,
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'UMBRAL • Mi Aula',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                _currentProfile.fullName,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.dynamicTextMuted,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          actions: [
            StudentDropdownNav(
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
        body: Column(
          children: [
            if (isSuperAdmin) _SuperAdminModeBanner(),
            Expanded(child: tabs[_currentIndex]),
          ],
        ),
        floatingActionButton: MiaFloatingAssistant(
          profile: _currentProfile,
          currentModule: 'alumnos',
        ),
        bottomNavigationBar:
            isSuperAdmin ? const SuperAdminBottomNavBar(currentIndex: 1) : null,
      ),
    );
  }
}

class _SuperAdminModeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primary.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(
            Icons.admin_panel_settings_rounded,
            size: 16,
            color: AppTheme.primary,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo Super Admin • Módulo Alumnos',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
