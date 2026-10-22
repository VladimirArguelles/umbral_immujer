import 'package:flutter/material.dart';

/// Paleta de colores y constantes de diseño visual para el Dashboard de Alumnos UMBRAL
class HomeThemeColors {
  // Fondo Principal (Dark Purple)
  static const Color background = Color(0xFF0F0818);

  // Tarjetas y Contenedores
  static const Color cardStart = Color(0xFF1F1133);
  static const Color cardEnd = Color(0xFF281540);
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardStart, cardEnd],
  );

  // Botón Primario y Acentos (Magenta/Rosa vibrante)
  static const Color accentPink = Color(0xFFE85589);
  static const Color accentPinkGlow = Color(0x66E85589);
  static const Color accentPurple = Color(0xFF9C4DCC);

  // Barra de Navegación Flotante
  static const Color navBarStart = Color(0xFF180D29);
  static const Color navBarEnd = Color(0xFF23123B);
  static const LinearGradient navBarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navBarStart, navBarEnd],
  );

  // Bordes y Superficies
  static const Color cardBorder = Color(0x1AFFFFFF); // Colors.white10
  static const Color activeIconContainer = Color(0xFFE85589);
}
