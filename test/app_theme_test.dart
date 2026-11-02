import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('applies the UMBRAL color scheme and typography', () {
    final theme = AppTheme.darkTheme;
    final scheme = theme.colorScheme;

    expect(scheme.brightness, Brightness.dark);
    expect(scheme.surface, const Color(0xFF0F172A));
    expect(scheme.primary, const Color(0xFFFF1493));
    expect(scheme.primaryContainer, const Color(0xFFD42F8C));
    expect(scheme.secondary, const Color(0xFFBFC6DC));
    expect(scheme.tertiary, const Color(0xFF0BD984));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0F172A));
    expect(theme.cardTheme.color, const Color(0xFF1E293B));
    expect(AppTheme.lightTheme.colorScheme.primary, const Color(0xFFFF1493));
    expect(AppTheme.lightTheme.colorScheme.tertiary, const Color(0xFF0BD984));
    expect(
      theme.textTheme.bodyMedium?.fontFamily,
      startsWith('PlusJakartaSans'),
    );
    expect(theme.textTheme.headlineLarge?.fontSize, 32);
  });
}
