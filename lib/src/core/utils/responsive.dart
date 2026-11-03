import 'package:flutter/material.dart';

/// Tipos de dispositivo según ancho de pantalla
enum ScreenType { mobile, tablet, desktop }

/// Utilidad y sistema de breakpoints responsivos para UMBRAL IMMUJER
class Responsive {
  /// Breakpoints estándar
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;
  static const double maxContentWidth = 1280.0;

  /// Detecta si el ancho de pantalla corresponde a Mobile (< 600px)
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  /// Detecta si el ancho de pantalla corresponde a Tablet (600px <= width < 1024px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Detecta si el ancho de pantalla corresponde a Desktop / Web (width >= 1024px)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  /// Obtiene el tipo de pantalla actual
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobileBreakpoint) return ScreenType.mobile;
    if (width < tabletBreakpoint) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  /// Retorna un valor específico según el tamaño del viewport
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.mobile:
        return mobile;
    }
  }

  /// Cantidad recomendada de columnas para vistas de cuadrícula (Grid)
  static int gridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    return value(context, mobile: mobile, tablet: tablet, desktop: desktop);
  }

  /// Relleno horizontal dinámico para centrar contenido en pantallas grandes
  static EdgeInsets screenPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tabletBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    } else if (width >= mobileBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }

  /// Envoltura para centrar y restringir ancho máximo en pantallas grandes
  static Widget constrainedContainer({
    required Widget child,
    double maxWidth = maxContentWidth,
    EdgeInsetsGeometry? padding,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding, child: child)
            : child,
      ),
    );
  }
}

/// Widget constructor responsivo que renderiza la vista correspondiente según el breakpoint
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Responsive.tabletBreakpoint) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= Responsive.mobileBreakpoint) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}

/// Widget builder que proporciona las restricciones y el ScreenType
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    ScreenType screenType,
    BoxConstraints constraints,
  ) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        ScreenType type = ScreenType.mobile;
        if (constraints.maxWidth >= Responsive.tabletBreakpoint) {
          type = ScreenType.desktop;
        } else if (constraints.maxWidth >= Responsive.mobileBreakpoint) {
          type = ScreenType.tablet;
        }
        return builder(context, type, constraints);
      },
    );
  }
}
