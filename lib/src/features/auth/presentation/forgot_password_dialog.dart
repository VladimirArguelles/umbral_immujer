import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/features/auth/data/auth_repository.dart';

import 'auth_form_styles.dart';

class ForgotPasswordDialog extends StatefulWidget {
  final AuthRepository authRepository;
  final String? initialValue;

  const ForgotPasswordDialog({
    super.key,
    required this.authRepository,
    this.initialValue,
  });

  static Future<void> show(
    BuildContext context, {
    required AuthRepository authRepository,
    String? initialValue,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ForgotPasswordDialog(
        authRepository: authRepository,
        initialValue: initialValue,
      ),
    );
  }

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

enum _RecoveryStep { input, success, otpReset }

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _inputController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _RecoveryStep _currentStep = _RecoveryStep.input;
  bool _isLoading = false;
  String? _errorMessage;
  String _sentEmail = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue!.trim().isNotEmpty) {
      _inputController.text = widget.initialValue!.trim();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}*@$domain';
    }
    final prefix = name.substring(0, 2);
    final masked = '*' * (name.length - 2).clamp(3, 8);
    return '$prefix$masked@$domain';
  }

  Future<void> _handleSendResetEmail() async {
    final query = _inputController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa tu correo electrónico o tu número de cédula.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final emailResolved = await widget.authRepository.sendPasswordResetEmail(query);
      if (mounted) {
        setState(() {
          _sentEmail = emailResolved;
          _currentStep = _RecoveryStep.success;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleVerifyOtpAndReset() async {
    final token = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (token.isEmpty) {
      setState(() => _errorMessage = 'Por favor ingresa el código recibido en tu correo.');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _errorMessage = 'La nueva contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.verifyOtpAndResetPassword(
        email: _sentEmail,
        token: token,
        newPassword: newPassword,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Contraseña actualizada correctamente. Ya puedes iniciar sesión.'),
                ),
              ],
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AuthFormStyles.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.outlineVariant),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              switch (_currentStep) {
                _RecoveryStep.input => _buildInputStep(),
                _RecoveryStep.success => _buildSuccessStep(),
                _RecoveryStep.otpReset => _buildOtpResetStep(),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AuthFormStyles.panel,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: AuthFormStyles.neonAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Recuperar Contraseña',
                  style: TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close, color: AuthFormStyles.softAccent),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Ingresa el correo electrónico o la cédula con la que te registraste. Te enviaremos un correo a tu cuenta con las instrucciones y el código de recuperación.',
          style: TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Correo electrónico o Cédula',
          style: AuthFormStyles.labelStyle,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _inputController,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppTheme.onSurface),
          decoration: AuthFormStyles.inputDecoration(
            hintText: 'ejemplo@gmail.com o V-12345678',
            prefixIcon: Icons.alternate_email_rounded,
            suffixIcon: _inputController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: AuthFormStyles.softAccent),
                    onPressed: () => setState(() => _inputController.clear()),
                  )
                : null,
          ),
          onSubmitted: (_) => _handleSendResetEmail(),
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          style: AuthFormStyles.actionButtonStyle,
          onPressed: _isLoading ? null : _handleSendResetEmail,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.onPrimary,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'ENVIAR CORREO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AuthFormStyles.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AuthFormStyles.neonAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.mark_email_read_rounded,
                color: AuthFormStyles.neonAccent,
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                '¡Correo enviado con éxito!',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Hemos enviado el enlace y código de recuperación al correo:\n',
                    ),
                    TextSpan(
                      text: _maskEmail(_sentEmail),
                      style: const TextStyle(
                        color: AuthFormStyles.neonAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(
                      text: '\n\nRevisa tu bandeja de entrada o la carpeta de spam / correo no deseado.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          style: AuthFormStyles.actionButtonStyle,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'ENTENDIDO, REVISARÉ MI CORREO',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            setState(() {
              _errorMessage = null;
              _currentStep = _RecoveryStep.otpReset;
            });
          },
          child: const Text(
            '¿Ya recibiste el código? Ingrésalo aquí',
            style: TextStyle(
              color: AuthFormStyles.softAccent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpResetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Introduce el código de verificación que llegó a ${_maskEmail(_sentEmail)} y define tu nueva contraseña.',
          style: const TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        const Text('Código de Verificación (OTP)', style: AuthFormStyles.labelStyle),
        const SizedBox(height: 4),
        TextField(
          controller: _otpController,
          enabled: !_isLoading,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.onSurface, letterSpacing: 2),
          decoration: AuthFormStyles.inputDecoration(
            hintText: 'Ej. 123456',
            prefixIcon: Icons.pin_outlined,
          ),
        ),
        const SizedBox(height: 12),
        const Text('Nueva Contraseña', style: AuthFormStyles.labelStyle),
        const SizedBox(height: 4),
        TextField(
          controller: _newPasswordController,
          enabled: !_isLoading,
          obscureText: _obscurePassword,
          style: const TextStyle(color: AppTheme.onSurface),
          decoration: AuthFormStyles.inputDecoration(
            hintText: 'Mínimo 6 caracteres',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AuthFormStyles.softAccent,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Confirmar Nueva Contraseña', style: AuthFormStyles.labelStyle),
        const SizedBox(height: 4),
        TextField(
          controller: _confirmPasswordController,
          enabled: !_isLoading,
          obscureText: _obscureConfirmPassword,
          style: const TextStyle(color: AppTheme.onSurface),
          decoration: AuthFormStyles.inputDecoration(
            hintText: 'Repite la nueva contraseña',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                color: AuthFormStyles.softAccent,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          style: AuthFormStyles.actionButtonStyle,
          onPressed: _isLoading ? null : _handleVerifyOtpAndReset,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.onPrimary,
                  ),
                )
              : const Text(
                  'ACTUALIZAR CONTRASEÑA',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _errorMessage = null;
                    _currentStep = _RecoveryStep.success;
                  });
                },
          child: const Text(
            'Volver al paso anterior',
            style: TextStyle(color: AuthFormStyles.softAccent, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
