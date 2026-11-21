import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Reusable user avatar widget that displays a user's profile picture from [imageUrl].
/// If the URL is null, empty, or fails to load, it falls back to rendering
/// the initial letter of [name] or [fallbackIcon] with styled theme colors.
class AppUserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? fallbackIcon;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final double? fontSize;
  final FontWeight? fontWeight;

  const AppUserAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.fallbackIcon,
    this.border,
    this.boxShadow,
    this.fontSize,
    this.fontWeight = FontWeight.bold,
  });

  bool get _hasValidUrl {
    if (imageUrl == null) return false;
    final trimmed = imageUrl!.trim();
    return trimmed.isNotEmpty &&
        (trimmed.startsWith('http://') || trimmed.startsWith('https://'));
  }

  String _getInitial() {
    if (name == null || name!.trim().isEmpty) return '?';
    final trimmed = name!.trim();
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final bg = backgroundColor ?? AppTheme.primary.withValues(alpha: 0.15);
    final fg = foregroundColor ?? AppTheme.primary;
    final fSize = fontSize ?? (radius * 0.75);

    Widget fallbackWidget = Container(
      width: size,
      height: size,
      color: bg,
      alignment: Alignment.center,
      child: fallbackIcon != null
          ? Icon(fallbackIcon, size: fSize, color: fg)
          : Text(
              _getInitial(),
              style: TextStyle(
                color: fg,
                fontWeight: fontWeight,
                fontSize: fSize,
              ),
            ),
    );

    Widget content;
    if (_hasValidUrl) {
      content = Image.network(
        imageUrl!.trim(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallbackWidget,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return fallbackWidget;
        },
      );
    } else {
      content = fallbackWidget;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: border,
        boxShadow: boxShadow,
      ),
      child: ClipOval(
        child: content,
      ),
    );
  }
}
