import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Compatibility names backed by the application's shared palette.
class HomeThemeColors {
  static const Color background = AppTheme.background;
  static const Color cardStart = AppTheme.surfaceContainerLow;
  static const Color cardEnd = AppTheme.surfaceContainer;
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardStart, cardEnd],
  );
  static const Color accentPink = AppTheme.primary;
  static const Color accentPinkGlow = Color(0x59FFB2B7);
  static const Color accentPurple = AppTheme.secondary;
  static const Color navBarStart = AppTheme.surfaceContainer;
  static const Color navBarEnd = AppTheme.surfaceContainerLow;
  static const LinearGradient navBarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navBarStart, navBarEnd],
  );

  // Bordes y Superficies
  static const Color cardBorder = AppTheme.outlineVariant;
  static const Color activeIconContainer = AppTheme.primary;
}
