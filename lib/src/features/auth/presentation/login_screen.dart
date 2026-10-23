import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/features/auth/data/auth_repository.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';
import 'package:umbral_immujer/src/features/alumnos/presentation/alumno_home_screen.dart';
import 'package:umbral_immujer/src/features/profesores/presentation/profesor_home_screen.dart';
import 'package:umbral_immujer/src/features/coordinadores/presentation/coordinador_home_screen.dart';
import 'package:umbral_immujer/src/features/auth/presentation/register_screen.dart';
import 'auth_form_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AuthRepository _authRepo;

  @override
  void initState() {
    super.initState();
    _authRepo = AuthRepository(SupabaseConfig.client);
    _checkExistingSession();
  }

  void _checkExistingSession() async {
    final profile = await _authRepo.getCurrentProfile();
    if (profile != null && mounted) {
      _navigateToRoleHome(profile);
    }
  }

  void _navigateToRoleHome(UserProfile profile) {
    Widget destination;
    switch (profile.role) {
      case UserRole.alumno:
        destination = AlumnoHomeScreen(profile: profile);
        break;
      case UserRole.profesor:
        destination = ProfesorHomeScreen(profile: profile);
        break;
      case UserRole.coordinador:
        destination = CoordinadorHomeScreen(profile: profile);
        break;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profile = await _authRepo.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        _navigateToRoleHome(profile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0714),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AuthFormStyles.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Ingresa con el correo de tu cuenta',
                                style: TextStyle(
                                  color: AuthFormStyles.softAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: 'Volver',
                            icon: const Icon(
                              Icons.close,
                              color: AuthFormStyles.softAccent,
                            ),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Correo electrónico', style: AuthFormStyles.labelStyle),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: AuthFormStyles.inputDecoration(
                          hintText: 'correo@ejemplo.com',
                          prefixIcon: Icons.mail_outline,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingresa tu correo electrónico';
                          }
                          if (!val.contains('@')) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Text('Contraseña', style: AuthFormStyles.labelStyle),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: AuthFormStyles.inputDecoration(
                          hintText: '••••••••',
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AuthFormStyles.softAccent,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 6) {
                            return 'La contraseña debe tener al menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: AuthFormStyles.actionButtonStyle,
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'ENTRAR',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: RichText(
                            text: const TextSpan(
                              text: '¿Primera vez en la plataforma? ',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Regístrate aquí',
                                  style: TextStyle(
                                    color: AuthFormStyles.softAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
