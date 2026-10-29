import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  // ===========================================================================
  // PALETA OFICIAL UMBRAL - IMMUJER
  // ===========================================================================

  /// Gris Oscuro / Antracita: Color de contenedores, tarjetas de métricas y módulos.
  static const Color anthracite = Color(0xFF1D1F27);
  static const Color anthraciteDark = Color(0xFF10131A);
  static const Color anthraciteCard = Color(0xFF191B23);
  static const Color anthraciteElevated = Color(0xFF272A32);

  /// Verde Menta / Neón: Indicadores de estado positivo, gráficos de líneas,
  /// porcentajes de éxito y barras de progreso.
  static const Color mintNeon = Color(0xFF4EDEA3);

  /// Rosa Coral / Fucsia: Llamada a la acción (CTA) para botones principales,
  /// insignias de alerta y notificaciones.
  static const Color coralFuchsia = Color(0xFFFF516A);
  static const Color coralFuchsiaSoft = Color(0xFFFFB2B7);

  /// Blanco Puro: Tipografías principales de títulos, valores numéricos y textos destacados.
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// Gris Claro / Atenuado: Textos secundarios, descripciones y subtítulos.
  static const Color mutedGray = Color(0xFFA1A1AA);

  // ===========================================================================
  // TOKENS MATERIAL 3 VINCULADOS A LA PALETA OFICIAL
  // ===========================================================================

  static const Color background = anthraciteDark;
  static const Color surface = anthraciteDark;
  static const Color surfaceDim = anthraciteDark;
  static const Color surfaceBright = Color(0xFF363941);
  static const Color surfaceContainerLowest = Color(0xFF0B0E15);
  static const Color surfaceContainerLow = anthraciteCard;
  static const Color surfaceContainer = anthracite;
  static const Color surfaceContainerHigh = anthraciteElevated;
  static const Color surfaceContainerHighest = Color(0xFF32353D);
  static const Color onSurface = pureWhite;
  static const Color onSurfaceVariant = mutedGray;
  static const Color outline = Color(0xFF3F424E);
  static const Color outlineVariant = Color(0xFF2B2D38);
  /// Botones principales, acentos y llamadas a la acción (Rosa Coral / Fucsia)
  static const Color primary = coralFuchsiaSoft;
  static const Color onPrimary = Color(0xFF67001B);
  static const Color primaryContainer = coralFuchsia;
  static const Color onPrimaryContainer = Color(0xFF5B0017);
  static const Color primaryFixed = Color(0xFFFFDADB);
  static const Color primaryFixedDim = coralFuchsiaSoft;
  static const Color onPrimaryFixed = Color(0xFF40000D);
  static const Color onPrimaryFixedVariant = Color(0xFF92002A);
  static const Color primaryDark = primary;
  static const Color inversePrimary = Color(0xFFBC0B3B);

  static const Color secondary = Color(0xFFBFC6DC);
  static const Color onSecondary = Color(0xFF283041);
  static const Color secondaryContainer = Color(0xFF41495B);
  static const Color onSecondaryContainer = Color(0xFFB0B8CD);
  static const Color secondaryFixed = Color(0xFFDBE2F8);
  static const Color secondaryFixedDim = Color(0xFFBFC6DC);
  static const Color onSecondaryFixed = Color(0xFF131C2B);
  static const Color onSecondaryFixedVariant = Color(0xFF3F4758);

  /// Indicadores de estado positivo, gráficos, porcentajes de éxito y barras de progreso (Verde Menta / Neón)
  static const Color tertiary = mintNeon;
  static const Color onTertiary = Color(0xFF003824);
  static const Color tertiaryContainer = Color(0xFF00A572);
  static const Color onTertiaryContainer = Color(0xFF00311F);
  static const Color tertiaryFixed = Color(0xFF6FFBBE);
  static const Color tertiaryFixedDim = mintNeon;
  static const Color onTertiaryFixed = Color(0xFF002113);
  static const Color onTertiaryFixedVariant = Color(0xFF005236);
  static const Color errorRed = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color successGreen = mintNeon;

  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    secondaryFixed: secondaryFixed,
    secondaryFixedDim: secondaryFixedDim,
    onSecondaryFixed: onSecondaryFixed,
    onSecondaryFixedVariant: onSecondaryFixedVariant,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    tertiaryFixed: tertiaryFixed,
    tertiaryFixedDim: tertiaryFixedDim,
    onTertiaryFixed: onTertiaryFixed,
    onTertiaryFixedVariant: onTertiaryFixedVariant,
    primaryFixed: primaryFixed,
    primaryFixedDim: primaryFixedDim,
    onPrimaryFixed: onPrimaryFixed,
    onPrimaryFixedVariant: onPrimaryFixedVariant,
    error: errorRed,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: onSurface,
    onInverseSurface: Color(0xFF2D3038),
    inversePrimary: inversePrimary,
    surfaceTint: primary,
    surfaceDim: surfaceDim,
    surfaceBright: surfaceBright,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
  );

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );
    final textTheme = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 28 / 22,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 22 / 16,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 18 / 14,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 14 / 11,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceContainerLow,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: outline, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: onSurfaceVariant),
        labelStyle: const TextStyle(color: onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceContainerLow,
        indicatorColor: primary.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(color: onSurfaceVariant),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: outlineVariant),
    );
  }
}
