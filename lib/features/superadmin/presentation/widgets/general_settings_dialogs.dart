import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_tokens.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Displays confirmation dialog before discarding unsaved settings edits.
Future<bool> confirmGeneralSettingsReset(
  BuildContext context, {
  required int modifiedCount,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: GeneralSettingsTokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: GeneralSettingsTokens.border),
      ),
      title: Row(
        children: [
          const Icon(
            Symbols.restart_alt,
            color: GeneralSettingsTokens.amber,
            size: 24,
          ),
          const SizedBox(width: 10),
          Text(
            'Restablecer Valores',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: GeneralSettingsTokens.textMain,
            ),
          ),
        ],
      ),
      content: Text(
        'Tienes $modifiedCount cambio(s) sin guardar.\n\n¿Deseas descartarlos y recargar los valores originales de la base de datos?',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: GeneralSettingsTokens.textMuted,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: GeneralSettingsTokens.textDim),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: GeneralSettingsTokens.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Descartar y Restablecer',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  return result == true;
}

/// Displays high-visibility confirmation before changing global maintenance mode.
Future<bool> confirmMaintenanceModeToggle(
  BuildContext context, {
  required bool enableMaintenance,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: GeneralSettingsTokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: enableMaintenance
              ? GeneralSettingsTokens.amber
              : GeneralSettingsTokens.border,
          width: enableMaintenance ? 1.5 : 1.0,
        ),
      ),
      title: Row(
        children: [
          Icon(
            enableMaintenance ? Symbols.warning : Symbols.check_circle,
            color: enableMaintenance
                ? GeneralSettingsTokens.amber
                : GeneralSettingsTokens.emerald,
            size: 26,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              enableMaintenance
                  ? '¿Activar Modo Mantenimiento?'
                  : '¿Desactivar Modo Mantenimiento?',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: GeneralSettingsTokens.textMain,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        enableMaintenance
            ? 'ALERTA: Al activar el Modo Mantenimiento, las estudiantes y profesores verán una pantalla de mantenimiento y no podrán registrar asistencias ni subir comprobantes.\n\n¿Estás seguro de continuar?'
            : 'La plataforma UMBRAL volverá a estar disponible públicamente para todos los roles de usuario.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: GeneralSettingsTokens.textMuted,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: GeneralSettingsTokens.textDim),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: enableMaintenance
                ? GeneralSettingsTokens.amber
                : GeneralSettingsTokens.emerald,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            enableMaintenance
                ? 'Sí, Activar Mantenimiento'
                : 'Reanudar Operaciones',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  return result == true;
}

/// Shows a floating feedback snackbar using UMBRAL status styling.
void showGeneralSettingsToast(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isSuccess = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError
                ? Symbols.error
                : isSuccess
                ? Symbols.check_circle
                : Symbols.info,
            color: (isError || isSuccess)
                ? Colors.white
                : GeneralSettingsTokens.sky,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: isError
          ? AppTheme.errorRed
          : isSuccess
          ? AppTheme.tertiary
          : AppTheme.surfaceContainerLow,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isError
              ? AppTheme.errorRed
              : isSuccess
              ? AppTheme.successGreen
              : GeneralSettingsTokens.border,
        ),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ),
  );
}
