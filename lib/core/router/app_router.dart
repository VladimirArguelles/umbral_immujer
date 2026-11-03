import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/features/coordinator/presentation/coordinator_dashboard_page.dart';
import 'package:umbral_immujer/features/landing/presentation/pages/landing_page.dart';
import 'package:umbral_immujer/features/student/presentation/student_dashboard_page.dart';
import 'package:umbral_immujer/features/superadmin/presentation/configuracion_general_screen.dart';
import 'package:umbral_immujer/features/superadmin/presentation/gestion_profesores_page.dart';
import 'package:umbral_immujer/features/superadmin/presentation/super_admin_dashboard.dart';
import 'package:umbral_immujer/features/teacher/presentation/teacher_dashboard_page.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/app_logger.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';
import 'package:umbral_immujer/src/features/auth/data/auth_repository.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';
import 'package:umbral_immujer/src/features/auth/presentation/login_screen.dart';
import 'package:umbral_immujer/src/features/auth/presentation/register_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _AuthStateNotifier(),
  redirect: (context, state) {
    final path = state.matchedLocation;
    final session = SupabaseConfig.client.auth.currentSession;
    final isAuthenticated = session != null;
    final isProtected =
        _matchesPrefix(path, '/student') ||
        _matchesPrefix(path, '/alumnos') ||
        _matchesPrefix(path, '/teacher') ||
        _matchesPrefix(path, '/profesor') ||
        _matchesPrefix(path, '/coordinator') ||
        _matchesPrefix(path, '/coordinador') ||
        _matchesPrefix(path, '/superadmin');

    if (!isAuthenticated && isProtected) {
      return '/login';
    }

    if (isAuthenticated && path == '/login') {
      return _routeForCurrentRole();
    }

    if (isAuthenticated) {
      if (_matchesPrefix(path, '/alumnos')) return '/student';
      if (_matchesPrefix(path, '/profesor')) return '/teacher';
      if (_matchesPrefix(path, '/coordinador')) return '/coordinator';

      final currentRole = _currentUserRole();

      // Control de acceso estricto basado en roles para rutas de Super Admin
      if (_matchesPrefix(path, '/superadmin') && currentRole != UserRole.superAdmin) {
        AppLogger.warning(
          'Acceso denegado a ruta Super Admin: $path por usuario con rol $currentRole',
          tag: 'SECURITY_ROUTER',
        );
        return _routeForRole(currentRole);
      }

      // Control de acceso para rutas de Coordinación
      if (_matchesPrefix(path, '/coordinator') &&
          currentRole != UserRole.coordinador &&
          currentRole != UserRole.superAdmin) {
        AppLogger.warning(
          'Acceso denegado a ruta Coordinador: $path por usuario con rol $currentRole',
          tag: 'SECURITY_ROUTER',
        );
        return _routeForRole(currentRole);
      }
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LandingPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) {
        final roleParam = state.uri.queryParameters['role'];
        final initialRole = roleParam != null
            ? UserRole.fromString(roleParam)
            : null;
        return RegisterScreen(initialRole: initialRole);
      },
    ),
    GoRoute(
      path: '/student',
      pageBuilder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        final legacyTabIndex = int.tryParse(tab ?? '');
        final tabIndex = switch (tab) {
          'courses' => 1,
          'attendance' => 2,
          'surveys' => 3,
          _ => legacyTabIndex == null ? 0 : legacyTabIndex.clamp(0, 2) + 1,
        };
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          child: _AuthenticatedDashboardPage(
            allowedRoles: const [UserRole.alumno, UserRole.superAdmin],
            builder: (profile) =>
                StudentDashboardPage(profile: profile, initialIndex: tabIndex),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );
      },
    ),
    GoRoute(path: '/alumnos', redirect: (context, state) => '/student'),
    GoRoute(
      path: '/teacher',
      pageBuilder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        final legacyTabIndex = int.tryParse(tab ?? '');
        final tabIndex = switch (tab) {
          'attendance' || 'asistencia' => 1,
          'surveys' || 'encuestas' => 2,
          'revenue' || 'recaudacion' => 3,
          'students' || 'alumnos' => 4,
          _ => legacyTabIndex == null ? 0 : legacyTabIndex.clamp(0, 4),
        };
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          child: _AuthenticatedDashboardPage(
            allowedRoles: const [UserRole.profesor, UserRole.coordinador, UserRole.superAdmin],
            builder: (profile) =>
                TeacherDashboardPage(profile: profile, initialIndex: tabIndex),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );
      },
    ),
    GoRoute(path: '/profesor', redirect: (context, state) => '/teacher'),
    GoRoute(
      path: '/coordinator',
      builder: (context, state) => _AuthenticatedDashboardPage(
        allowedRoles: const [UserRole.coordinador, UserRole.superAdmin],
        builder: (profile) => CoordinatorDashboardPage(profile: profile),
      ),
    ),
    GoRoute(
      path: '/superadmin',
      builder: (context, state) => _AuthenticatedDashboardPage(
        allowedRoles: const [UserRole.superAdmin],
        builder: (profile) => SuperAdminDashboardPage(profile: profile),
      ),
    ),
    GoRoute(
      path: '/superadmin/profesores',
      builder: (context, state) => _AuthenticatedDashboardPage(
        allowedRoles: const [UserRole.superAdmin],
        builder: (profile) => const GestionProfesoresPage(),
      ),
    ),
    GoRoute(
      path: '/superadmin/configuracion',
      builder: (context, state) => _AuthenticatedDashboardPage(
        allowedRoles: const [UserRole.superAdmin],
        builder: (profile) => const ConfiguracionGeneralScreen(),
      ),
    ),
    GoRoute(
      path: '/configuracion-general',
      redirect: (context, state) => '/superadmin/configuracion',
    ),
    GoRoute(
      path: '/gestion-profesores',
      redirect: (context, state) => '/superadmin/profesores',
    ),
    GoRoute(path: '/coordinador', redirect: (context, state) => '/coordinator'),
  ],
);

bool _matchesPrefix(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

UserRole _currentUserRole() {
  final role = SupabaseConfig.client.auth.currentUser?.userMetadata?['rol'];
  return UserRole.fromString(role is String ? role : null);
}

String _routeForRole(UserRole role) {
  return switch (role) {
    UserRole.superAdmin => '/superadmin',
    UserRole.coordinador => '/coordinator',
    UserRole.profesor => '/teacher',
    UserRole.alumno => '/student',
  };
}

String _routeForCurrentRole() => _routeForRole(_currentUserRole());

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier() {
    _subscription = SupabaseConfig.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

class _AuthenticatedDashboardPage extends StatefulWidget {
  const _AuthenticatedDashboardPage({
    required this.builder,
    this.allowedRoles,
  });

  final Widget Function(UserProfile profile) builder;
  final List<UserRole>? allowedRoles;

  @override
  State<_AuthenticatedDashboardPage> createState() =>
      _AuthenticatedDashboardPageState();
}

class _AuthenticatedDashboardPageState
    extends State<_AuthenticatedDashboardPage> {
  late final Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthRepository(SupabaseConfig.client).getCurrentProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: SafeArea(child: DashboardSkeleton()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          final errorMsg = snapshot.hasError
              ? 'No se pudo cargar el perfil: ${snapshot.error}'
              : 'No se encontró el perfil de usuario.';
          AppLogger.error(errorMsg, tag: 'AUTH_PAGE', error: snapshot.error);

          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorRed),
                    const SizedBox(height: 16),
                    Text(
                      errorMsg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login_rounded),
                      onPressed: () async {
                        await SupabaseConfig.client.auth.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      label: const Text('Volver al inicio de sesión'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data!;

        // Verificación estricta de roles autorizados
        if (widget.allowedRoles != null && !widget.allowedRoles!.contains(profile.rol)) {
          AppLogger.warning(
            'Acceso denegado: Usuario ${profile.id} con rol ${profile.rol} intentó acceder a vista restringida',
            tag: 'SECURITY_ACCESS_DENIED',
          );

          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          size: 56,
                          color: AppTheme.errorRed,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Acceso Restringido (403)',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tu cuenta con rol "${profile.rol.displayName}" no cuenta con los permisos necesarios para acceder a este módulo del sistema.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: AppTheme.mutedGray, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Ir a mi panel autorizado', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => context.go(_routeForRole(profile.rol)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return widget.builder(profile);
      },
    );
  }
}
