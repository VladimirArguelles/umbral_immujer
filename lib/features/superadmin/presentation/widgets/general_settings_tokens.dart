import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Design tokens used across General Settings widgets.
abstract final class GeneralSettingsTokens {
  static const Color bg = AppTheme.background;
  static const Color card = AppTheme.surfaceContainerLow;
  static const Color cardInner = AppTheme.surfaceContainerLowest;
  static const Color border = AppTheme.outlineVariant;
  static const Color primary = AppTheme.primary;
  static final Color primaryGlow = AppTheme.primary.withValues(alpha: 0.25);
  static const Color emerald = AppTheme.tertiaryContainer;
  static const Color sky = AppTheme.secondary;
  static const Color amber = AppTheme.warningOrange;
  static const Color textMain = AppTheme.pureWhite;
  static const Color textMuted = AppTheme.mutedGray;
  static const Color textDim = AppTheme.secondary;
}
