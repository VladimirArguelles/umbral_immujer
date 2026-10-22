import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/home/presentation/theme/home_theme_colors.dart';
import 'package:umbral_immujer/src/features/auth/presentation/login_screen.dart';

/// Barra superior limpia con el Logotipo Oficial de UMBRAL y botón de acceso 'Entrar'
class CustomTopBar extends StatelessWidget {
  final VoidCallback? onLoginPressed;

  const CustomTopBar({
    super.key,
    this.onLoginPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logoHeight = constraints.maxWidth < 350 ? 36.0 : 48.0;

          return SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Logotipo Oficial UMBRAL centrado en la barra
                Hero(
                  tag: 'app_logo_umbral',
                  child: Image.asset(
                    'assets/images/Logo Umbral.png',
                    height: logoHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Text(
                        'UMBRAL',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HomeThemeColors.accentPink,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: HomeThemeColors.accentPinkGlow,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
