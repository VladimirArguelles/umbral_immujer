import 'package:flutter/material.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/features/auth/data/auth_repository.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';
import 'package:umbral_immujer/src/features/alumnos/presentation/alumno_home_screen.dart';
import 'package:umbral_immujer/src/features/profesores/presentation/profesor_home_screen.dart';
import 'package:umbral_immujer/src/features/coordinadores/presentation/coordinador_home_screen.dart';
import 'auth_form_styles.dart';

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
  String _documentType = 'V';
  bool _isLoading = false;
  bool _isValidatingCedula = false;
  bool _cedulaValidated = false;
  bool _obscurePassword = true;
  String? _validationMessage;

  late final AuthRepository _authRepo;

  @override
  void initState() {
    super.initState();
    _authRepo = AuthRepository(SupabaseConfig.client);
  }

  /// Valida en tiempo real si la persona está en el padrón oficial antes de registrarse
  Future<void> _validatePreRegistration() async {
    final documentNumber = _cedulaController.text.trim();
    final documentError = _validateDocument(documentNumber);
    if (documentError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(documentError)),
      );
      return;
    }
    final document = '$_documentType$documentNumber';

    setState(() {
      _isValidatingCedula = true;
      _validationMessage = null;
    });

    try {
      if (_selectedRole == UserRole.alumno) {
        final data = await _authRepo.checkAlumnoPreRegistered(
          cedula: document,
        );
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
            _validationMessage =
                'Acceso denegado: El documento $document no se encuentra registrado en el padrón de alumnos.';
          });
        }
      } else if (_selectedRole == UserRole.profesor) {
        final data = await _authRepo.checkProfesorPreRegistered(
          cedula: document,
        );
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
            _validationMessage =
                'Acceso denegado: El documento $document no se encuentra registrado como docente autorizado.';
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

  String? _validateDocument(String? value) {
    final document = value?.trim() ?? '';
    if (document.isEmpty) {
      return _documentType == 'V'
          ? 'Ingresa tu cédula'
          : 'Ingresa tu número de pasaporte';
    }

    final isValid = _documentType == 'V'
        ? RegExp(r'^\d{5,12}$').hasMatch(document)
        : RegExp(r'^[A-Za-z0-9]{5,20}$').hasMatch(document);
    if (!isValid) {
      return _documentType == 'V'
          ? 'Ingresa una cédula válida (5 a 12 dígitos)'
          : 'Ingresa un pasaporte válido (5 a 20 letras o números)';
    }
    return null;
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
        cedula: '$_documentType${_cedulaController.text.trim()}',
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
      backgroundColor: const Color(0xFF0D0714),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
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
                                'Registrarse',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Crea tu cuenta en la plataforma',
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
                      const Text(
                        'Validación de Padrón Institucional',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Solo personas previamente autorizadas por IMMUJER pueden registrarse en la plataforma.',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      Text('Tipo de cuenta', style: AuthFormStyles.labelStyle),
                      const SizedBox(height: 6),
                      SegmentedButton<UserRole>(
                        style: SegmentedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: AuthFormStyles.panel,
                          selectedForegroundColor: Colors.white,
                          selectedBackgroundColor: AuthFormStyles.neonAccent,
                          side: const BorderSide(
                            color: AuthFormStyles.softAccent,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: UserRole.alumno,
                            label: Text('Alumno'),
                          ),
                          ButtonSegment(
                            value: UserRole.profesor,
                            label: Text('Profesor'),
                          ),
                          ButtonSegment(
                            value: UserRole.coordinador,
                            label: Text('Coordinador'),
                          ),
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
                      const SizedBox(height: 16),
                      Text(
                        'Documento de Identidad',
                        style: AuthFormStyles.labelStyle,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AuthFormStyles.panel,
                              border: Border.all(
                                color: AuthFormStyles.softAccent,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _documentType,
                                dropdownColor: AuthFormStyles.panel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: AuthFormStyles.softAccent,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'V',
                                    child: Text('V - Cédula'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'P',
                                    child: Text('P - Pasaporte'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _documentType = value;
                                    _cedulaValidated = false;
                                    _validationMessage = null;
                                  });
                                  _formKey.currentState?.validate();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _cedulaController,
                              keyboardType: _documentType == 'V'
                                  ? TextInputType.number
                                  : TextInputType.text,
                              style: const TextStyle(color: Colors.white),
                              decoration: AuthFormStyles.inputDecoration(
                                hintText: _documentType == 'V'
                                    ? 'Número de cédula'
                                    : 'Número de pasaporte',
                                prefixIcon: Icons.badge_outlined,
                              ),
                              validator: _validateDocument,
                              onChanged: (_) {
                                if (_cedulaValidated ||
                                    _validationMessage != null) {
                                  setState(() {
                                    _cedulaValidated = false;
                                    _validationMessage = null;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: ElevatedButton(
                              style: AuthFormStyles.actionButtonStyle.copyWith(
                                padding: WidgetStateProperty.all(
                                  const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                              onPressed: _isValidatingCedula
                                  ? null
                                  : _validatePreRegistration,
                              child: _isValidatingCedula
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
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
                              color: _cedulaValidated
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _cedulaValidated
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: _cedulaValidated
                                    ? AppTheme.successGreen
                                    : const Color(0xFFFF6B7A),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _validationMessage!,
                                  style: TextStyle(
                                    color: _cedulaValidated
                                        ? const Color(0xFF7FE3A0)
                                        : const Color(0xFFFF9AA2),
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
                      Text('Nombre Completo', style: AuthFormStyles.labelStyle),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nombreController,
                        style: const TextStyle(color: Colors.white),
                        decoration: AuthFormStyles.inputDecoration(
                          hintText: 'Tu nombre completo',
                          prefixIcon: Icons.person_outline,
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty)
                            ? 'Ingresa tu nombre'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Text('Teléfono', style: AuthFormStyles.labelStyle),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _telefonoController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: AuthFormStyles.inputDecoration(
                          hintText: 'Número de teléfono',
                          prefixIcon: Icons.phone_outlined,
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty)
                            ? 'Ingresa tu teléfono'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Text('Correo Electrónico', style: AuthFormStyles.labelStyle),
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
                            return 'Ingresa tu correo';
                          }
                          if (!val.contains('@')) return 'Correo inválido';
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
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: AuthFormStyles.actionButtonStyle,
                        onPressed: _isLoading ? null : _handleRegister,
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
                                    'REGISTRARSE',
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
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushReplacementNamed('/login'),
                          child: RichText(
                            text: const TextSpan(
                              text: '¿Ya tienes cuenta? ',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Inicia sesión',
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
