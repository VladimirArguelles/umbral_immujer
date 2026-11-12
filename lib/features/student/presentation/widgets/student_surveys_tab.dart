import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:umbral_immujer/features/student/data/student_repository.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_active_survey_card.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_payments_history_view.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_receipt_dialogs.dart';
import 'package:umbral_immujer/features/student/presentation/widgets/student_surveys_history_view.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// Surveys and supply-contribution tab with filter between active, history, and payments.
class StudentSurveysTab extends StatefulWidget {
  const StudentSurveysTab({
    super.key,
    required this.studentRepository,
    this.isSuperAdmin = false,
  });

  final StudentRepository studentRepository;
  final bool isSuperAdmin;

  @override
  State<StudentSurveysTab> createState() => _StudentSurveysTabState();
}

class _StudentSurveysTabState extends State<StudentSurveysTab> {
  int _selectedFilter = 0;
  late Future<List<StudentSurvey>> _encuestasDisponiblesFuture;
  late Future<List<StudentSurvey>> _historialEncuestasFuture;
  late Future<List<StudentPaymentRecord>> _historialPagosFuture;

  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  void _refreshAll() {
    _encuestasDisponiblesFuture = widget.studentRepository.getActiveSurveys(
      isSuperAdmin: widget.isSuperAdmin,
    );
    _historialEncuestasFuture = widget.studentRepository.getSurveysHistory(
      isSuperAdmin: widget.isSuperAdmin,
    );
    _historialPagosFuture = widget.studentRepository.getPaymentHistory(
      isSuperAdmin: widget.isSuperAdmin,
    );
  }

  Future<void> _respondSurvey(String surveyId, bool willAttend) async {
    setState(() => _isResponding = true);
    try {
      await widget.studentRepository.respondToSurvey(
        surveyId: surveyId,
        willAttend: willAttend,
        isSuperAdmin: widget.isSuperAdmin,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willAttend
                ? 'Asistencia confirmada. Puedes adjuntar tu pago.'
                : 'Has indicado que no podrás asistir a esta clase.',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      setState(_refreshAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al responder encuesta: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  Future<void> _pickAndUploadReceipt(String surveyId) async {
    final source = await showStudentReceiptSourceSheet(context);
    if (source == null || !mounted) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1600,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();

      await widget.studentRepository.uploadPaymentProof(
        surveyId: surveyId,
        imageBytes: bytes,
        fileExtension: ext,
        isSuperAdmin: widget.isSuperAdmin,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comprobante subido exitosamente.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      setState(_refreshAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir comprobante: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<int>(
            initialValue: _selectedFilter,
            decoration: InputDecoration(
              labelText: 'Vista de Encuestas y Aportes',
              prefixIcon: const Icon(Icons.filter_list_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppTheme.dynamicCard,
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Encuestas Disponibles')),
              DropdownMenuItem(value: 1, child: Text('Historial de Encuestas')),
              DropdownMenuItem(value: 2, child: Text('Historial de Pago')),
            ],
            onChanged: (value) {
              if (value != null && value != _selectedFilter) {
                setState(() => _selectedFilter = value);
              }
            },
          ),
        ),
        Expanded(child: _buildSelectedView()),
      ],
    );
  }

  Widget _buildSelectedView() {
    switch (_selectedFilter) {
      case 1:
        return StudentSurveysHistoryView(
          future: _historialEncuestasFuture,
          onRefresh: () async {
            setState(_refreshAll);
            await _historialEncuestasFuture;
          },
        );
      case 2:
        return StudentPaymentsHistoryView(
          future: _historialPagosFuture,
          isUploading: _isUploading,
          onRefresh: () async {
            setState(_refreshAll);
            await _historialPagosFuture;
          },
          onUploadReceipt: _pickAndUploadReceipt,
        );
      default:
        return _buildActiveSurveysView();
    }
  }

  Widget _buildActiveSurveysView() {
    return FutureBuilder<List<StudentSurvey>>(
      future: _encuestasDisponiblesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SurveysSkeleton();
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(height: 12),
                  Text('Error al cargar encuestas: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(_refreshAll),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final activeSurveys = (snapshot.data ?? [])
            .where((e) => e.estadoEncuesta == 'activa' && !e.estaVencida)
            .toList();

        if (activeSurveys.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.poll_outlined,
                    size: 64,
                    color: AppTheme.dynamicTextMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay encuestas activas disponibles en este momento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.dynamicTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(_refreshAll);
            await _encuestasDisponiblesFuture;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: activeSurveys.length,
            itemBuilder: (context, index) {
              final survey = activeSurveys[index];
              return StudentActiveSurveyCard(
                survey: survey,
                isResponding: _isResponding,
                isUploading: _isUploading,
                onRespond: (willAttend) => _respondSurvey(survey.id, willAttend),
                onUploadReceipt: () => _pickAndUploadReceipt(survey.id),
              );
            },
          ),
        );
      },
    );
  }
}
