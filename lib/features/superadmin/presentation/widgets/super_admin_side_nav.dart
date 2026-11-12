import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_theme_tokens.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Navigation item metadata for the Super Admin desktop sidebar.
class SuperAdminNavItem {
  const SuperAdminNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

const List<SuperAdminNavItem> superAdminNavItems = [
  SuperAdminNavItem(icon: Symbols.dashboard, label: 'General'),
  SuperAdminNavItem(icon: Symbols.school, label: 'Alumnos'),
  SuperAdminNavItem(icon: Symbols.badge, label: 'Profesores'),
  SuperAdminNavItem(icon: Symbols.military_tech, label: 'Coord.'),
  SuperAdminNavItem(icon: Symbols.settings, label: 'Ajustes'),
];

/// Persistent desktop sidebar navigation for the Super Admin dashboard.
class SuperAdminSideNav extends StatelessWidget {
  const SuperAdminSideNav({
    super.key,
    required this.screenHeight,
    required this.currentIndex,
    required this.onSelectIndex,
    required this.onSignOut,
  });

  final double screenHeight;
  final int currentIndex;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: screenHeight,
      decoration: const BoxDecoration(
        color: SuperAdminTokens.card,
        border: Border(right: BorderSide(color: SuperAdminTokens.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [SuperAdminTokens.accent, AppTheme.primary],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: SuperAdminTokens.accentGlow,
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Symbols.shield_person,
                      color: AppTheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Image.asset(
                    'assets/images/logo-umbral.png',
                    height: 38,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Super Admin',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: SuperAdminTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: SuperAdminTokens.border, height: 1),
            const SizedBox(height: 12),
            for (int i = 0; i < superAdminNavItems.length; i++)
              _SideNavTile(
                icon: superAdminNavItems[i].icon,
                label: superAdminNavItems[i].label,
                isSelected: currentIndex == i,
                onTap: () => onSelectIndex(i),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: onSignOut,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: SuperAdminTokens.cardInner,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SuperAdminTokens.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Symbols.logout,
                        size: 18,
                        color: SuperAdminTokens.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Cerrar sesión',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: SuperAdminTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideNavTile extends StatelessWidget {
  const _SideNavTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? SuperAdminTokens.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: SuperAdminTokens.accent.withValues(alpha: 0.25),
                  )
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? SuperAdminTokens.accent
                    : SuperAdminTokens.textMuted,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? SuperAdminTokens.accent
                      : SuperAdminTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
