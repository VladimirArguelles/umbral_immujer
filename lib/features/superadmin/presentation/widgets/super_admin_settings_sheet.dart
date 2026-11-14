import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/profile/data/profile_repository.dart';
import 'package:umbral_immujer/features/profile/presentation/profile_modal.dart';
import 'package:umbral_immujer/features/superadmin/domain/super_admin_metrics.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_theme_tokens.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/feature_gate.dart';

/// Opens the quick system settings modal bottom sheet for Super Admin.
Future<void> showSuperAdminSettingsSheet(
  BuildContext context, {
  required SuperAdminQuickSettings settings,
  required ValueChanged<SuperAdminQuickSettings> onSettingsChanged,
  required VoidCallback onSignOut,
}) {
  var currentSettings = settings;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SuperAdminTokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (ctx, setModalState) {
        void update(SuperAdminQuickSettings updated) {
          setModalState(() => currentSettings = updated);
          onSettingsChanged(updated);
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ajustes del Sistema',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: SuperAdminTokens.textMain,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close,
                          color: SuperAdminTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: currentSettings.platformName,
                    style: const TextStyle(color: SuperAdminTokens.textMain),
                    decoration: _inputDecoration('Nombre de la Plataforma'),
                    onChanged: (val) => onSettingsChanged(
                      currentSettings.copyWith(platformName: val),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: currentSettings.activeCycle,
                    dropdownColor: SuperAdminTokens.cardInner,
                    style: const TextStyle(color: SuperAdminTokens.textMain),
                    decoration: _inputDecoration('Ciclo Académico Activo'),
                    items: const [
                      DropdownMenuItem(
                        value: '2024-B',
                        child: Text('Ciclo 2024-B (Agosto - Diciembre)'),
                      ),
                      DropdownMenuItem(
                        value: '2025-A',
                        child: Text('Ciclo 2025-A (Enero - Junio)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        update(currentSettings.copyWith(activeCycle: val));
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _SettingsSwitchTile(
                    title: 'Políticas Institucionales y RLS',
                    subtitle:
                        'Reglas de acceso por sede institucional y cifrado en reposo activo.',
                    value: currentSettings.rlsEnabled,
                    onChanged: (val) =>
                        update(currentSettings.copyWith(rlsEnabled: val)),
                  ),
                  _SettingsSwitchTile(
                    title: 'Notificaciones Push y Alertas',
                    subtitle:
                        'Avisos automáticos a facilitadores y alumnos por WhatsApp/Push.',
                    value: currentSettings.notificationsEnabled,
                    onChanged: (val) => update(
                      currentSettings.copyWith(notificationsEnabled: val),
                    ),
                  ),
                  _SettingsSwitchTile(
                    title: 'Modo Mantenimiento',
                    subtitle:
                        'Suspender temporalmente ingresos al portal de alumnos.',
                    value: currentSettings.maintenanceMode,
                    onChanged: (val) =>
                        update(currentSettings.copyWith(maintenanceMode: val)),
                  ),
                  FeatureGate(
                    flagKey: 'enable_bcv_sync_banner',
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _BcvQuickBanner(
                        onTap: () {
                          Navigator.pop(ctx);
                          context.go('/superadmin/configuracion');
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SuperAdminTokens.textMain,
                        side: const BorderSide(color: SuperAdminTokens.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final parentNavigator = Navigator.of(context);
                        parentNavigator.pop();
                        final current = await ProfileRepository(
                          SupabaseConfig.client,
                        ).getCurrentProfile();
                        if (current != null && context.mounted) {
                          await ProfileModal.show(context, profile: current);
                        }
                      },
                      icon: const Icon(Symbols.person),
                      label: const Flexible(
                        child: Text(
                          'Mi Perfil y Contraseña',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SuperAdminTokens.accent,
                        foregroundColor: AppTheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.go('/superadmin/configuracion');
                      },
                      icon: const Icon(Symbols.tune),
                      label: const Flexible(
                        child: Text(
                          'Configuración General',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.go('/admin/error-console');
                      },
                      icon: const Icon(Symbols.terminal),
                      label: const Flexible(
                        child: Text(
                          'Consola de Diagnóstico (Terminal)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SuperAdminTokens.accent,
                        side: const BorderSide(color: SuperAdminTokens.accent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onSignOut();
                      },
                      icon: const Icon(Symbols.logout),
                      label: const Flexible(
                        child: Text(
                          'Cerrar Sesión',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Umbral • Versión instalada: 0.1.6+7',
                      style: GoogleFonts.firaCode(
                        fontSize: 11,
                        color: SuperAdminTokens.textDim,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: SuperAdminTokens.textMuted),
    filled: true,
    fillColor: SuperAdminTokens.cardInner,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SuperAdminTokens.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SuperAdminTokens.border),
    ),
  );
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: SuperAdminTokens.textMain,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: SuperAdminTokens.textMuted, fontSize: 12),
      ),
      value: value,
      activeThumbColor: SuperAdminTokens.accent,
      onChanged: onChanged,
    );
  }
}

class _BcvQuickBanner extends StatelessWidget {
  const _BcvQuickBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SuperAdminTokens.cardInner,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SuperAdminTokens.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Symbols.currency_exchange,
              color: AppTheme.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasa Oficial BCV en Tiempo Real',
                  style: TextStyle(
                    color: SuperAdminTokens.textMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Sincronización vía API y auditoría en Bs.',
                  style: TextStyle(
                    color: SuperAdminTokens.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('Ir a Tasa BCV')),
        ],
      ),
    );
  }
}
