import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('applies the Nocturne Scholar color scheme and typography', () {
    final theme = AppTheme.lightTheme;
    final scheme = theme.colorScheme;

    expect(scheme.brightness, Brightness.dark);
    expect(scheme.surface, const Color(0xFF10131A));
    expect(scheme.primary, const Color(0xFFFFB2B7));
    expect(scheme.secondary, const Color(0xFFBFC6DC));
    expect(scheme.tertiary, const Color(0xFF4EDEA3));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF10131A));
    expect(
      theme.textTheme.bodyMedium?.fontFamily,
      startsWith('PlusJakartaSans'),
    );
    expect(theme.textTheme.headlineLarge?.fontSize, 32);
  });
}
