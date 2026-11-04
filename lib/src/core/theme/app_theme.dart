import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// PALETA DE COLORES OFICIAL MODO CLARO (APPCOLORS)
// =============================================================================
class AppColors {
  // ==========================================
  // 1. Colores Principales y Estructura
  // ==========================================
  static const Color primaryBlueStart = Color(0xFF2A3A93);
  static const Color primaryBlueEnd   = Color(0xFF3E4BA6);
  static const Color background       = Color(0xFFF4F6FB);
  static const Color surfaceWhite     = Color(0xFFFFFFFF);

  // ==========================================
  // 2. Colores de Iconos y Acentos (Acceso Rápido)
  // ==========================================
  static const Color blueViolet   = Color(0xFF5B4BD7);
  static const Color warmOrange   = Color(0xFFFF7A1A);
  static const Color lightBlue    = Color(0xFF2B82FB);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color pinkMagenta  = Color(0xFFFF4B72);
  static const Color goldenYellow = Color(0xFFF59E0B);

  // ==========================================
  // 3. Fondos Pasteles de Tarjetas
  // ==========================================
  static const Color softPurple     = Color(0xFFECE9FF);
  static const Color softOrange     = Color(0xFFFFF0E5);
  static const Color softBlue       = Color(0xFFEBF3FF);
  static const Color softMint       = Color(0xFFE6F7F0);
  static const Color softPink       = Color(0xFFFFEBF0);
  static const Color softCreamYellow = Color(0xFFFEF8E7);

  // ==========================================
  // 4. Tipografía y Textos
  // ==========================================
  static const Color textDark    = Color(0xFF111827);
  static const Color textGray    = Color(0xFF6B7280);
  static const Color textPrimary = Color(0xFF4F46E5);
}

class ThemeController {
  static const String _prefKey = 'umbral_theme_mode';
  // MODO CLARO ES EL PREDETERMINADO
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  static bool get isDark => themeMode.value == ThemeMode.dark;

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'dark') {
        themeMode.value = ThemeMode.dark;
      } else if (saved == 'light') {
        themeMode.value = ThemeMode.light;
      } else {
        themeMode.value = ThemeMode.light; // Predeterminado claro
      }
    } catch (_) {
      themeMode.value = ThemeMode.light;
    }
  }

  static Future<void> toggleTheme() async {
    final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
    themeMode.value = nextMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, nextMode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }
}

abstract final class AppTheme {
  // ===========================================================================
  // SELECTORES DINÁMICOS DE TEMA (CLARO / OSCURO)
  // Permiten reactividad instantánea al cambiar de modo sin romper const existentes
  // ===========================================================================

  static bool get isDark => ThemeController.isDark;

  /// Fondo principal de vistas y Scaffold
  static Color get dynamicBackground => isDark ? anthraciteDark : AppColors.background;

  /// Fondo de tarjetas principales y contenedores modulares
  static Color get dynamicCard => isDark ? anthraciteCard : AppColors.surfaceWhite;

  /// Fondo de contenedores secundarios / interiores
  static Color get dynamicSurfaceContainer => isDark ? anthracite : AppColors.softBlue;

  /// Fondo de elementos elevados o resaltados
  static Color get dynamicSurfaceHigh => isDark ? anthraciteElevated : AppColors.softPurple;

  /// Fondo de list tiles, chips y cajas secundarias
  static Color get dynamicSurfaceBright => isDark ? surfaceBright : AppColors.softBlue;

  /// Fondo de badges e indicadores de progreso inactivos
  static Color get dynamicSurfaceHighest => isDark ? surfaceContainerHighest : const Color(0xFFE5E7EB);

  /// Color de texto principal (títulos, encabezados, valores)
  static Color get dynamicText => isDark ? pureWhite : AppColors.textDark;

  /// Color de texto secundario (subtítulos, etiquetas, leyendas)
  static Color get dynamicTextMuted => isDark ? mutedGray : AppColors.textGray;

  /// Color de texto primario / enlaces
  static Color get dynamicTextPrimary => isDark ? coralFuchsia : AppColors.textPrimary;

  /// Color de bordes y separadores sutiles
  static Color get dynamicBorder => isDark ? outlineVariant : const Color(0xFFE5E7EB);

  /// Color de bordes interactivos y contornos
  static Color get dynamicOutline => isDark ? outline : const Color(0xFFD1D5DB);

  /// Color primario dinámico de la interfaz
  static Color get dynamicPrimary => isDark ? coralFuchsia : AppColors.primaryBlueStart;

  /// Color primario degradado fin
  static Color get dynamicPrimaryEnd => isDark ? coralFuchsiaSoft : AppColors.primaryBlueEnd;

  /// Color secundario dinámico
  static Color get dynamicSecondary => isDark ? secondary : AppColors.blueViolet;

  /// Color de éxito dinámico
  static Color get dynamicSuccess => isDark ? mintNeon : AppColors.emeraldGreen;

  /// Color de advertencia dinámico
  static Color get dynamicWarning => isDark ? warningOrange : AppColors.goldenYellow;

  // ===========================================================================
  // PALETA OFICIAL UMBRAL - IMMUJER (MODO OSCURO)
  // ===========================================================================

  /// Gris Oscuro / Antracita: Color de contenedores, tarjetas de métricas y módulos.
  static const Color anthracite = Color(0xFF1D1F27);
  static const Color anthraciteDark = Color(0xFF0F172A);
  static const Color anthraciteCard = Color(0xFF1E293B);
  static const Color anthraciteElevated = Color(0xFF272A32);

  /// Verde Menta / Neón: Indicadores de estado positivo, gráficos de líneas,
  /// porcentajes de éxito y barras de progreso.
  static const Color mintNeon = Color(0xFF0BD984);

  /// Rosa Coral / Fucsia: Llamada a la acción (CTA) para botones principales,
  /// insignias de alerta y notificaciones.
  static const Color coralFuchsia = Color(0xFFFF1493);
  static const Color coralFuchsiaSoft = Color(0xFFD42F8C);
  static const Color primaryGlow = Color(0x59FF1493);

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
  static const Color surfaceBright = anthraciteElevated;
  static const Color surfaceContainerLowest = Color(0xFF0B0E15);
  static const Color surfaceContainerLow = anthraciteCard;
  static const Color surfaceContainer = anthracite;
  static const Color surfaceContainerHigh = anthraciteElevated;
  static const Color surfaceContainerHighest = anthraciteElevated;
  static const Color onSurface = pureWhite;
  static const Color onSurfaceVariant = mutedGray;
  static const Color outline = Color(0xFF3F424E);
  static const Color outlineVariant = Color(0xFF2B2D38);
  static const Color activeOutline = Color(0xFF334155);
  /// Botones principales, acentos y llamadas a la acción (Rosa Coral / Fucsia)
  static const Color primary = coralFuchsia;
  static const Color onPrimary = Color(0xFF0F172A);
  static const Color primaryContainer = coralFuchsiaSoft;
  static const Color onPrimaryContainer = Color(0xFF0F172A);
  static const Color primaryFixed = coralFuchsia;
  static const Color primaryFixedDim = coralFuchsiaSoft;
  static const Color onPrimaryFixed = Color(0xFF0F172A);
  static const Color onPrimaryFixedVariant = Color(0xFF0F172A);
  static const Color primaryDark = primary;
  static const Color inversePrimary = Color(0xFFE11D48);

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
  static const Color tertiaryContainer = Color(0xFF10B981);
  static const Color successGreenVariant = Color(0xFF00A572);
  static const Color onTertiaryContainer = Color(0xFF00311F);
  static const Color tertiaryFixed = Color(0xFF6FFBBE);
  static const Color tertiaryFixedDim = mintNeon;
  static const Color onTertiaryFixed = Color(0xFF002113);
  static const Color onTertiaryFixedVariant = Color(0xFF005236);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color onError = pureWhite;
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

  static ThemeData get darkTheme => _buildDarkTheme();

  static ThemeData get lightTheme => _buildLightTheme();

  static ThemeData _buildDarkTheme() {
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
          side: const BorderSide(color: activeOutline, width: 1),
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
          borderSide: const BorderSide(color: activeOutline, width: 2),
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

  static ThemeData _buildLightTheme() {
    const lightBackground = AppColors.background;
    const lightSurface = AppColors.surfaceWhite;
    const lightOnSurface = AppColors.textDark;
    const lightOnSurfaceVariant = AppColors.textGray;
    const lightOutline = Color(0xFFE5E7EB);
    const lightOutlineVariant = Color(0xFFD1D5DB);
    const lightPrimary = AppColors.primaryBlueStart;

    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: lightOnSurface,
      displayColor: lightOnSurface,
    );
    final textTheme = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        color: lightOnSurface,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 28 / 22,
        color: lightOnSurface,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        color: lightOnSurface,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 22 / 16,
        color: lightOnSurface,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: lightOnSurface,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: lightOnSurface,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: lightOnSurfaceVariant,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 18 / 14,
        color: lightOnSurface,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        color: lightOnSurfaceVariant,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 14 / 11,
        color: lightOnSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: lightPrimary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.softBlue,
        onPrimaryContainer: AppColors.primaryBlueStart,
        secondary: AppColors.blueViolet,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.softPurple,
        onSecondaryContainer: AppColors.textDark,
        tertiary: AppColors.emeraldGreen,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.softMint,
        onTertiaryContainer: Color(0xFF065F46),
        error: errorRed,
        onError: Colors.white,
        surface: lightSurface,
        surfaceDim: Color(0xFFEDEFEF),
        surfaceBright: Colors.white,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Colors.white,
        surfaceContainer: AppColors.softBlue,
        surfaceContainerHigh: AppColors.softPurple,
        surfaceContainerHighest: Color(0xFFE5E7EB),
        onSurface: lightOnSurface,
        onSurfaceVariant: lightOnSurfaceVariant,
        outline: lightOutline,
        outlineVariant: lightOutlineVariant,
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: textTheme,
      tabBarTheme: TabBarThemeData(
        labelColor: lightPrimary,
        unselectedLabelColor: lightOnSurfaceVariant,
        indicatorColor: lightPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: lightPrimary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(color: lightOnSurfaceVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightOnSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: lightOnSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: lightOnSurfaceVariant),
        labelStyle: const TextStyle(color: lightOnSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightOutline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: lightPrimary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightOutline),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: lightOutline),
    );
  }
}
