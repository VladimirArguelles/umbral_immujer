import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

abstract final class AuthFormStyles {
  static const background = AppTheme.background;
  static const panel = AppTheme.surfaceContainerLow;
  static const neonAccent = AppTheme.primaryContainer;
  static const softAccent = AppTheme.primary;

  static InputDecoration inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: softAccent),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: softAccent),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: panel,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: neonAccent, width: 2),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppTheme.errorRed),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
      ),
      errorStyle: const TextStyle(color: AppTheme.errorRed),
    );
  }

  static ButtonStyle get actionButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: neonAccent,
    foregroundColor: AppTheme.onPrimaryContainer,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  static const labelStyle = TextStyle(color: softAccent, fontSize: 13);
}
