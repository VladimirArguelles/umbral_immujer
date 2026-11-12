import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/inscripciones/data/inscripciones_repository.dart';
import 'package:umbral_immujer/features/inscripciones/domain/inscripcion_models.dart';
import 'package:umbral_immujer/features/inscripciones/presentation/widgets/cupos_cursos_dialog.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Panel de control para el Super Admin:
/// - Switch para Activar / Desactivar el Periodo de Inscripciones y Accesos Temporales
/// - Selector de fechas de inicio y cierre de inscripciones + botón de cupos por curso
/// - Listado rápido para crear, suspender/reactivar o revocar credenciales de operador_inscripcion
class InscripcionesAdminPanelWidget extends StatefulWidget {
  final ValueChanged<bool>? onWindowToggled;

  const InscripcionesAdminPanelWidget({
    super.key,
    this.onWindowToggled,
  });

  @override
  State<InscripcionesAdminPanelWidget> createState() =>
      _InscripcionesAdminPanelWidgetState();
}

class _InscripcionesAdminPanelWidgetState
    extends State<InscripcionesAdminPanelWidget> {
  late final InscripcionesRepository _repository;

  bool _isLoading = true;
  bool _isTogglingWindow = false;
  bool _isSavingPeriodoDates = false;
  bool _inscripcionesActivas = false;
  bool _activasFlag = false;
  bool _enRangoFechas = true;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  List<OperadorTemporal> _operadores = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = InscripcionesRepository(SupabaseConfig.client);
    _loadControlData();
  }

  Future<void> _loadControlData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.getPeriodoConfig(),
        _repository.getOperadoresTemporales(),
      ]);

      final config = results[0] as InscripcionesPeriodoConfig;
      if (!mounted) return;
      setState(() {
        _inscripcionesActivas = config.activasEfectivo;
        _activasFlag = config.activasFlag;
        _enRangoFechas = config.enRangoFechas;
        _fechaInicio = config.fechaInicio;
        _fechaFin = config.fechaFin;
        _operadores = results[1] as List<OperadorTemporal>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No se pudo cargar el control de inscripciones: $e';
      });
    }
  }

  Future<void> _toggleInscripcionesWindow(bool newValue) async {
    setState(() => _isTogglingWindow = true);
    try {
      final updated = await _repository.setInscripcionesPeriodo(
        activas: newValue,
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
      );
      if (!mounted) return;
      setState(() {
        _activasFlag = updated.activasFlag;
        _inscripcionesActivas = updated.activasEfectivo;
        _enRangoFechas = updated.enRangoFechas;
        _isTogglingWindow = false;
      });
      widget.onWindowToggled?.call(updated.activasEfectivo);
      _showFeedback(
        updated.activasEfectivo
            ? 'Periodo de inscripciones y accesos temporales ACTIVADOS.'
            : (updated.activasFlag && !updated.enRangoFechas)
                ? 'Bandera activada, pero la fecha actual está fuera del rango configurado.'
                : 'Periodo de inscripciones y accesos temporales DESACTIVADOS.',
        isSuccess: updated.activasEfectivo,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTogglingWindow = false);
      _showFeedback('Error al actualizar periodo: $e', isError: true);
    }
  }

  Future<void> _pickPeriodoDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_fechaInicio ?? now)
        : (_fechaFin ?? _fechaInicio ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      helpText: isStart
          ? 'Selecciona fecha de inicio de inscripciones'
          : 'Selecciona fecha de cierre de inscripciones',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  primary: AppTheme.primary,
                  onPrimary: AppTheme.onPrimary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    final nextInicio = isStart ? picked : _fechaInicio;
    final nextFin = isStart ? _fechaFin : picked;

    if (nextInicio != null && nextFin != null && nextFin.isBefore(nextInicio)) {
      _showFeedback(
        'La fecha de término no puede ser anterior a la fecha de inicio.',
        isError: true,
      );
      return;
    }

    await _savePeriodoDates(nextInicio, nextFin);
  }

  Future<void> _savePeriodoDates(DateTime? inicio, DateTime? fin) async {
    setState(() => _isSavingPeriodoDates = true);
    try {
      final updated = await _repository.setInscripcionesPeriodo(
        activas: _activasFlag,
        fechaInicio: inicio,
        fechaFin: fin,
      );
      if (!mounted) return;
      setState(() {
        _fechaInicio = updated.fechaInicio;
        _fechaFin = updated.fechaFin;
        _activasFlag = updated.activasFlag;
        _enRangoFechas = updated.enRangoFechas;
        _inscripcionesActivas = updated.activasEfectivo;
        _isSavingPeriodoDates = false;
      });
      widget.onWindowToggled?.call(updated.activasEfectivo);
      _showFeedback('Fechas del periodo de inscripciones actualizadas.', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingPeriodoDates = false);
      _showFeedback('Error al guardar fechas: $e', isError: true);
    }
  }

  Future<void> _openCuposPorCursoDialog() async {
    final changed = await CuposCursosDialog.show(
      context,
      repository: _repository,
    );
    if (changed && mounted) {
      widget.onWindowToggled?.call(_inscripcionesActivas);
    }
  }

  Future<void> _showCreateOperadorDialog() async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final cedulaCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
    bool creating = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !creating,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.dynamicCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.dynamicBorder),
          ),
          title: Row(
            children: [
              const Icon(Symbols.badge, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Crear Credencial Temporal',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.dynamicText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Se creará una cuenta con rol operador_inscripcion habilitada únicamente mientras el periodo de inscripciones esté activo.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.dynamicTextMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nombreCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: AppTheme.dynamicText),
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo *',
                        prefixIcon: Icon(Symbols.person, size: 18),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Nombre requerido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cedulaCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppTheme.dynamicText),
                      decoration: const InputDecoration(
                        labelText: 'Cédula (opcional)',
                        prefixIcon: Icon(Symbols.badge, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: telefonoCtrl,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: AppTheme.dynamicText),
                      decoration: const InputDecoration(
                        labelText: 'Teléfono (opcional)',
                        prefixIcon: Icon(Symbols.call, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: AppTheme.dynamicText),
                      decoration: const InputDecoration(
                        labelText: 'Correo de acceso *',
                        hintText: 'apoyo.inscripcion@immujer.org',
                        prefixIcon: Icon(Symbols.mail, size: 18),
                        isDense: true,
                      ),
                      validator: (v) {
                        final txt = (v ?? '').trim();
                        if (txt.isEmpty || !txt.contains('@')) {
                          return 'Correo válido requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      style: TextStyle(color: AppTheme.dynamicText),
                      decoration: InputDecoration(
                        labelText: 'Contraseña temporal *',
                        prefixIcon: const Icon(Symbols.lock, size: 18),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 18,
                          ),
                          onPressed: () => setDialogState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: creating ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
              ),
              onPressed: creating
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => creating = true);
                      try {
                        await _repository.crearOperadorTemporal(
                          email: emailCtrl.text,
                          password: passwordCtrl.text,
                          nombreCompleto: nombreCtrl.text,
                          cedula: cedulaCtrl.text,
                          telefono: telefonoCtrl.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          _showFeedback(
                            'Credencial temporal creada para ${nombreCtrl.text.trim()}.',
                            isSuccess: true,
                          );
                          await _loadControlData();
                        }
                      } catch (e) {
                        setDialogState(() => creating = false);
                        if (mounted) {
                          _showFeedback(
                            'Error al crear operador: $e',
                            isError: true,
                          );
                        }
                      }
                    },
              icon: creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.onPrimary,
                      ),
                    )
                  : const Icon(Symbols.person_add, size: 18),
              label: Text(creating ? 'Creando...' : 'Crear Acceso'),
            ),
          ],
        ),
      ),
    );

    nombreCtrl.dispose();
    emailCtrl.dispose();
    cedulaCtrl.dispose();
    telefonoCtrl.dispose();
    passwordCtrl.dispose();
  }

  Future<void> _toggleOperador(OperadorTemporal op, bool nuevoEstado) async {
    try {
      await _repository.toggleOperadorAcceso(
        userId: op.userId,
        activo: nuevoEstado,
      );
      if (!mounted) return;
      _showFeedback(
        nuevoEstado
            ? 'Acceso temporal reactivado para ${op.nombreCompleto}.'
            : 'Acceso temporal revocado para ${op.nombreCompleto}.',
        isSuccess: nuevoEstado,
      );
      await _loadControlData();
    } catch (e) {
      if (mounted) {
        _showFeedback('No se pudo actualizar acceso: $e', isError: true);
      }
    }
  }

  Future<void> _confirmDeleteOperador(OperadorTemporal op) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.dynamicCard,
        title: Text(
          'Revocar y Eliminar Operador',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.dynamicText,
          ),
        ),
        content: Text(
          '¿Deseas eliminar definitivamente la credencial temporal de ${op.nombreCompleto} (${op.email})?',
          style: TextStyle(color: AppTheme.dynamicTextMuted, fontSize: 13),
        ),
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    try {
      await _repository.eliminarOperadorTemporal(op.userId);
      if (!mounted) return;
      _showFeedback('Credencial eliminada correctamente.', isSuccess: true);
      await _loadControlData();
    } catch (e) {
      if (mounted) {
        _showFeedback('Error al eliminar credencial: $e', isError: true);
      }
    }
  }

  void _showFeedback(
    String msg, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? AppTheme.errorRed
            : isSuccess
                ? AppTheme.successGreenVariant
                : AppTheme.surfaceContainerHigh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Symbols.how_to_reg,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Periodo de Inscripciones y Accesos Temporales',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Controla la ventana de inscripción y los operadores temporales de apoyo.',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar estado',
                onPressed: _isLoading ? null : _loadControlData,
                icon: Icon(
                  Symbols.refresh,
                  color: AppTheme.dynamicTextMuted,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Symbols.error, color: AppTheme.errorRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppTheme.errorRed,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Switch principal del periodo de inscripciones
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.dynamicSurfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_inscripcionesActivas
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange)
                      .withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (_inscripcionesActivas
                              ? AppTheme.successGreen
                              : AppTheme.warningOrange)
                          .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _inscripcionesActivas
                          ? Symbols.lock_open
                          : Symbols.lock,
                      color: _inscripcionesActivas
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _inscripcionesActivas
                              ? 'Periodo de Inscripciones ACTIVO'
                              : 'Periodo de Inscripciones CERRADO',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppTheme.dynamicText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _inscripcionesActivas
                              ? 'Los operadores temporales pueden iniciar sesión y registrar aspirantes.'
                              : (_activasFlag && !_enRangoFechas)
                                  ? 'Bandera activa, pero fuera del rango de fechas configurado.'
                                  : 'Los accesos de operador_inscripcion permanecen bloqueados.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: (_activasFlag && !_enRangoFechas)
                                ? AppTheme.warningOrange
                                : AppTheme.dynamicTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isTogglingWindow
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: _activasFlag,
                          activeThumbColor: AppTheme.successGreen,
                          onChanged: _toggleInscripcionesWindow,
                        ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildPeriodoFechasYCuposCard(),
            const SizedBox(height: 16),

            // Encabezado del listado rápido de operadores temporales
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Operadores Temporales (${_operadores.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dynamicText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _showCreateOperadorDialog,
                  icon: const Icon(Symbols.person_add, size: 17),
                  label: const Text(
                    'Nuevo Operador',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_operadores.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.dynamicSurfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.dynamicBorder),
                ),
                child: Text(
                  'Aún no hay credenciales temporales registradas. Crea un operador de apoyo cuando inicie la jornada de inscripciones.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.dynamicTextMuted,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _operadores.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final op = _operadores[index];
                  final effectiveActive =
                      op.accesoActivo && _inscripcionesActivas;
                  final statusColor = !op.accesoActivo
                      ? AppTheme.errorRed
                      : effectiveActive
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange;
                  final statusText = !op.accesoActivo
                      ? 'Revocado'
                      : effectiveActive
                          ? 'Activo'
                          : 'Pausado (Periodo cerrado)';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.dynamicSurfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dynamicBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: statusColor.withValues(alpha: 0.16),
                          foregroundColor: statusColor,
                          child: Text(
                            op.nombreCompleto.isNotEmpty
                                ? op.nombreCompleto[0].toUpperCase()
                                : 'O',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      op.nombreCompleto,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppTheme.dynamicText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          statusColor.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                op.email,
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
                        IconButton(
                          tooltip: op.accesoActivo
                              ? 'Revocar acceso temporal'
                              : 'Reactivar acceso temporal',
                          icon: Icon(
                            op.accesoActivo
                                ? Symbols.person_off
                                : Symbols.how_to_reg,
                            color: op.accesoActivo
                                ? AppTheme.warningOrange
                                : AppTheme.successGreen,
                            size: 20,
                          ),
                          onPressed: () =>
                              _toggleOperador(op, !op.accesoActivo),
                        ),
                        IconButton(
                          tooltip: 'Eliminar credencial',
                          icon: const Icon(
                            Symbols.delete,
                            color: AppTheme.errorRed,
                            size: 20,
                          ),
                          onPressed: () => _confirmDeleteOperador(op),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodoFechasYCuposCard() {
    final df = DateFormat('dd/MM/yyyy');
    final inicioLabel =
        _fechaInicio != null ? df.format(_fechaInicio!) : 'Definir inicio';
    final finLabel = _fechaFin != null ? df.format(_fechaFin!) : 'Definir cierre';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dynamicSurfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Symbols.date_range, size: 17, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vigencia de Inscripciones y Cupos',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.dynamicText,
                  ),
                ),
              ),
              if (_fechaInicio != null || _fechaFin != null)
                TextButton(
                  onPressed: _isSavingPeriodoDates
                      ? null
                      : () => _savePeriodoDates(null, null),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Limpiar fechas',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDateSelectorButton(
                  label: 'Fecha de Inicio',
                  valueText: inicioLabel,
                  icon: Symbols.event_available,
                  hasValue: _fechaInicio != null,
                  onTap: _isSavingPeriodoDates
                      ? null
                      : () => _pickPeriodoDate(isStart: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateSelectorButton(
                  label: 'Fecha de Término',
                  valueText: finLabel,
                  icon: Symbols.event_busy,
                  hasValue: _fechaFin != null,
                  onTap: _isSavingPeriodoDates
                      ? null
                      : () => _pickPeriodoDate(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            onPressed: _openCuposPorCursoDialog,
            icon: const Icon(Symbols.event_seat, size: 18),
            label: Text(
              'Establecer Cupos por Curso',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectorButton({
    required String label,
    required String valueText,
    required IconData icon,
    required bool hasValue,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.dynamicCard,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: hasValue
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.dynamicBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: hasValue ? AppTheme.primary : AppTheme.dynamicTextMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.dynamicTextMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valueText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasValue
                          ? AppTheme.dynamicText
                          : AppTheme.dynamicTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
