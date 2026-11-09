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

  static Color get _cCard => AppTheme.dynamicCard;
  static Color get _cBorder => AppTheme.dynamicBorder;
  static const Color _cAccent = AppTheme.primaryContainer;
  static Color get _cTextMuted => AppTheme.dynamicTextMuted;

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark ? 0.4 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_navItems.length, (index) {
            final item = _navItems[index];
            final isSelected = index == currentIndex;

            return Expanded(
              child: InkWell(
                onTap: () => _onTap(context, index),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _cAccent.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(color: _cAccent.withValues(alpha: 0.35), width: 1)
                              : null,
                        ),
                        child: Icon(
                          item.icon,
                          size: 22,
                          color: isSelected ? _cAccent : _cTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            color: isSelected ? _cAccent : _cTextMuted,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
