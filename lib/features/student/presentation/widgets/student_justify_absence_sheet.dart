import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:umbral_immujer/features/student/data/student_repository.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';

/// Bottom sheet allowing a student to submit a medical/personal absence justification.
class StudentJustifyAbsenceSheet extends StatefulWidget {
  const StudentJustifyAbsenceSheet({
    super.key,
    required this.curso,
    this.initialFecha,
    required this.studentRepository,
    required this.picker,
    required this.onSubmitted,
  });

  final StudentCourse curso;
  final String? initialFecha;
  final StudentRepository studentRepository;
  final ImagePicker picker;
  final VoidCallback onSubmitted;

  @override
  State<StudentJustifyAbsenceSheet> createState() =>
      _StudentJustifyAbsenceSheetState();
}

class _StudentJustifyAbsenceSheetState
    extends State<StudentJustifyAbsenceSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fechaController;
  final _motivoController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageExtension;
  String? _imageName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final defaultDate = widget.initialFecha ?? Formatters.isoDate(DateTime.now());
    _fechaController = TextEditingController(text: defaultDate);
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    DateTime initial = now;
    try {
      initial = DateTime.parse(_fechaController.text);
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Fecha de la Inasistencia',
    );
    if (picked != null && mounted) {
      setState(() {
        _fechaController.text = Formatters.isoDate(picked);
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await widget.picker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageExtension = ext;
        _imageName = picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await widget.studentRepository.submitAbsenceJustification(
        cursoId: widget.curso.id,
        fecha: _fechaController.text.trim(),
        motivo: _motivoController.text.trim(),
        imageBytes: _imageBytes,
        fileExtension: _imageExtension,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSubmitted();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Justificativo enviado exitosamente. Pendiente de revisión por Coordinación.',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar justificativo: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.dynamicCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dynamicBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Justificar Ausencia',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.curso.nombre,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.dynamicTextMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _fechaController,
                  readOnly: true,
                  onTap: _selectDate,
                  decoration: InputDecoration(
                    labelText: 'Fecha de la falta *',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Selecciona una fecha'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motivoController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: 'Motivo médico o justificación *',
                    hintText: 'Describe brevemente la razón de tu inasistencia...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 8) {
                      return 'Explica el motivo (mínimo 8 caracteres)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Soporte / Récipe Médico (Opcional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_imageBytes != null) ...[
                  _AttachmentPreview(
                    imageBytes: _imageBytes!,
                    imageName: _imageName,
                    onRemove: () => setState(() {
                      _imageBytes = null;
                      _imageExtension = null;
                      _imageName = null;
                    }),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Cámara'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galería'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'ENVIANDO...' : 'ENVIAR JUSTIFICATIVO',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.imageBytes,
    required this.imageName,
    required this.onRemove,
  });

  final Uint8List imageBytes;
  final String? imageName;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final sizeKb = (imageBytes.lengthInBytes / 1024).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.dynamicBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageBytes,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  imageName ?? 'Soporte adjunto',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$sizeKb KB listo para subir',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.dynamicTextMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
            tooltip: 'Quitar imagen',
          ),
        ],
      ),
    );
  }
}
