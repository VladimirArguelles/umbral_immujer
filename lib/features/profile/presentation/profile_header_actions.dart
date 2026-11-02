import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/profile/presentation/profile_modal.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class ThemeModeToggleButton extends StatelessWidget {
  const ThemeModeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: isDark ? const Color(0xFFFFD166) : AppTheme.primary,
            size: 20,
          ),
          tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo nocturno',
          onPressed: ThemeController.toggleTheme,
        );
      },
    );
  }
}

class UserProfileAvatarButton extends StatelessWidget {
  final UserProfile profile;
  final ValueChanged<UserProfile>? onProfileUpdated;

  const UserProfileAvatarButton({
    super.key,
    required this.profile,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final initials = profile.fullName.isNotEmpty
        ? profile.fullName
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(right: 6, left: 2),
      child: Tooltip(
        message: 'Mi Perfil • ${profile.fullName}',
        child: InkWell(
          onTap: () async {
            final updated = await ProfileModal.show(
              context,
              profile: profile,
              onProfileUpdated: onProfileUpdated,
            );
            if (updated != null) {
              onProfileUpdated?.call(updated);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.mintNeon, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.mintNeon.withValues(alpha: 0.25),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
                  ? Image.network(
                      profile.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallback(initials),
                    )
                  : _buildFallback(initials),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(String initials) {
    return Container(
      color: AppTheme.primaryContainer.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}
