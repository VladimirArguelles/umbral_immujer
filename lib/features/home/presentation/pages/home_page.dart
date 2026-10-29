import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/home/presentation/theme/home_theme_colors.dart';
import 'package:umbral_immujer/features/home/presentation/widgets/custom_top_bar.dart';

import 'package:umbral_immujer/features/home/presentation/widgets/menu_option_card.dart';
import 'package:umbral_immujer/features/home/presentation/widgets/floating_bottom_bar.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/features/auth/data/auth_repository.dart';

/// Pantalla Principal (Home Dashboard) para Alumnos UMBRAL - IMMUJER
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedNavIndex = 0;
  late final AuthRepository _authRepo;

  @override
  void initState() {
    super.initState();
    _authRepo = AuthRepository(SupabaseConfig.client);
  }

  /// Navega a la sección solicitada, verificando si el alumno ya inició sesión
  Future<void> _navegarASeccion(int tabIndex, String rutaNombre) async {
    final profile = await _authRepo.getCurrentProfile();

    if (!mounted) return;

    if (profile != null) {
      context.go('/student?tab=$tabIndex');
    } else {
      // Si aún no ha iniciado sesión, ofrece ir a identificarse o registrarse
      showModalBottomSheet(
        context: context,
        backgroundColor: HomeThemeColors.cardStart,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Acceso al Módulo de $rutaNombre',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para consultar tus cursos, asistencias o responder encuestas oficiales, inicia sesión con tu cuenta de alumna de IMMUJER.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeThemeColors.accentPink,
                  foregroundColor: AppTheme.onPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/login');
                },
                child: Text(
                  'Iniciar Sesión',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _onBottomNavSelected(int index) {
    setState(() => _selectedNavIndex = index);

    switch (index) {
      case 0:
        // Ya está en HOME
        break;
      case 1:
        _navegarASeccion(0, 'Mis Cursos');
        break;
      case 2:
        _navegarASeccion(1, 'Mi Asistencia');
        break;
      case 3:
        _navegarASeccion(2, 'Encuestas y Aportes');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeThemeColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // A. Barra Superior Personalizada (Header)
            CustomTopBar(onLoginPressed: () => context.go('/login')),

            // Contenido desplazable con SingleChildScrollView (previene overflows)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),

                    // B. Banner Hero "FORMACIONES IMMUJER"
                    // B. Carrusel Slider Automático de Formaciones IMMUJER
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: _FormationCarousel(),
                    ),

                    const SizedBox(height: 14),

                    // Título de Sección
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: HomeThemeColors.accentPink,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Accesos Rápidos de Alumnas',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // C. Tarjetas de Menú Principal (Quick Access Cards)
                    // 1. MIS CURSOS
                    MenuOptionCard(
                      title: 'MIS CURSOS',
                      subtitle: 'Visualiza tus cursos',
                      buttonText: 'IR A MIS CURSOS',
                      icon: Icons.school_rounded,
                      badgeText: 'Activos & Historial',
                      onPressed: () => _navegarASeccion(0, 'Mis Cursos'),
                    ),

                    // 2. MI ASISTENCIA
                    MenuOptionCard(
                      title: 'MI ASISTENCIA',
                      subtitle: 'Consulta tu historial de participación',
                      buttonText: 'IR A MI ASISTENCIA',
                      icon: Icons.event_available_rounded,
                      badgeText: 'Alerta Inasistencias',
                      onPressed: () => _navegarASeccion(1, 'Mi Asistencia'),
                    ),

                    // 3. ENCUESTAS
                    MenuOptionCard(
                      title: 'ENCUESTAS',
                      subtitle: 'Participa en las encuestas',
                      buttonText: 'IR A ENCUESTAS',
                      icon: Icons.poll_rounded,
                      badgeText: 'Insumos y Aportes',
                      onPressed: () =>
                          _navegarASeccion(2, 'Encuestas y Aportes'),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // D. Bottom Navigation Bar Estilizada
            FloatingBottomBar(
              currentIndex: _selectedNavIndex,
              onTabSelected: _onBottomNavSelected,
            ),
          ],
        ),
      ),
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
      area: 'Área 1 · Liderazgo y graduación',
      title: 'Empoderamiento y liderazgo femenino',
      description: 'Gestión de proyectos y desarrollo de habilidades.',
      tag: 'LIDERAZGO',
      icon: Icons.workspace_premium_rounded,
      color: AppTheme.primary,
    ),
    _Formation(
      area: 'Área 2 · Tecnología',
      title: 'Programación y diseño web',
      description: 'Desarrollo web, tecnología y diseño de interfaces.',
      tag: 'CODING LAB',
      icon: Icons.code_rounded,
      color: AppTheme.tertiary,
    ),
    _Formation(
      area: 'Área 3 · Diseño textil y modas',
      title: 'Confección y artesanía sostenible',
      description: 'Patronaje, costura y desarrollo de marca.',
      tag: 'TALLER DE MODA',
      icon: Icons.checkroom_rounded,
      color: AppTheme.secondary,
    ),
    _Formation(
      area: 'Área 4 · Repostería artesanal',
      title: 'Repostería y panadería artesanal',
      description: 'Técnicas de pastelería, decoración y costos.',
      tag: 'PASTELERÍA',
      icon: Icons.cake_rounded,
      color: AppTheme.warningOrange,
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
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'FORMACIONES IMMUJER',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const Icon(Icons.circle, color: AppTheme.tertiary, size: 8),
              const SizedBox(width: 5),
              Text(
                'ACTIVO',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.tertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Explora las áreas formativas para impulsar tu autonomía profesional.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: Listener(
              onPointerDown: (_) => _autoplay?.cancel(),
              onPointerUp: (_) => _startAutoplay(),
              child: PageView.builder(
                controller: _pageController,
                itemCount: _formations.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) =>
                    _FormationCard(formation: _formations[index]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Row(
                children: List.generate(_formations.length, (index) {
                  final selected = index == _currentPage;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Semantics(
                      button: true,
                      label: 'Mostrar formación ${index + 1}',
                      child: GestureDetector(
                        onTap: () => _goToPage(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: selected ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.outlineVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
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
        image: const DecorationImage(
          image: AssetImage('assets/images/formaciones_inmujer.png'),
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
  });

  final String area;
  final String title;
  final String description;
  final String tag;
  final IconData icon;
  final Color color;
}
