import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Barra de navegación inferior persistente de Super Admin.
/// Permanece visible y fija en Super Admin y todos sus submódulos
/// (General, Alumnos, Profesores, Coordinación, Ajustes).
class SuperAdminBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const SuperAdminBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  static const Color _cCard = AppTheme.surfaceContainerLow;
  static const Color _cBorder = AppTheme.outlineVariant;
  static const Color _cAccent = AppTheme.primaryContainer;
  static const Color _cTextMuted = AppTheme.onSurfaceVariant;

  static const _navItems = [
    (icon: Symbols.dashboard, label: 'General', route: '/superadmin'),
    (icon: Symbols.school, label: 'Alumnos', route: '/student'),
    (icon: Symbols.badge, label: 'Profesores', route: '/teacher'),
    (icon: Symbols.military_tech, label: 'Coord.', route: '/coordinator'),
    (icon: Symbols.settings, label: 'Ajustes', route: '/superadmin/configuracion'),
  ];

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    context.go(_navItems[index].route);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cCard.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: _cBorder.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_navItems.length, (index) {
            final item = _navItems[index];
            final isSelected = index == currentIndex;

            return InkWell(
              onTap: () => _onTap(context, index),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _cAccent.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: _cAccent.withValues(alpha: 0.35))
                      : Border.all(color: Colors.transparent),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: isSelected ? _cAccent : _cTextMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? _cAccent : _cTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
