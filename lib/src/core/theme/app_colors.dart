import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Paleta de colores unificada y tokens semánticos institucionales UMBRAL - IMMUJER.
/// Proporciona acceso directo a los tonos oscuros, violetas, menta neón y fondos dinámicos.
abstract final class AppColors {
  // Primario / Violeta Institucional
  static const Color primary = AppTheme.primary;
  static const Color primaryContainer = AppTheme.primaryContainer;
  static const Color primaryGlow = AppTheme.primaryGlow;
  static const Color onPrimary = AppTheme.onPrimary;

  // Tonos Oscuros / Antracita
  static const Color darkBackground = AppTheme.anthraciteDark;
  static const Color darkCard = AppTheme.anthraciteCard;
  static const Color darkCardInner = AppTheme.anthracite;
  static const Color darkElevated = AppTheme.anthraciteElevated;

  // Acentos y Estados
  static const Color mintNeon = AppTheme.mintNeon;
  static const Color success = AppTheme.successGreen;
  static const Color error = AppTheme.errorRed;
  static const Color warning = AppTheme.warningOrange;

  // Tipografías
  static const Color textMain = AppTheme.pureWhite;
  static const Color textMuted = AppTheme.mutedGray;
  static const Color textDim = Color(0xFF64748B);

  // Bordes y Líneas
  static const Color outline = AppTheme.outline;
  static const Color outlineVariant = AppTheme.outlineVariant;

  // Getters reactivos acordes al modo activo (Claro / Oscuro)
  static Color get dynamicBackground => AppTheme.dynamicBackground;
  static Color get dynamicCard => AppTheme.dynamicCard;
  static Color get dynamicSurfaceHigh => AppTheme.dynamicSurfaceHigh;
  static Color get dynamicText => AppTheme.dynamicText;
  static Color get dynamicTextMuted => AppTheme.dynamicTextMuted;
  static Color get dynamicBorder => AppTheme.dynamicBorder;
  static Color get dynamicOutline => AppTheme.dynamicOutline;
}
