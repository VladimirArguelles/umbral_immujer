import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:umbral_immujer/features/assistant/presentation/widgets/mia_assistant_widget.dart';
import 'package:umbral_immujer/features/profile/presentation/profile_modal.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

/// Quick tab-switcher and role-navigation dropdown shown in Coordinator AppBar.
class CoordinatorDropdownNav extends StatelessWidget {
  const CoordinatorDropdownNav({
    super.key,
    required this.currentIndex,
    required this.isSuperAdmin,
    required this.profile,
    required this.onSelectTab,
    required this.onProfileUpdated,
  });

  final int currentIndex;
  final bool isSuperAdmin;
  final UserProfile profile;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<UserProfile> onProfileUpdated;

  static const _tabTitles = ['Cursos', 'En Vivo', 'Profesores', 'Insumos'];
  static const _tabIcons = [
    Icons.dashboard_rounded,
    Icons.sensors_rounded,
    Icons.badge_rounded,
    Icons.monetization_on_rounded,
  ];

  static const _superAdminLinks = [
    ('/student', Icons.school_outlined, AppTheme.primary, 'Módulo Alumnos'),
    (
      '/teacher',
      Icons.badge_outlined,
      AppTheme.secondary,
      'Módulo Docente (Profesores)',
    ),
    (
      '/superadmin',
      Icons.admin_panel_settings_outlined,
      AppTheme.primary,
      'Centro de Control Super Admin',
    ),
    (
      '/superadmin/configuracion',
      Icons.settings_outlined,
      AppTheme.outline,
      'Ajustes y Configuración',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.onSurface;
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: AppTheme.dynamicCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.dynamicBorder),
          ),
        ),
      ),
      child: PopupMenuButton<dynamic>(
        tooltip: 'Menú de opciones y navegación',
        offset: const Offset(0, 48),
        onSelected: (value) async {
          if (value is int) {
            onSelectTab(value);
          } else if (value == 'profile') {
            final updated = await ProfileModal.show(
              context,
              profile: profile,
              onProfileUpdated: onProfileUpdated,
            );
            if (updated != null) onProfileUpdated(updated);
          } else if (value == 'assistant') {
            MiaAssistantModal.show(
              context,
              profile: profile,
              currentModule: 'coordinacion',
            );
          } else if (value == 'toggle_theme') {
            ThemeController.toggleTheme();
          } else if (value is String) {
            context.go(value);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.dynamicBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_tabIcons[currentIndex], size: 15, color: AppTheme.primary),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 75),
                child: Text(
                  _tabTitles[currentIndex],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dynamicText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: AppTheme.dynamicTextMuted,
              ),
            ],
          ),
        ),
        itemBuilder: (context) => [
          const PopupMenuItem<dynamic>(
            enabled: false,
            child: Text(
              'OPCIONES DE COORDINACIÓN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (int i = 0; i < _tabTitles.length; i++)
            PopupMenuItem<dynamic>(
              value: i,
              child: Row(
                children: [
                  Icon(
                    _tabIcons[i],
                    size: 18,
                    color: currentIndex == i
                        ? AppTheme.primary
                        : AppTheme.dynamicTextMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _tabTitles[i],
                    style: TextStyle(
                      fontWeight: currentIndex == i
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: currentIndex == i
                          ? AppTheme.primary
                          : AppTheme.dynamicText,
                    ),
                  ),
                  if (currentIndex == i) ...[
                    const Spacer(),
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          const PopupMenuDivider(),
          _menuLink('assistant', Icons.smart_toy_rounded, AppTheme.primary,
              'Umby (Soporte Técnico)', surfaceColor),
          _menuLink('/reports', Icons.visibility_rounded, AppTheme.primary,
              'Ver Registros', surfaceColor),
          _menuLink('/inscripciones', Icons.how_to_reg_rounded,
              AppTheme.successGreen, 'Módulo Inscripciones', surfaceColor),
          _menuLink('profile', Icons.person_rounded, AppTheme.mintNeon,
              'Mi Perfil', surfaceColor),
          PopupMenuItem<dynamic>(
            value: 'toggle_theme',
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.themeMode,
              builder: (context, mode, _) {
                final isDark = mode == ThemeMode.dark;
                return Row(
                  children: [
                    Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isDark ? 'Modo Claro' : 'Modo Nocturno',
                      style: TextStyle(color: surfaceColor),
                    ),
                  ],
                );
              },
            ),
          ),
          if (isSuperAdmin) ...[
            const PopupMenuDivider(),
            const PopupMenuItem<dynamic>(
              enabled: false,
              child: Text(
                'NAVEGACIÓN SUPER ADMIN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            for (final item in _superAdminLinks)
              _menuLink(item.$1, item.$2, item.$3, item.$4, null),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<dynamic> _menuLink(
    dynamic value,
    IconData icon,
    Color iconColor,
    String label,
    Color? textColor,
  ) {
    return PopupMenuItem<dynamic>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Text(
            label,
            style: textColor != null ? TextStyle(color: textColor) : null,
          ),
        ],
      ),
    );
  }
}
