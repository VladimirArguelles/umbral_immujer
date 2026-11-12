import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_pago_movil_fields.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

/// Opens a modal bottom sheet to create a new supply survey or edit an existing one.
Future<void> showTeacherSurveyFormSheet({
  required BuildContext context,
  required TeacherRepository teacherRepository,
  required List<TeacherCourse> courses,
  required VoidCallback onSaved,
  UserProfile? profile,
  TeacherSurvey? existingSurvey,
}) async {
  if (existingSurvey == null && courses.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No tienes cursos activos para asignar una encuesta.'),
        backgroundColor: AppTheme.errorRed,
      ),
    );
    return;
  }

  final rateInfo = await teacherRepository.getLatestBcvRateInfo();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.9,
    ),
    builder: (ctx) => _TeacherSurveyFormSheet(
      teacherRepository: teacherRepository,
      courses: courses,
      profile: profile,
      existingSurvey: existingSurvey,
      bcvRate: rateInfo.tasa,
      bcvValueDate: rateInfo.fechaValor,
      onSaved: onSaved,
    ),
  );
}

class _TeacherSurveyFormSheet extends StatefulWidget {
  const _TeacherSurveyFormSheet({
    required this.teacherRepository,
    required this.courses,
    required this.bcvRate,
    required this.onSaved,
    this.profile,
    this.existingSurvey,
    this.bcvValueDate,
  });

  final TeacherRepository teacherRepository;
  final List<TeacherCourse> courses;
  final UserProfile? profile;
  final TeacherSurvey? existingSurvey;
  final double bcvRate;
  final String? bcvValueDate;
  final VoidCallback onSaved;

  @override
  State<_TeacherSurveyFormSheet> createState() =>
      _TeacherSurveyFormSheetState();
}

class _TeacherSurveyFormSheetState extends State<_TeacherSurveyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _costoCtrl;
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _customBancoCtrl;

  TeacherCourse? _selectedCourse;
  late DateTime _fechaClase;
  late DateTime _fechaLimite;
  late String _bancoSeleccionado;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existingSurvey != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingSurvey;
    _selectedCourse = widget.courses.isNotEmpty ? widget.courses.first : null;
    _costoCtrl = TextEditingController(
      text: existing != null ? existing.costoTotalInsumos.toStringAsFixed(2) : '',
    );
    _fechaClase = existing != null
        ? (DateTime.tryParse(existing.fechaClase) ??
            DateTime.now().add(const Duration(days: 3)))
        : DateTime.now().add(const Duration(days: 3));
    _fechaLimite = existing != null
        ? existing.fechaLimite
        : DateTime.now().add(const Duration(days: 2));
    _cedulaCtrl = TextEditingController(
      text: existing?.pagoMovilCedula ?? widget.profile?.cedula ?? '',
    );
    _telefonoCtrl = TextEditingController(
      text: existing?.pagoMovilTelefono ?? widget.profile?.telefono ?? '',
    );

    final rawBank = existing?.pagoMovilBanco ?? '';
    if (rawBank.isEmpty) {
      _bancoSeleccionado = teacherPagoMovilBanks.first;
      _customBancoCtrl = TextEditingController();
    } else if (teacherPagoMovilBanks.contains(rawBank)) {
      _bancoSeleccionado = rawBank;
      _customBancoCtrl = TextEditingController();
    } else {
      _bancoSeleccionado = 'Otro Banco';
      _customBancoCtrl = TextEditingController(text: rawBank);
    }
  }

  @override
  void dispose() {
    _costoCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _customBancoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final costo = double.parse(_costoCtrl.text.trim());
    final bancoFinal = _bancoSeleccionado == 'Otro Banco'
        ? _customBancoCtrl.text.trim()
        : _bancoSeleccionado;

    try {
      if (_isEditing) {
        await widget.teacherRepository.updateSurveyDetails(
          surveyId: widget.existingSurvey!.id,
          totalSupplyCost: costo,
          classDate: Formatters.isoDate(_fechaClase),
          deadline: _fechaLimite,
          pagoMovilCedula: _cedulaCtrl.text.trim(),
          pagoMovilTelefono: _telefonoCtrl.text.trim(),
          pagoMovilBanco: bancoFinal,
        );
      } else {
        await widget.teacherRepository.createSurvey(
          courseId: _selectedCourse!.id,
          classDate: Formatters.isoDate(_fechaClase),
          totalSupplyCost: costo,
          deadline: _fechaLimite,
          pagoMovilCedula: _cedulaCtrl.text.trim(),
          pagoMovilTelefono: _telefonoCtrl.text.trim(),
          pagoMovilBanco: bancoFinal,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? '¡Encuesta actualizada y cuota recalculada exitosamente!'
                : '¡Encuesta creada con éxito!',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_isEditing ? "Error al actualizar" : "Error al crear encuesta"}: $e',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _isEditing
                          ? 'Editar Encuesta • ${widget.existingSurvey!.cursoNombre}'
                          : 'Nueva Encuesta de Insumos',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 6),
                const Text(
                  'Crea una encuesta para que los alumnos confirmen su asistencia y el presupuesto se prorratee automáticamente.',
                  style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TeacherCourse>(
                  isExpanded: true,
                  initialValue: _selectedCourse,
                  decoration: const InputDecoration(
                    labelText: 'Curso / Asignatura',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: widget.courses
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c.nombre,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCourse = val);
                  },
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _costoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Presupuesto Total de Insumos (USD)',
                  prefixIcon: Icon(Icons.attach_money),
                  hintText: 'Ej. 35.00',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  final numVal = double.tryParse(v.trim());
                  if (numVal == null || numVal <= 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TeacherBcvRateBadge(
                rate: widget.bcvRate,
                valueDate: widget.bcvValueDate,
              ),
              const SizedBox(height: 14),
              _DatePickerTile(
                icon: Icons.event,
                iconColor: AppTheme.primary,
                title: 'Fecha de la Práctica',
                subtitle: Formatters.date(_fechaClase),
                onTap: () async {
                  final firstDate = _isEditing
                      ? DateTime.now().subtract(const Duration(days: 7))
                      : DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fechaClase,
                    firstDate: firstDate,
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null && mounted) setState(() => _fechaClase = d);
                },
              ),
              const SizedBox(height: 12),
              _DatePickerTile(
                icon: Icons.timer,
                iconColor: AppTheme.secondary,
                title: 'Fecha y Hora Límite',
                subtitle: Formatters.dateTime(_fechaLimite),
                onTap: () async {
                  final firstDate = _isEditing
                      ? DateTime.now().subtract(const Duration(days: 7))
                      : DateTime.now();
                  final lastDate =
                      _fechaClase.isBefore(firstDate) ? firstDate : _fechaClase;
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fechaLimite.isBefore(firstDate)
                        ? firstDate
                        : (_fechaLimite.isAfter(lastDate)
                            ? lastDate
                            : _fechaLimite),
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                  if (d != null && context.mounted) {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_fechaLimite),
                    );
                    if (t != null && mounted) {
                      setState(() {
                        _fechaLimite =
                            DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 14),
              TeacherPagoMovilFields(
                cedulaController: _cedulaCtrl,
                telefonoController: _telefonoCtrl,
                selectedBank: _bancoSeleccionado,
                customBankController: _customBancoCtrl,
                onBankChanged: (val) => setState(() => _bancoSeleccionado = val),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppTheme.onSurface,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEditing
                            ? 'Guardar Cambios y Recalcular'
                            : 'Publicar Encuesta a los Alumnos',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppTheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      tileColor: AppTheme.surfaceBright,
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: const Icon(Icons.edit_calendar_rounded, size: 18),
      onTap: onTap,
    );
  }
}
