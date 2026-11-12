import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/profile/data/profile_repository.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class ProfileModal extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<UserProfile>? onProfileUpdated;

  const ProfileModal({
    super.key,
    required this.profile,
    this.onProfileUpdated,
  });

  static Future<UserProfile?> show(
    BuildContext context, {
    required UserProfile profile,
    ValueChanged<UserProfile>? onProfileUpdated,
  }) {
    return showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileModal(
        profile: profile,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }

  @override
  State<ProfileModal> createState() => _ProfileModalState();
}

class _ProfileModalState extends State<ProfileModal> {
  late final ProfileRepository _profileRepo;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _cedulaCtrl;

  Uint8List? _newAvatarBytes;
  String? _newAvatarExt;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _profileRepo = ProfileRepository(SupabaseConfig.client);
    _nameCtrl = TextEditingController(text: widget.profile.fullName);
    _emailCtrl = TextEditingController(text: widget.profile.email);
    _phoneCtrl = TextEditingController(text: widget.profile.telefono ?? '');
    _cedulaCtrl = TextEditingController(text: widget.profile.cedula ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cedulaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last;
        setState(() {
          _newAvatarBytes = bytes;
          _newAvatarExt = ext;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cambiar Foto de Perfil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Tomar Foto con Cámara'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.mintNeon),
                title: const Text('Seleccionar de la Galería'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? avatarUrl = widget.profile.avatarUrl;

      // 1. Si se seleccionó una nueva imagen, subirla a Supabase Storage
      if (_newAvatarBytes != null && _newAvatarExt != null) {
        final uploadedUrl = await _profileRepo.uploadAvatar(
          userId: widget.profile.id,
          bytes: _newAvatarBytes!,
          fileExtension: _newAvatarExt!,
        );
        if (uploadedUrl != null) {
          avatarUrl = uploadedUrl;
        }
      }

      // 2. Actualizar perfiles y notificar a los roles
      final updatedProfile = await _profileRepo.updateProfile(
        userId: widget.profile.id,
        fullName: _nameCtrl.text,
        email: _emailCtrl.text,
        telefono: _phoneCtrl.text,
        cedula: _cedulaCtrl.text,
        role: widget.profile.role,
        avatarUrl: avatarUrl,
      );

      if (!mounted) return;

      widget.onProfileUpdated?.call(updatedProfile);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.pureWhite),
              SizedBox(width: 8),
              Expanded(
                child: Text('Perfil actualizado. Notificaciones enviadas a profesores y coordinadores.'),
              ),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );

      Navigator.pop(context, updatedProfile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el perfil: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar Sesión?'),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: AppTheme.pureWhite,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _profileRepo.signOut();
      if (mounted) {
        Navigator.pop(context);
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark;
    final surfaceColor = isDark ? AppTheme.surfaceContainerLow : Colors.white;
    final textColor = isDark ? AppTheme.onSurface : const Color(0xFF1E232A);
    final textMuted = isDark ? AppTheme.onSurfaceVariant : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppTheme.outlineVariant : const Color(0xFFE2E8F0),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra de agarre
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Título y Cerrar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mi Perfil',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Avatar con botón de cambio
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.mintNeon,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.mintNeon.withValues(alpha: 0.25),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _newAvatarBytes != null
                              ? Image.memory(
                                  _newAvatarBytes!,
                                  fit: BoxFit.cover,
                                )
                              : (widget.profile.avatarUrl != null &&
                                      widget.profile.avatarUrl!.isNotEmpty)
                                  ? Image.network(
                                      widget.profile.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          _buildAvatarPlaceholder(),
                                    )
                                  : _buildAvatarPlaceholder(),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _showImageSourceSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: surfaceColor, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: AppTheme.pureWhite,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Rol Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      widget.profile.role.displayName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Campo Nombre Completo
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                ),
                const SizedBox(height: 14),

                // Campo Correo Electrónico
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                    if (!v.contains('@') || !v.contains('.')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Campo Teléfono
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Número de Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: 'Ej. 04141234567',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa tu número de teléfono' : null,
                ),
                const SizedBox(height: 14),

                // Campo Cédula
                TextFormField(
                  controller: _cedulaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cédula de Identidad',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 18),

                // Selector de Modo Claro / Nocturno
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.surfaceContainer
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.outlineVariant
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tema Visual',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              isDark ? 'Modo Nocturno activo' : 'Modo Claro activo',
                              style: TextStyle(
                                fontSize: 11,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: !isDark,
                        onChanged: (val) {
                          ThemeController.toggleTheme();
                          setState(() {});
                        },
                        activeThumbColor: AppTheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Botón Guardar Cambios
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.pureWhite,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar Cambios',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    foregroundColor: AppTheme.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón Cambiar Contraseña
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _showChangePasswordDialog,
                  icon: const Icon(
                    Symbols.lock_reset,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  label: const Text(
                    'Cambiar Contraseña',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Botón Cerrar Sesión
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _handleSignOut,
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.errorRed, size: 18),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isUpdating = false;
    String? dialogError;

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: !isUpdating,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.dynamicCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.dynamicBorder),
          ),
          title: Row(
            children: [
              const Icon(Symbols.lock_reset, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cambiar Contraseña',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.dynamicText,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ingresa tu nueva contraseña de acceso (mínimo 6 caracteres).',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.dynamicTextMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: newPasswordCtrl,
                    obscureText: obscureNew,
                    enabled: !isUpdating,
                    style: TextStyle(color: AppTheme.dynamicText),
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña *',
                      prefixIcon: const Icon(Symbols.lock, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 6) {
                        return 'Mínimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordCtrl,
                    obscureText: obscureConfirm,
                    enabled: !isUpdating,
                    style: TextStyle(color: AppTheme.dynamicText),
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña *',
                      prefixIcon: const Icon(Symbols.verified_user, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                        ),
                        onPressed: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim() != newPasswordCtrl.text.trim()) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: const TextStyle(
                        color: AppTheme.errorRed,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
              ),
              onPressed: isUpdating
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isUpdating = true;
                        dialogError = null;
                      });
                      try {
                        await _profileRepo.updatePassword(newPasswordCtrl.text);
                        if (ctx.mounted) Navigator.of(ctx).pop(true);
                      } catch (e) {
                        setDialogState(() {
                          isUpdating = false;
                          dialogError = 'No se pudo actualizar: $e';
                        });
                      }
                    },
              icon: isUpdating
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.onPrimary,
                      ),
                    )
                  : const Icon(Symbols.save, size: 17),
              label: Text(isUpdating ? 'Guardando...' : 'Actualizar'),
            ),
          ],
        ),
      ),
    );

    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada correctamente.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Widget _buildAvatarPlaceholder() {
    final initials = widget.profile.fullName.isNotEmpty
        ? widget.profile.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '?';

    return Container(
      color: AppTheme.primaryContainer.withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}
