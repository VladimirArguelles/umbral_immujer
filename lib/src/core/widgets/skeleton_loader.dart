import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Shimmer effect provider using a synchronized sweep animation
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFF1E222D),
    this.highlightColor = const Color(0xFF2E3547),
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              colors: [
                widget.baseColor,
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
                widget.baseColor,
              ],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}

/// Primitive Skeleton Box
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    Widget box = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xFF222633),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
    return box;
  }
}

/// Primitive Skeleton Circle for Avatars and Icons
class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const SkeletonCircle({
    super.key,
    this.size = 40,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: const BoxDecoration(
        color: Color(0xFF222633),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADAPTIVE SKELETON SCREENS
// ═══════════════════════════════════════════════════════════════════════════

/// Skeleton Screen for Courses list matching `GestionCursosPage` and Student courses
class CoursesSkeleton extends StatelessWidget {
  final int itemCount;
  const CoursesSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonCircle(size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        SkeletonBox(width: 160, height: 16),
                        SkeletonBox(width: 60, height: 20, borderRadius: 6),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const SkeletonBox(width: double.infinity, height: 12),
                    const SizedBox(height: 6),
                    const SkeletonBox(width: 200, height: 12),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        SkeletonBox(width: 90, height: 16),
                        SizedBox(width: 12),
                        SkeletonBox(width: 110, height: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton Screen for Attendance list matching `_PaseListaTab` and `_MisAsistenciasTab`
class AttendanceSkeleton extends StatelessWidget {
  final int itemCount;
  const AttendanceSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              const SkeletonCircle(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 140, height: 14),
                    SizedBox(height: 6),
                    SkeletonBox(width: 90, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: const [
                  SkeletonBox(width: 32, height: 32, borderRadius: 8),
                  SizedBox(width: 6),
                  SkeletonBox(width: 32, height: 32, borderRadius: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton Screen for Surveys and Contributions list matching `_EncuestasAportesTab`
class SurveysSkeleton extends StatelessWidget {
  final int itemCount;
  const SurveysSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonBox(width: 140, height: 16),
                  SkeletonBox(width: 70, height: 22, borderRadius: 8),
                ],
              ),
              const SizedBox(height: 8),
              const SkeletonBox(width: 110, height: 12),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 150, height: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 120, height: 28),
                    SizedBox(height: 10),
                    SkeletonBox(width: double.infinity, height: 12),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const SkeletonBox(width: double.infinity, height: 42, borderRadius: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton Screen for Super Admin Metrics and Modules Grid
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Row(
              children: [
                const SkeletonCircle(size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 160, height: 18),
                      SizedBox(height: 8),
                      SkeletonBox(width: 220, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Metrics Cards Skeleton
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 110, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 110, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 110, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 110, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 20),
          // Modules list skeleton
          for (int i = 0; i < 3; i++) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Row(
                children: const [
                  SkeletonBox(width: 44, height: 44, borderRadius: 12),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 130, height: 14),
                        SizedBox(height: 6),
                        SkeletonBox(width: 180, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
