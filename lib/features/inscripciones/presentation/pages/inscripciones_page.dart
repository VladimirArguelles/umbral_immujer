import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/features/inscripciones/data/inscripciones_repository.dart';
import 'package:umbral_immujer/features/inscripciones/domain/inscripcion_models.dart';
import 'package:umbral_immujer/features/inscripciones/presentation/widgets/aspirante_form_card.dart';
import 'package:umbral_immujer/features/inscripciones/presentation/widgets/curso_cupo_card.dart';
import 'package:umbral_immujer/features/inscripciones/presentation/widgets/inscripciones_admin_panel_widget.dart';
import 'package:umbral_immujer/features/profile/presentation/profile_header_actions.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/features/auth/data/auth_repository.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

/// Módulo principal de Inscripciones y control de cupos en tiempo real.
class InscripcionesPage extends StatefulWidget {
  final UserProfile profile;

  const InscripcionesPage({super.key, required this.profile});

  @override
  State<InscripcionesPage> createState() => _InscripcionesPageState();
}

class _InscripcionesPageState extends State<InscripcionesPage> {
  late final InscripcionesRepository _repository;
  late final AuthRepository _authRepository;

  final _formKey = GlobalKey<FormState>();
  final _cedulaCtrl = TextEditingController();
  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _searchCursoCtrl = TextEditingController();

  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounce;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isCheckingCedula = false;
  bool _inscripcionesActivas = true;
  String? _accessRestrictionReason;
  String? _errorMessage;

  String _documentType = 'V';
  String? _selectedCursoId;
  String _searchQuery = '';
  int _mobileTabIndex = 0;

  String? _duplicateWarning;
  String? _existingStudentHint;

  List<CursoConCupos> _cursos = [];
  List<InscripcionRecienteItem> _recientes = [];

  @override
  void initState() {
    super.initState();
    _repository = InscripcionesRepository(SupabaseConfig.client);
    _authRepository = AuthRepository(SupabaseConfig.client);
    _loadInitialData();
    _realtimeChannel = _repository.subscribeRealtimeUpdates(_scheduleReload);
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    if (_realtimeChannel != null) {
      SupabaseConfig.client.removeChannel(_realtimeChannel!);
    }
    _cedulaCtrl.dispose();
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _searchCursoCtrl.dispose();
    super.dispose();
  }

  void _scheduleReload() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _loadInitialData(silent: true);
      }
    });
  }

  Future<void> _loadInitialData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      UserProfile effectiveProfile = widget.profile;
      if (widget.profile.role == UserRole.operadorInscripcion) {
        final latestProfile = await _authRepository.getCurrentProfile();
        if (latestProfile != null) {
          effectiveProfile = latestProfile;
        }
        final restriction = await _authRepository
            .getOperadorAccessRestrictionReason(effectiveProfile);
        if (restriction != null) {
          if (!mounted) return;
          setState(() {
            _accessRestrictionReason = restriction;
            _isLoading = false;
          });
          return;
        }
      }

      final results = await Future.wait([
        _repository.isInscripcionesActivas(),
        _repository.getCursosConCupos(),
        _repository.getInscripcionesRecientes(limit: 25),
      ]);

      final windowActive = results[0] as bool;
      final cursos = results[1] as List<CursoConCupos>;
      final recientes = results[2] as List<InscripcionRecienteItem>;

      String? nextSelectedCurso = _selectedCursoId;
      if (nextSelectedCurso != null) {
        final match = cursos.where((c) => c.id == nextSelectedCurso);
        if (match.isEmpty || !match.first.puedeInscribir) {
          nextSelectedCurso = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _accessRestrictionReason = null;
        _inscripcionesActivas = windowActive;
        _cursos = cursos;
        _recientes = recientes;
        _selectedCursoId = nextSelectedCurso;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo cargar la información de inscripciones: $e';
      });
    }
  }

  String _formattedCedula() {
    final digits = _cedulaCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return '$_documentType$digits';
  }

  Future<void> _verificarCedulaEnCurso() async {
    final cedula = _formattedCedula();
    final cursoId = _selectedCursoId;
    if (cedula.isEmpty || cursoId == null) {
      setState(() {
        _duplicateWarning = null;
        _existingStudentHint = null;
      });
      return;
    }

    setState(() {
      _isCheckingCedula = true;
      _duplicateWarning = null;
      _existingStudentHint = null;
    });

    try {
      final result = await _repository.verificarCedulaEnCurso(
        cedula: cedula,
        cursoId: cursoId,
      );

      if (!mounted) return;
      setState(() {
        _isCheckingCedula = false;
        if (result.yaInscritoEnCurso) {
          final nombre = result.nombreExistente ?? cedula;
          _duplicateWarning =
              'La persona ($nombre - $cedula) ya posee una inscripción activa en el curso seleccionado.';
          _existingStudentHint = null;
        } else if (result.alumnoId != null) {
          final nombre = result.nombreExistente ?? 'Aspirante registrado';
          _existingStudentHint =
              'Aspirante encontrado en el padrón ($nombre). Se vinculará su nueva inscripción manteniendo su historial.';
          _prefillExistingAlumno(result);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingCedula = false);
      _showSnack(
        'No se pudo verificar la cédula en este momento: $e',
        isError: true,
      );
    }
  }

  void _prefillExistingAlumno(VerificacionCedulaResultado result) {
    final fullName = (result.nombreExistente ?? '').trim();
    if (_nombresCtrl.text.trim().isEmpty &&
        _apellidosCtrl.text.trim().isEmpty &&
        fullName.isNotEmpty) {
      final parts = fullName.split(RegExp(r'\s+'));
      if (parts.length == 1) {
        _nombresCtrl.text = parts.first;
      } else {
        final mid = (parts.length / 2).ceil();
        _nombresCtrl.text = parts.take(mid).join(' ');
        _apellidosCtrl.text = parts.skip(mid).join(' ');
      }
    }
    if (_telefonoCtrl.text.trim().isEmpty &&
        (result.telefonoExistente ?? '').trim().isNotEmpty) {
      _telefonoCtrl.text = result.telefonoExistente!.trim();
    }
    if (_correoCtrl.text.trim().isEmpty &&
        (result.correoExistente ?? '').trim().isNotEmpty) {
      _correoCtrl.text = result.correoExistente!.trim();
    }
  }

  Future<void> _submitInscripcion() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cursoId = _selectedCursoId;
    if (cursoId == null) {
      _showSnack('Selecciona un curso con cupos disponibles.', isError: true);
      return;
    }

    final cedula = _formattedCedula();
    if (cedula.length < 6) {
      _showSnack('Ingresa un número de cédula válido.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final check = await _repository.verificarCedulaEnCurso(
        cedula: cedula,
        cursoId: cursoId,
      );
      if (check.yaInscritoEnCurso) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _duplicateWarning =
              'La cédula $cedula ya se encuentra inscrita en este curso.';
        });
        _showSnack(_duplicateWarning!, isError: true);
        return;
      }

      final result = await _repository.registrarAspirante(
        RegistroAspiranteRequest(
          cursoId: cursoId,
          cedula: cedula,
          nombres: _nombresCtrl.text.trim(),
          apellidos: _apellidosCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim(),
          correo: _correoCtrl.text.trim().toLowerCase(),
        ),
      );

      if (!mounted) return;
      _clearFormKeepingSelectedCurso();
      setState(() => _isSubmitting = false);
      await _loadInitialData(silent: true);

      if (!mounted) return;
      _showSnack(
        'Inscripción registrada: ${result.nombreCompleto} en ${result.cursoNombre} (${result.inscritosActuales}/${result.cupoMaximo}).',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  void _clearFormKeepingSelectedCurso() {
    _cedulaCtrl.clear();
    _nombresCtrl.clear();
    _apellidosCtrl.clear();
    _telefonoCtrl.clear();
    _correoCtrl.clear();
    setState(() {
      _duplicateWarning = null;
      _existingStudentHint = null;
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openAdminControlModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.dynamicBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dynamicBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
                child: Row(
                  children: [
                    const Icon(Symbols.admin_panel_settings,
                        color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Control de Inscripciones y Accesos',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dynamicText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Symbols.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: InscripcionesAdminPanelWidget(
                    onWindowToggled: (_) => _loadInitialData(silent: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _homeRouteForRole(UserRole role) {
    return switch (role) {
      UserRole.superAdmin => '/superadmin',
      UserRole.coordinador => '/coordinator',
      UserRole.profesor => '/teacher',
      UserRole.alumno => '/student',
      UserRole.operadorInscripcion => '/inscripciones',
    };
  }

  Future<void> _signOut() async {
    await _authRepository.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  List<CursoConCupos> get _filteredCursos {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _cursos;
    return _cursos.where((c) {
      return c.nombre.toLowerCase().contains(q) ||
          (c.horario ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isOperador = widget.profile.role == UserRole.operadorInscripcion;
    final isSuperAdmin = widget.profile.role == UserRole.superAdmin;
    final isWide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      backgroundColor: AppTheme.dynamicBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.dynamicBackground,
        elevation: 0,
        leading: isOperador
            ? null
            : IconButton(
                tooltip: 'Volver al panel',
                icon: const Icon(Symbols.arrow_back),
                onPressed: () =>
                    context.go(_homeRouteForRole(widget.profile.role)),
              ),
        title: Row(
          children: [
            const Icon(Symbols.how_to_reg, color: AppTheme.primary, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Módulo de Inscripciones',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.dynamicText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (isSuperAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.14),
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _openAdminControlModal,
                icon: const Icon(Symbols.tune, size: 18),
                label: const Text(
                  'Accesos',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Actualizar cupos',
            icon: const Icon(Symbols.refresh),
            onPressed: () => _loadInitialData(),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Symbols.logout, color: AppTheme.errorRed),
            onPressed: _signOut,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _accessRestrictionReason != null
                ? _buildBlockedAccessView(_accessRestrictionReason!)
                : _errorMessage != null
                    ? _buildErrorView(_errorMessage!)
                    : Column(
                        children: [
                          _buildTopStatusHeader(),
                          Expanded(
                            child: isWide
                                ? _buildDesktopBody()
                                : _buildMobileBody(),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildBlockedAccessView(String reason) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.dynamicCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.errorRed.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Symbols.lock_clock,
                    color: AppTheme.errorRed,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Acceso Temporal Restringido',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.dynamicText,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.dynamicTextMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _signOut,
                    icon: const Icon(Symbols.logout),
                    label: const Text('Cerrar Sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.error, color: AppTheme.errorRed, size: 42),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.dynamicTextMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadInitialData(),
              icon: const Icon(Symbols.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatusHeader() {
    final totalCursos = _cursos.length;
    final disponibles = _cursos.where((c) => c.puedeInscribir).length;
    final agotados = _cursos.where((c) => c.cuposAgotados).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.dynamicSurfaceContainer,
        border: Border(
          bottom: BorderSide(color: AppTheme.dynamicBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserProfileAvatarButton(profile: widget.profile),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile.fullName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.dynamicText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.profile.role.displayName,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.dynamicTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (_inscripcionesActivas
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_inscripcionesActivas
                            ? AppTheme.successGreen
                            : AppTheme.warningOrange)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _inscripcionesActivas
                          ? Symbols.broadcast_on_personal
                          : Symbols.pause_circle,
                      size: 14,
                      color: _inscripcionesActivas
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _inscripcionesActivas
                          ? 'Periodo Activo'
                          : 'Periodo Cerrado',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _inscripcionesActivas
                            ? AppTheme.successGreen
                            : AppTheme.warningOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_inscripcionesActivas &&
              widget.profile.role != UserRole.operadorInscripcion) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.warningOrange.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Symbols.info,
                    size: 16,
                    color: AppTheme.warningOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El periodo temporal está desactivado para operadores externos; el personal interno puede seguir gestionando cupos.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.dynamicText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMetricChip(
                label: 'Cursos activos: $totalCursos',
                color: AppTheme.primary,
              ),
              _buildMetricChip(
                label: 'Con cupos: $disponibles',
                color: AppTheme.successGreen,
              ),
              _buildMetricChip(
                label: 'Agotados: $agotados',
                color: agotados > 0
                    ? AppTheme.errorRed
                    : AppTheme.dynamicTextMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDesktopBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildCursosPanel(),
          ),
        ),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAspiranteForm(),
                const SizedBox(height: 18),
                _buildRecientesSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildMobileTabButton(
                  index: 0,
                  icon: Symbols.person_add,
                  label: 'Inscribir',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileTabButton(
                  index: 1,
                  icon: Symbols.analytics,
                  label: 'Cupos (${_cursos.length})',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileTabButton(
                  index: 2,
                  icon: Symbols.history,
                  label: 'Recientes',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _mobileTabIndex,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: _buildAspiranteForm(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildCursosPanel(),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: _buildRecientesSection(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _mobileTabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _mobileTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.16)
              : AppTheme.dynamicCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.dynamicBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppTheme.primary : AppTheme.dynamicTextMuted,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppTheme.primary : AppTheme.dynamicText,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAspiranteForm() {
    return AspiranteFormCard(
      formKey: _formKey,
      cedulaController: _cedulaCtrl,
      nombresController: _nombresCtrl,
      apellidosController: _apellidosCtrl,
      telefonoController: _telefonoCtrl,
      correoController: _correoCtrl,
      documentType: _documentType,
      onDocumentTypeChanged: (val) {
        setState(() => _documentType = val);
        if (_cedulaCtrl.text.trim().length >= 6 && _selectedCursoId != null) {
          _verificarCedulaEnCurso();
        }
      },
      cursos: _cursos,
      selectedCursoId: _selectedCursoId,
      onCursoChanged: (val) {
        setState(() {
          _selectedCursoId = val;
          _duplicateWarning = null;
        });
        if (val != null && _cedulaCtrl.text.trim().length >= 6) {
          _verificarCedulaEnCurso();
        }
      },
      isSubmitting: _isSubmitting,
      isCheckingCedula: _isCheckingCedula,
      canSubmit: _selectedCursoId != null &&
          _cursos.any((c) => c.id == _selectedCursoId && c.puedeInscribir),
      duplicateWarning: _duplicateWarning,
      existingStudentHint: _existingStudentHint,
      onCheckCedula: _verificarCedulaEnCurso,
      onSubmit: _submitInscripcion,
    );
  }

  Widget _buildCursosPanel() {
    final filtered = _filteredCursos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCursoCtrl,
          style: TextStyle(color: AppTheme.dynamicText),
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Buscar curso u horario...',
            prefixIcon: const Icon(Symbols.search, size: 20),
            isDense: true,
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Symbols.close, size: 18),
                    onPressed: () {
                      _searchCursoCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No hay cursos que coincidan con tu búsqueda.',
                    style: TextStyle(
                      color: AppTheme.dynamicTextMuted,
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final curso = filtered[index];
                    return CursoCupoCard(
                      curso: curso,
                      isSelected: curso.id == _selectedCursoId,
                      onTap: () {
                        setState(() {
                          _selectedCursoId = curso.id;
                          _duplicateWarning = null;
                          _mobileTabIndex = 0;
                        });
                        if (_cedulaCtrl.text.trim().length >= 6) {
                          _verificarCedulaEnCurso();
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecientesSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.history_edu, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Últimas Inscripciones Registradas',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.dynamicText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${_recientes.length}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dynamicTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recientes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aún no hay inscripciones recientes para mostrar.',
                style: TextStyle(
                  color: AppTheme.dynamicTextMuted,
                  fontSize: 12.5,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recientes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final item = _recientes[index];
                final isForm = item.origen == 'formulario';
                final badgeColor =
                    isForm ? AppTheme.successGreen : AppTheme.secondary;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.dynamicSurfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dynamicBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.alumnoNombre,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.dynamicText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.cedula} • ${item.cursoNombre}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.dynamicTextMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isForm ? 'Formulario' : 'Histórico',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
