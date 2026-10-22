import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/home/presentation/theme/home_theme_colors.dart';
import 'package:umbral_immujer/src/features/auth/presentation/login_screen.dart';

class CustomTopBar extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onLoginPressed;

  const CustomTopBar({
    super.key,
    this.onMenuPressed,
    this.onSearchPressed,
    this.onLoginPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Lado Izquierdo: Botones de Menú y Búsqueda
          Row(
            children: [
              _buildIconButton(
                icon: Icons.menu,
                tooltip: 'Menú principal',
                onTap: onMenuPressed ??
                    () {
                      Scaffold.maybeOf(context)?.openDrawer();
                    },
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.search,
                tooltip: 'Buscar cursos',
                onTap: onSearchPressed ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Buscador de cursos en UMBRAL'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
              ),
            ],
          ),

          // Centro: Logo / Texto tipográfico "UMBRAL" estilizado
          Hero(
            tag: 'app_title_umbral',
            child: Material(
              color: Colors.transparent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'UMBRAL',
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.5,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 3, top: 4),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: HomeThemeColors.accentPink,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lado Derecho: Botón píldora "Entrar"
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeThemeColors.accentPink,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: HomeThemeColors.accentPinkGlow,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: onLoginPressed ??
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
            icon: const Icon(Icons.login, size: 16),
            label: Text(
              'Entrar',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF), // Fondo traslúcido
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Icon(
          icon,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}
