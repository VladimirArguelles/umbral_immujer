import 'dart:async';
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
                      const _FormationCarousel(),
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

class _FormationCarousel extends StatefulWidget {
  const _FormationCarousel();

  @override
  State<_FormationCarousel> createState() => _FormationCarouselState();
}

class _FormationCarouselState extends State<_FormationCarousel> {
  static const _formations = [
    _Formation(
      area: 'Área 1 · Estética y Belleza',
      title: 'Diseño y Estética de Cejas',
      description: 'Visagismo, micropigmentación y técnicas de cuidado facial.',
      tag: 'CEJAS',
      icon: Icons.face_retouching_natural_rounded,
      color: AppTheme.primary,
      imagePath: 'assets/images/cejas.png',
    ),
    _Formation(
      area: 'Área 2 · Gastronomía Tradicional',
      title: 'Panadería y Masas Artesanales',
      description: 'Panificación tradicional, fermentación, amasado y horneado.',
      tag: 'PANADERÍA',
      icon: Icons.bakery_dining_rounded,
      color: AppTheme.warningOrange,
      imagePath: 'assets/images/panaderia.png',
    ),
    _Formation(
      area: 'Área 3 · Pastelería y Dulces',
      title: 'Repostería y Decoración Artística',
      description: 'Técnicas de pastelería comercial, masas dulces y decoración.',
      tag: 'REPOSTERÍA',
      icon: Icons.cake_rounded,
      color: AppTheme.secondary,
      imagePath: 'assets/images/reposteria.png',
    ),
  ];

  late final PageController _pageController;
  Timer? _autoplay;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoplay();
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoplay() {
    _autoplay?.cancel();
    _autoplay = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _formations.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
    _startAutoplay();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.surfaceContainer, AppTheme.surfaceContainerLow],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'FORMACIONES IMMUJER',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                '${_currentPage + 1}/${_formations.length}',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Listener(
            onPointerDown: (_) => _autoplay?.cancel(),
            onPointerUp: (_) => _startAutoplay(),
            child: SizedBox(
              height: 156,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _formations.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _FormationCard(formation: _formations[index]);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Row(
                children: List.generate(
                  _formations.length,
                  (index) => GestureDetector(
                    onTap: () => _goToPage(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 6),
                      width: _currentPage == index ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppTheme.primary
                            : AppTheme.outlineVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _CarouselArrow(
                icon: Icons.chevron_left_rounded,
                label: 'Formación anterior',
                onTap: () => _goToPage(
                  (_currentPage - 1 + _formations.length) % _formations.length,
                ),
              ),
              const SizedBox(width: 7),
              _CarouselArrow(
                icon: Icons.chevron_right_rounded,
                label: 'Siguiente formación',
                onTap: () => _goToPage((_currentPage + 1) % _formations.length),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormationCard extends StatelessWidget {
  const _FormationCard({required this.formation});

  final _Formation formation;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: AssetImage(formation.imagePath),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.surfaceContainer.withValues(alpha: 0.55),
              AppTheme.surfaceContainer.withValues(alpha: 0.94),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formation.area.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.onSurface,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formation.tag,
                    style: GoogleFonts.plusJakartaSans(
                      color: formation.color,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(formation.icon, color: formation.color, size: 25),
            const SizedBox(height: 5),
            Text(
              formation.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              formation.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: label,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.surfaceBright,
        foregroundColor: AppTheme.onSurface,
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _Formation {
  const _Formation({
    required this.area,
    required this.title,
    required this.description,
    required this.tag,
    required this.icon,
    required this.color,
    required this.imagePath,
  });

  final String area;
  final String title;
  final String description;
  final String tag;
  final IconData icon;
  final Color color;
  final String imagePath;
}

