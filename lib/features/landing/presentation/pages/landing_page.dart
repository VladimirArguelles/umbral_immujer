import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/landing/presentation/widgets/landing_top_bar.dart';
import 'package:umbral_immujer/features/landing/presentation/widgets/module_card.dart';
import 'package:umbral_immujer/features/landing/presentation/widgets/particles_background.dart';
import 'package:umbral_immujer/src/features/auth/presentation/auth_form_styles.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Pantalla de bienvenida para elegir un módulo e iniciar la autenticación o registro.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _openAuth(BuildContext context) {
    context.go('/login');
  }

  void _showModuleOptions(
    BuildContext context, {
    required String title,
    required String role,
    required IconData icon,
    required String description,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer.withValues(alpha: 0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          border: Border.all(
                            color:
                                AppTheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Icon(icon, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Módulo $title',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              description,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AuthFormStyles.neonAccent,
                      foregroundColor: AppTheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(
                      'Registrarse en $title',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/register?role=$role');
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(
                        color: AppTheme.outline.withValues(alpha: 0.25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      'Iniciar Sesión',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/login');
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ParticlesBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // El encabezado ofrece acceso directo al inicio de sesión.
                      LandingTopBar(onLoginPressed: () => _openAuth(context)),
                      const SizedBox(height: 24),
                      _buildWelcomeCard(),
                      const SizedBox(height: 24),
                      Text(
                        'Selecciona tu módulo',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ModuleCard(
                        title: 'Alumnos',
                        description: 'Cursos, asistencia, encuestas y pagos.',
                        icon: Icons.school_rounded,
                        onTap: () => _showModuleOptions(
                          context,
                          title: 'Alumnos',
                          role: 'alumno',
                          icon: Icons.school_rounded,
                          description:
                              'Solo alumnos previamente inscritos pueden registrarse.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ModuleCard(
                        title: 'Profesores',
                        description:
                            'Listado de alumnos, asistencia y evaluaciones.',
                        icon: Icons.menu_book_rounded,
                        onTap: () => _showModuleOptions(
                          context,
                          title: 'Profesores',
                          role: 'profesor',
                          icon: Icons.menu_book_rounded,
                          description:
                              'Solo profesores autorizados en nómina docente.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ModuleCard(
                        title: 'Coordinador',
                        description: 'Cursos, alumnos, pagos y auditoría.',
                        icon: Icons.admin_panel_settings_rounded,
                        onTap: () => _showModuleOptions(
                          context,
                          title: 'Coordinador',
                          role: 'coordinador',
                          icon: Icons.admin_panel_settings_rounded,
                          description:
                              'Gestión institucional y supervisión de UMBRAL.',
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildAuthFooter(context),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Presenta el saludo dentro de una superficie de vidrio esmerilado.
  Widget _buildWelcomeCard() {
    final borderRadius = BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer.withValues(alpha: 0.9),
            borderRadius: borderRadius,
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Hola Equipo!',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.onSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bienvenidos a UMBRAL. Selecciona un módulo para comenzar:',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mantiene registro e inicio de sesión como acciones independientes.
  Widget _buildAuthFooter(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '¿Aún no tienes una cuenta? ',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AuthFormStyles.softAccent,
          ),
          onPressed: () => context.push('/register'),
          child: const Text('Regístrate'),
        ),
        Text(
          ' o ',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AuthFormStyles.softAccent,
          ),
          onPressed: () => _openAuth(context),
          child: const Text('inicia sesión'),
        ),
      ],
    );
  }
}
