import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/home/presentation/theme/home_theme_colors.dart';
import 'package:umbral_immujer/features/home/presentation/widgets/custom_top_bar.dart';
import 'package:umbral_immujer/features/home/presentation/widgets/hero_banner.dart';
import 'package:umbral_immujer/features/home/presentation/widgets/menu_option_card.dart';
import 'package:umbral_immujer/features/home/presentation/widgets/floating_bottom_bar.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/features/auth/data/auth_repository.dart';
import 'package:umbral_immujer/src/features/auth/presentation/login_screen.dart';
import 'package:umbral_immujer/src/features/alumnos/presentation/alumno_home_screen.dart';

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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AlumnoHomeScreen(
            profile: profile,
            initialIndex: tabIndex,
          ),
        ),
      );
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
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para consultar tus cursos, asistencias o responder encuestas oficiales, inicia sesión con tu cuenta de alumna de IMMUJER.',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeThemeColors.accentPink,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text(
                  'Iniciar Sesión',
                  style: GoogleFonts.montserrat(
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
            CustomTopBar(
              onLoginPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),

            // Contenido desplazable con SingleChildScrollView (previene overflows)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),

                    // B. Banner Hero "FORMACIONES IMMUJER"
                    const HeroBanner(),

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
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Colors.white,
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
                      onPressed: () => _navegarASeccion(2, 'Encuestas y Aportes'),
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
