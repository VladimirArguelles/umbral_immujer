import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/landing/presentation/widgets/landing_top_bar.dart';
import 'package:umbral_immujer/features/landing/presentation/widgets/module_card.dart';
import 'package:umbral_immujer/features/landing/presentation/widgets/particles_background.dart';

/// Pantalla de bienvenida para elegir un módulo e iniciar la autenticación.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _openAuth(BuildContext context) {
    Navigator.of(context).pushNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0714),
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
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // El inicio de sesión verifica el perfil y abre el panel de su rol.
                      ModuleCard(
                        title: 'Alumnos',
                        description: 'Cursos, asistencia, encuestas y pagos.',
                        icon: Icons.school_rounded,
                        onTap: () => _openAuth(context),
                      ),
                      const SizedBox(height: 12),
                      ModuleCard(
                        title: 'Profesores',
                        description:
                            'Listado de alumnos, asistencia y evaluaciones.',
                        icon: Icons.menu_book_rounded,
                        onTap: () => _openAuth(context),
                      ),
                      const SizedBox(height: 12),
                      ModuleCard(
                        title: 'Coordinador',
                        description: 'Cursos, alumnos, pagos y auditoría.',
                        icon: Icons.admin_panel_settings_rounded,
                        onTap: () => _openAuth(context),
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
            color: const Color(0xFF1F132D).withValues(alpha: 0.7),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Hola Equipo!',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bienvenidos a UMBRAL. Selecciona un módulo para comenzar:',
                style: GoogleFonts.montserrat(
                  color: Colors.white70,
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
          style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pushNamed('/register'),
          child: const Text('Regístrate'),
        ),
        Text(
          ' o ',
          style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12),
        ),
        TextButton(
          onPressed: () => _openAuth(context),
          child: const Text('inicia sesión'),
        ),
      ],
    );
  }
}
