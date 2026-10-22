import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/home/presentation/theme/home_theme_colors.dart';

class FloatingBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'label': 'HOME', 'icon': Icons.home_rounded},
      {'label': 'CURSOS', 'icon': Icons.school_rounded},
      {'label': 'ASISTENCIA', 'icon': Icons.event_available_rounded},
      {'label': 'ENCUESTAS', 'icon': Icons.poll_rounded},
    ];

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: HomeThemeColors.navBarGradient,
        border: Border.all(color: Colors.white12, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final isSelected = index == currentIndex;
          final item = items[index];

          return GestureDetector(
            onTap: () => onTabSelected(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Contenedor del ícono
                  isSelected
                      ? Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HomeThemeColors.activeIconContainer,
                            boxShadow: [
                              BoxShadow(
                                color: HomeThemeColors.accentPink.withValues(alpha: 0.55),
                                blurRadius: 14,
                                spreadRadius: 2,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            size: 22,
                            color: Colors.white,
                          ),
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(
                            item['icon'] as IconData,
                            size: 22,
                            color: Colors.white54,
                          ),
                        ),

                  const SizedBox(height: 4),

                  // Texto del Tab
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      letterSpacing: 0.5,
                      color: isSelected ? Colors.white : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
