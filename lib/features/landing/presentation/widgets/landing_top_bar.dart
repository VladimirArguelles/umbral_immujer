import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Barra superior para la pantalla de inicio / Gateway
class LandingTopBar extends StatelessWidget {
  final VoidCallback onLoginPressed;

  const LandingTopBar({super.key, required this.onLoginPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logotipo Oficial UMBRAL
          Hero(
            tag: 'app_logo_umbral',
            child: Image.asset(
              'assets/images/Logo Umbral.png',
              height: 52,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  'UMBRAL',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: AppTheme.onSurface,
                  ),
                );
              },
            ),
          ),

          // Botón estilo píldora rosa/magenta translúcido "Entrar"
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                elevation: 0,
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: AppTheme.outline.withValues(alpha: 0.25),
                  width: 1,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: onLoginPressed,
              icon: const Icon(Icons.login_rounded, size: 16),
              label: Text(
                'Entrar',
                style: GoogleFonts.plusJakartaSans(
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
  }
}
