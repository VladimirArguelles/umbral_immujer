import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Shared color tokens and small display helpers for the Super Admin UI.
abstract final class SuperAdminTokens {
  static const Color bg = AppTheme.background;
  static const Color card = AppTheme.surfaceContainerLow;
  static const Color cardInner = AppTheme.surfaceContainerLowest;
  static const Color border = AppTheme.outlineVariant;
  static const Color accent = AppTheme.primaryContainer;
  static const Color accentGlow = AppTheme.primaryGlow;
  static const Color mintBright = AppTheme.tertiary;
  static const Color textMain = AppTheme.onSurface;
  static const Color textMuted = AppTheme.onSurfaceVariant;
  static const Color textDim = AppTheme.outline;
}

/// Formats nullable integer counts with thousands separators or an em-dash.
String formatSuperAdminMetric(int? number) {
  if (number == null) return '—';
  return number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

/// Uppercase section header used across desktop and mobile Super Admin views.
class SuperAdminSectionLabel extends StatelessWidget {
  const SuperAdminSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppTheme.primaryFixed,
        letterSpacing: 0.8,
      ),
    );
  }
}
