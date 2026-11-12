import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_tokens.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Top AppBar for General Settings with responsive badge and reset action.
class GeneralSettingsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const GeneralSettingsAppBar({
    super.key,
    required this.isBusy,
    required this.onResetPressed,
  });

  final bool isBusy;
  final VoidCallback onResetPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: GeneralSettingsTokens.card,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: GeneralSettingsTokens.textMain,
        ),
        tooltip: 'Volver al Panel',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/superadmin');
          }
        },
      ),
      titleSpacing: 0,
      title: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = MediaQuery.of(context).size.width < 500;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Configuración General',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: isSmall ? 15 : 17,
                        color: GeneralSettingsTokens.textMain,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isSmall) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: GeneralSettingsTokens.primary.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: GeneralSettingsTokens.primary.withAlpha(80),
                        ),
                      ),
                      child: const Text(
                        'SUPER ADMIN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: GeneralSettingsTokens.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                isSmall
                    ? 'Parámetros y auditoría de UMBRAL'
                    : 'Control de parámetros, auditoría, automatizaciones e integraciones de UMBRAL',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  color: GeneralSettingsTokens.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: TextButton.icon(
            onPressed: isBusy ? null : onResetPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 36),
            ),
            icon: const Icon(
              Symbols.restart_alt,
              size: 17,
              color: GeneralSettingsTokens.textMuted,
            ),
            label: Text(
              'Restablecer',
              style: GoogleFonts.plusJakartaSans(
                color: GeneralSettingsTokens.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(color: GeneralSettingsTokens.border, height: 1),
      ),
    );
  }
}

/// Banner indicating unsaved local parameter edits.
class GeneralSettingsPendingBanner extends StatelessWidget {
  const GeneralSettingsPendingBanner({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: GeneralSettingsTokens.amber.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GeneralSettingsTokens.amber.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.edit_note,
            color: GeneralSettingsTokens.amber,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tienes $count parámetro(s) con cambios locales pendientes por sincronizar en Supabase.',
              style: GoogleFonts.plusJakartaSans(
                color: GeneralSettingsTokens.textMain,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom bar summarizing pending changes and triggering batch save.
class GeneralSettingsBottomBar extends StatelessWidget {
  const GeneralSettingsBottomBar({
    super.key,
    required this.modifiedCount,
    required this.isSaving,
    required this.onSave,
  });

  final int modifiedCount;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 460;
        final isVeryNarrow = constraints.maxWidth < 360;

        return Container(
          decoration: BoxDecoration(
            color: GeneralSettingsTokens.card.withAlpha(245),
            border: const Border(
              top: BorderSide(color: GeneralSettingsTokens.border),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 20,
            vertical: isCompact ? 10 : 14,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modifiedCount > 0
                            ? '$modifiedCount cambio(s) pendiente(s)'
                            : 'Sin cambios pendientes',
                        style: GoogleFonts.plusJakartaSans(
                          color: modifiedCount > 0
                              ? GeneralSettingsTokens.amber
                              : GeneralSettingsTokens.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: isCompact ? 11.5 : 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isCompact
                            ? 'public.configuracion_general'
                            : 'Tabla: public.configuracion_general',
                        style: GoogleFonts.plusJakartaSans(
                          color: GeneralSettingsTokens.textDim,
                          fontSize: isCompact ? 9.5 : 10.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GeneralSettingsTokens.primary,
                    foregroundColor: AppTheme.onPrimary,
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 14 : 22,
                      vertical: isCompact ? 10 : 14,
                    ),
                    minimumSize: Size(0, isCompact ? 40 : 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    shadowColor: GeneralSettingsTokens.primaryGlow,
                  ),
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.save_rounded, size: isCompact ? 18 : 20),
                  label: Text(
                    isSaving
                        ? 'Guardando...'
                        : (isVeryNarrow ? 'Guardar' : 'Guardar Cambios'),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: isCompact ? 12 : 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
