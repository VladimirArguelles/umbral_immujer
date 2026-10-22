import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/home/presentation/theme/home_theme_colors.dart';

/// Banner Hero destacado de "FORMACIONES IMMUJER" con ilustración redimensionada
class HeroBanner extends StatelessWidget {
  final String imagePath;
  final VoidCallback? onTap;

  const HeroBanner({
    super.key,
    this.imagePath = 'assets/images/formaciones_inmujer.png',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF24113D),
            Color(0xFF381656),
          ],
        ),
        border: Border.all(color: Colors.white12, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Círculo decorativo difuminado en la esquina superior derecha
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HomeThemeColors.accentPink.withValues(alpha: 0.15),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Lado Izquierdo: Textos y Título
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tag Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: HomeThemeColors.accentPink.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: HomeThemeColors.accentPink.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'IMMUJER OFICIAL',
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: HomeThemeColors.accentPink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Título Grande
                        Text(
                          'FORMACIONES\nIMMUJER',
                          style: GoogleFonts.montserrat(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            height: 1.15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtítulo
                        Text(
                          'Empoderando MUJERES a través de la Educación y la Formación Profesional.',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Lado Derecho: Ilustración gráfica del banner ampliada
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 155, // Tamaño incrementado para mayor presencia e impacto visual
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback con ícono temático institucional
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  HomeThemeColors.accentPink,
                                  HomeThemeColors.accentPurple,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: HomeThemeColors.accentPink.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.auto_stories,
                                size: 52,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
