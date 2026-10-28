import 'dart:math';
import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Fondo estrellado sutil y con gradientes ambientales para la Landing Page
class ParticlesBackground extends StatelessWidget {
  final Widget child;

  const ParticlesBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Stack(
        children: [
          // Luces ambientales difuminadas (Glows púrpuras y magenta)
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondary.withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _StarsPainter(),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  final Random _random = Random(42); // Semilla fija para mantener estrellas estables

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.onSurface;

    // Dibujar 45 partículas/estrellas sutiles difuminadas
    for (int i = 0; i < 45; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final radius = _random.nextDouble() * 1.6 + 0.4;
      final opacity = _random.nextDouble() * 0.45 + 0.1;

      paint.color = AppTheme.onSurface.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
