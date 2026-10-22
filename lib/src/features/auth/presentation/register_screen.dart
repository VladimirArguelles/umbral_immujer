import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/features/auth/data/auth_repository.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';
import 'package:umbral_immujer/src/features/alumnos/presentation/alumno_home_screen.dart';
import 'package:umbral_immujer/src/features/profesores/presentation/profesor_home_screen.dart';
import 'package:umbral_immujer/src/features/coordinadores/presentation/coordinador_home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cedulaController = TextEditingController();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.alumno;
  bool _isLoading = false;
  bool _isValidatingCedula = false;
  bool _cedulaValidated = false;
  String? _validationMessage;

  late final AuthRepository _authRepo;

  @override
  void initState() {
    super.initState();
    _authRepo = AuthRepository(SupabaseConfig.client);
  }

  /// Valida en tiempo real si la persona está en el padrón oficial antes de registrarse
  Future<void> _validatePreRegistration() async {
    final cedula = _cedulaController.text.trim();
    if (cedula.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa tu número de cédula')),
      );
      return;
    }

    setState(() {
      _isValidatingCedula = true;
      _validationMessage = null;
    });

    try {
      if (_selectedRole == UserRole.alumno) {
        final data = await _authRepo.checkAlumnoPreRegistered(cedula: cedula);
        if (data != null) {
          setState(() {
            _cedulaValidated = true;
            _nombreController.text = data['nombre_completo'] ?? '';
            _telefonoController.text = data['telefono'] ?? '';
            if (data['correo'] != null && data['correo'].toString().isNotEmpty) {
              _emailController.text = data['correo'];
            }
            _validationMessage = '¡Identidad verificada en el padrón de alumnos de IMMUJER!';
          });
        } else {
          setState(() {
            _cedulaValidated = false;
            _validationMessage = 'Acceso Denegado: La cédula $cedula no se encuentra registrada en el padrón de alumnos.';
          });
        }
      } else if (_selectedRole == UserRole.profesor) {
        final data = await _authRepo.checkProfesorPreRegistered(cedula: cedula);
        if (data != null) {
          setState(() {
            _cedulaValidated = true;
            _nombreController.text = data['nombre_completo'] ?? '';
            _telefonoController.text = data['telefono'] ?? '';
            if (data['correo'] != null && data['correo'].toString().isNotEmpty) {
              _emailController.text = data['correo'];
            }
            _validationMessage = '¡Identidad docente verificada!';
          });
        } else {
          setState(() {
            _cedulaValidated = false;
            _validationMessage = 'Acceso Denegado: La cédula $cedula no se encuentra registrada como docente autorizado.';
          });
        }
      } else {
        // Coordinador
        setState(() {
          _cedulaValidated = true;
          _validationMessage = 'Registro de rol administrativo/coordinador.';
        });
      }
    } catch (e) {
      setState(() {
        _validationMessage = 'Error al validar: $e';
      });
    } finally {
      setState(() => _isValidatingCedula = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole != UserRole.coordinador && !_cedulaValidated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes verificar tu cédula en el padrón antes de registrarte.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profile = await _authRepo.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        cedula: _cedulaController.text.trim(),
        nombreCompleto: _nombreController.text.trim(),
        telefono: _telefonoController.text.trim(),
        role: _selectedRole,
      );

      if (mounted) {
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

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => destination),
          (route) => false,
        );
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
    _cedulaController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro en UMBRAL'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Validación de Padrón Institucional',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Solo personas previamente autorizadas por IMMUJER pueden registrarse en la plataforma.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 20),

                // Selector de Rol
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(value: UserRole.alumno, label: Text('Alumno')),
                    ButtonSegment(value: UserRole.profesor, label: Text('Profesor')),
                    ButtonSegment(value: UserRole.coordinador, label: Text('Coordinador')),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (val) {
                    setState(() {
                      _selectedRole = val.first;
                      _cedulaValidated = false;
                      _validationMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Cédula con botón de verificación
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cedulaController,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'Cédula de Identidad',
                          prefixIcon: Icon(Icons.badge_outlined),
                          hintText: 'Ej: 21210110',
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        onPressed: _isValidatingCedula ? null : _validatePreRegistration,
                        child: _isValidatingCedula
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Verificar'),
                      ),
                    ),
                  ],
                ),

                if (_validationMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _cedulaValidated
                          ? const Color(0x1F388E3C)
                          : const Color(0x1FD32F2F),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _cedulaValidated ? AppTheme.successGreen : AppTheme.errorRed,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _cedulaValidated ? Icons.check_circle : Icons.error_outline,
                          color: _cedulaValidated ? AppTheme.successGreen : AppTheme.errorRed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _validationMessage!,
                            style: TextStyle(
                              color: _cedulaValidated ? AppTheme.successGreen : AppTheme.errorRed,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Nombre Completo
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                ),
                const SizedBox(height: 16),

                // Teléfono
                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa tu teléfono' : null,
                ),
                const SizedBox(height: 16),

                // Correo Electrónico
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Ingresa tu correo';
                    if (!val.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña de Acceso',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Botón Registrarse
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Completar Registro'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
