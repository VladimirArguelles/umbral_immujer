import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_payment_dialogs.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_survey_actions.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_survey_cards.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_survey_form_sheet.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

/// Surveys management & history tab for teachers.
class TeacherSurveysTab extends StatefulWidget {
  const TeacherSurveysTab({
    super.key,
    required this.teacherRepository,
    this.isSuperAdmin = false,
    this.profile,
  });

  final TeacherRepository teacherRepository;
  final bool isSuperAdmin;
  final UserProfile? profile;

  @override
  State<TeacherSurveysTab> createState() => _TeacherSurveysTabState();
}

class _TeacherSurveysTabState extends State<TeacherSurveysTab> {
  int _selectedFilter = 0;
  bool _isLoading = false;
  List<TeacherSurvey> _activeSurveys = [];
  List<TeacherSurvey> _historySurveys = [];
  List<TeacherCourse> _cursos = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        widget.teacherRepository.getMyCourses(isSuperAdmin: widget.isSuperAdmin),
        widget.teacherRepository.getTeacherSurveys(
          activeOnly: true,
          isSuperAdmin: widget.isSuperAdmin,
        ),
        widget.teacherRepository.getTeacherSurveys(
          activeOnly: false,
          isSuperAdmin: widget.isSuperAdmin,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _cursos = results[0] as List<TeacherCourse>;
        _activeSurveys = results[1] as List<TeacherSurvey>;
        _historySurveys = results[2] as List<TeacherSurvey>;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCreateSurvey() {
    showTeacherSurveyFormSheet(
      context: context,
      teacherRepository: widget.teacherRepository,
      courses: _cursos,
      profile: widget.profile,
      onSaved: _loadAll,
    );
  }

  void _openEditSurvey(TeacherSurvey survey) {
    showTeacherSurveyFormSheet(
      context: context,
      teacherRepository: widget.teacherRepository,
      courses: _cursos,
      profile: widget.profile,
      existingSurvey: survey,
      onSaved: _loadAll,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.dynamicBackground,
      child: Column(
        children: [
          _FilterBar(
            selectedFilter: _selectedFilter,
            onFilterChanged: (val) => setState(() => _selectedFilter = val),
            onCreateSurvey: _openCreateSurvey,
          ),
          Expanded(
            child: _isLoading
                ? const SurveysSkeleton()
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    child: _selectedFilter == 0
                        ? _buildActiveList()
                        : _buildHistoryList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveList() {
    if (_activeSurveys.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.assignment_late_outlined,
                size: 56,
                color: AppTheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              const Text(
                'No tienes encuestas activas actualmente',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Publica una nueva encuesta para estimar y prorratear insumos con tus alumnos.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_chart_rounded, size: 18),
                label: const Text('Crear Encuesta de Insumos'),
                onPressed: _openCreateSurvey,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: _activeSurveys.length,
      itemBuilder: (context, index) {
        final survey = _activeSurveys[index];
        return TeacherActiveSurveyCard(
          survey: survey,
          onManage: () => showTeacherSurveyActionsSheet(
            context: context,
            survey: survey,
            onEdit: () => _openEditSurvey(survey),
            onAuditPayments: () => showTeacherSurveyPaymentsAuditDialog(
              context: context,
              survey: survey,
              teacherRepository: widget.teacherRepository,
            ),
            onClose: () => confirmCloseTeacherSurvey(
              context: context,
              survey: survey,
              teacherRepository: widget.teacherRepository,
              onCompleted: _loadAll,
            ),
            onDelete: () => confirmDeleteTeacherSurvey(
              context: context,
              survey: survey,
              teacherRepository: widget.teacherRepository,
              onCompleted: _loadAll,
            ),
          ),
          onDelete: () => confirmDeleteTeacherSurvey(
            context: context,
            survey: survey,
            teacherRepository: widget.teacherRepository,
            onCompleted: _loadAll,
          ),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    if (_historySurveys.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                size: 56,
                color: AppTheme.onSurfaceVariant,
              ),
              SizedBox(height: 14),
              Text(
                'No hay encuestas en el historial',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Las encuestas cerradas o finalizadas aparecerán archivadas aquí.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: _historySurveys.length,
      itemBuilder: (context, index) {
        final survey = _historySurveys[index];
        return TeacherHistorySurveyCard(
          survey: survey,
          onViewPayments: () => showTeacherSurveyPaymentsAuditDialog(
            context: context,
            survey: survey,
            teacherRepository: widget.teacherRepository,
          ),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onCreateSurvey,
  });

  final int selectedFilter;
  final ValueChanged<int> onFilterChanged;
  final VoidCallback onCreateSurvey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: AppTheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    'Filtro de Selección:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Nueva Encuesta',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  foregroundColor: AppTheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onCreateSurvey,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBright,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedFilter,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.primary,
                ),
                dropdownColor: AppTheme.surfaceBright,
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem<int>(
                    value: 0,
                    child: Row(
                      children: [
                        Icon(
                          Icons.assignment_turned_in_rounded,
                          size: 18,
                          color: AppTheme.mintNeon,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Encuestas Activas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem<int>(
                    value: 1,
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: AppTheme.secondary,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Historial de Encuestas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) onFilterChanged(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
