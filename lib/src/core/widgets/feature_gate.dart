import 'package:flutter/material.dart';
import 'package:umbral_immujer/core/config/remote_config_service.dart';

/// Widget condicional para arquitectura Over-The-Air (Zero-Rebuild).
/// Permite encender o apagar componentes visuales, accesos a módulos o botones
/// en tiempo real según el estado del flag en la tabla `feature_flags`.
class FeatureGate extends StatelessWidget {
  /// Clave del feature flag registrada en la base de datos (ej. `'enable_pdf_importer'`)
  final String flagKey;

  /// Widget principal que se renderiza si el feature flag está activo
  final Widget child;

  /// Widget alternativo que se renderiza si el feature flag está deshabilitado
  final Widget? fallback;

  /// Rol del usuario para validar permisos específicos (opcional)
  final String? userRole;

  /// Si es true, invierte la lógica (muestra el child si el flag está apagado)
  final bool inverted;

  const FeatureGate({
    super.key,
    required this.flagKey,
    required this.child,
    this.fallback,
    this.userRole,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RemoteConfigService.instance,
      builder: (context, _) {
        final isEnabled = RemoteConfigService.instance.isFeatureEnabled(
          flagKey,
          userRole: userRole,
        );

        final shouldShow = inverted ? !isEnabled : isEnabled;

        if (shouldShow) {
          return child;
        }

        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}
