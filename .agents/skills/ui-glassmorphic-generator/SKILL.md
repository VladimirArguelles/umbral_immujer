---
name: ui-glassmorphic-generator
description: Generates high-performance glassmorphism, frosted glass, backdrop blur, translucent depth, and glowing gradient UI components in Flutter and web. Use when asked to design glassmorphic cards, translucent floating headers, modal sheets, neon borders, glowing badges, or frosted glass surfaces that perform fluidly at 60/120 FPS.
---

# UI Glassmorphic Generator

This skill guides the design and implementation of modern **Glassmorphism**, frosted glass surfaces, translucent depth layers, and ambient glowing borders in Flutter and modern frontend systems.

---

## The 4 Pillars of Authentic Glassmorphism

1. **Optical Translucency**:
   A multi-layered surface where backgrounds subtly bleed through without compromising text legibility or contrast ratios (WCAG AA).
2. **Backdrop Filtration (`BackdropFilter`)**:
   Surface blur applied exclusively to what lies behind the component (`sigmaX: 10 - 24`, `sigmaY: 10 - 24`).
3. **Specular Border & Light Source**:
   A subtle gradient stroke simulating refractive light on the glass edge (`white with 0.15 - 0.3 opacity` at top-left, fading to `white with 0.03 opacity` at bottom-right).
4. **Subtle Specular Reflection & Shadow**:
   Soft, ambient drop shadows combined with translucent inner fills rather than solid matte fills.

---

## High-Performance Flutter Implementation

In Flutter, backdrop filters can be GPU-heavy if overused or nested incorrectly. Always apply `ClipRRect` and confine the blur boundary strictly to the card geometry.

### 1. Reusable GlassContainer Widget (`lib/core/widgets/glass_container.dart`)

```dart
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final Color baseColor;
  final double baseOpacity;
  final Color borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.blurSigma = 16.0,
    this.baseColor = const Color(0xFF1E1F2A),
    this.baseOpacity = 0.55,
    this.borderColor = Colors.white,
    this.borderWidth = 1.0,
    this.padding = const EdgeInsets.all(20.0),
    this.margin,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: baseOpacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                width: borderWidth,
                color: borderColor.withValues(alpha: 0.14),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

---

## Golden Rules for Mobile & Web Performance

* **Avoid Overdraw / Stacking**: Never nest multiple `BackdropFilter` widgets inside each other (e.g., a glass card inside a glass scroll view). Use a solid translucent tint for nested elements instead.
* **Keep Sigmas Modest**: A sigma range between `12.0` and `20.0` provides optimal frosted diffusion without stalling low-end mobile GPUs.
* **Contrast Safeguards**: Always verify foreground typography contrast against the most colorful background element that could slide underneath the glass pane.
* **Ambient Glow Accent**: Pair neutral frosted cards with vibrant ambient radial glow accents behind them (e.g., deep magenta, cyan, or gold orbs with high blur).
