import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/home/presentation/theme/home_theme_colors.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

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

    final borderRadius = BorderRadius.circular(40);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            offset: Offset(0, 10),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Color(0x0DFFFFFF),
            offset: Offset(0, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer.withValues(alpha: 0.92),
              borderRadius: borderRadius,
              border: Border.all(
                color: AppTheme.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final isSelected = index == currentIndex;
                final item = items[index];

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTabSelected(index),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isSelected
                                    ? [
                                        HomeThemeColors.accentPink,
                                        AppTheme.primary,
                                      ]
                                    : [
                                        AppTheme.surfaceContainerHigh,
                                        AppTheme.surfaceContainerLowest,
                                      ],
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: HomeThemeColors.accentPink
                                            .withValues(alpha: 0.6),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [
                                      const BoxShadow(
                                        color: Color(0x99000000),
                                        offset: Offset(2, 2),
                                        blurRadius: 4,
                                      ),
                                      const BoxShadow(
                                        color: Color(0x0DFFFFFF),
                                        offset: Offset(-1, -1),
                                        blurRadius: 3,
                                      ),
                                    ],
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              color: isSelected
                                  ? AppTheme.onPrimary
                                  : AppTheme.onSurfaceVariant,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item['label'] as String,
                              maxLines: 1,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                letterSpacing: 0.4,
                                color: isSelected
                                    ? AppTheme.onSurface
                                    : AppTheme.onSurfaceVariant,
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
        ),
      ),
    );
  }
}
