import 'package:flutter/material.dart';

abstract final class AuthFormStyles {
  static const background = Color(0xFF190F2C);
  static const panel = Color(0xFF211536);
  static const neonAccent = Color(0xFFFF006F);
  static const softAccent = Color(0xFFFF6FD3);

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
      hintStyle: const TextStyle(color: Colors.white54),
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
        borderSide: const BorderSide(color: Color(0xFFFF6B7A)),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFFF6B7A), width: 2),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFF9AA2)),
    );
  }

  static ButtonStyle get actionButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: neonAccent,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  static const labelStyle = TextStyle(color: softAccent, fontSize: 13);
}
