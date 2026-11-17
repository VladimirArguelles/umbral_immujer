import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/features/student/data/student_repository.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';

/// Interactive notification bell with real-time updates for active surveys.
class StudentNotificationBell extends StatefulWidget {
  const StudentNotificationBell({
    super.key,
    required this.studentRepository,
    this.isSuperAdmin = false,
    required this.onNavigateToSurveys,
    this.onSurveysUpdated,
  });

  final StudentRepository? studentRepository;
  final bool isSuperAdmin;
  final VoidCallback onNavigateToSurveys;
  final ValueChanged<List<StudentSurvey>>? onSurveysUpdated;

  @override
  State<StudentNotificationBell> createState() => _StudentNotificationBellState();
}

class _StudentNotificationBellState extends State<StudentNotificationBell> {
  List<StudentSurvey> _surveys = [];
  RealtimeChannel? _channel;
  int _pendingCount = 0;
  bool _hasInitialLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSurveys();
    _setupRealtimeSubscription();
  }

  @override
  void didUpdateWidget(covariant StudentNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentRepository != widget.studentRepository ||
        oldWidget.isSuperAdmin != widget.isSuperAdmin) {
      _loadSurveys();
    }
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) {
      SupabaseConfig.client.removeChannel(ch);
    }
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    if (widget.studentRepository == null) return;
    try {
      final client = SupabaseConfig.client;
      final ch = client.channel(
        'student_survey_bell_${DateTime.now().microsecondsSinceEpoch}',
      );
      _channel = ch;

      ch
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'encuestas_participacion',
            callback: (_) {
              if (mounted) _loadSurveys(isRealtimeTrigger: true);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'respuestas_encuesta',
            callback: (_) {
              if (mounted) _loadSurveys(isRealtimeTrigger: true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[StudentNotificationBell] Error al suscribir a Realtime: $e');
    }
  }

  Future<void> _loadSurveys({bool isRealtimeTrigger = false}) async {
    final repo = widget.studentRepository;
    if (repo == null) {
      return;
    }

    try {
      final list = await repo.getActiveSurveys(
        isSuperAdmin: widget.isSuperAdmin,
      );

      final pending = list
          .where((s) => s.respondio != true || s.tieneCapturePendiente)
          .length;

      if (!mounted) return;

      final previousPending = _pendingCount;

      setState(() {
        _surveys = list;
        _pendingCount = pending;
      });

      widget.onSurveysUpdated?.call(list);

      // Si fue una actualización en tiempo real y hay nuevas encuestas pendientes
      if (isRealtimeTrigger && _hasInitialLoaded && pending > previousPending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '¡Nueva encuesta activa! El profesor ha creado una encuesta de insumos.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'RESPONDER',
              textColor: Colors.white,
              onPressed: widget.onNavigateToSurveys,
            ),
          ),
        );
      }

      _hasInitialLoaded = true;
    } catch (e) {
      debugPrint('[StudentNotificationBell] Error al cargar encuestas: $e');
    }
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.dynamicCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppTheme.dynamicBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notificaciones de Encuestas',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.dynamicText,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Encuestas de aportes e insumos activos',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.dynamicTextMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppTheme.dynamicTextMuted,
                      onPressed: () => Navigator.of(bottomSheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_surveys.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 48,
                            color: AppTheme.mintNeon.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '¡Todo al día!',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.dynamicText,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No tienes encuestas activas pendientes en este momento.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.dynamicTextMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _surveys.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final survey = _surveys[index];
                        final bool hasNotResponded = survey.respondio != true;
                        final bool hasPendingVoucher = survey.tieneCapturePendiente;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.dynamicSurfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: hasNotResponded
                                  ? AppTheme.primary.withValues(alpha: 0.4)
                                  : AppTheme.dynamicBorder,
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      survey.cursoNombre,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.dynamicText,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (hasNotResponded)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'NUEVA',
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    )
                                  else if (hasPendingVoucher)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'PAGO PENDIENTE',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (survey.profesorNombre != null &&
                                  survey.profesorNombre!.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Prof. ${survey.profesorNombre}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.dynamicTextMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 13,
                                    color: AppTheme.dynamicTextMuted,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Límite: ${Formatters.dateTime(survey.fechaLimite)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.dynamicTextMuted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: hasNotResponded
                                        ? AppTheme.primary
                                        : AppTheme.dynamicSurfaceHigh,
                                    foregroundColor: hasNotResponded
                                        ? Colors.white
                                        : AppTheme.dynamicText,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: Icon(
                                    hasNotResponded
                                        ? Icons.rate_review_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    hasNotResponded
                                        ? 'Responder Encuesta'
                                        : 'Ver Encuesta y Aportes',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(bottomSheetContext).pop();
                                    widget.onNavigateToSurveys();
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPending = _pendingCount > 0;

    return Semantics(
      label: hasPending
          ? 'Notificaciones: $_pendingCount encuestas pendientes'
          : 'Notificaciones de encuestas',
      button: true,
      child: Tooltip(
        message: hasPending
            ? 'Tienes $_pendingCount encuesta(s) de insumos activa(s)'
            : 'Notificaciones de encuestas',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showNotificationsSheet(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasPending
                  ? AppTheme.primary.withValues(alpha: 0.14)
                  : AppTheme.dynamicCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasPending
                    ? AppTheme.primary.withValues(alpha: 0.5)
                    : AppTheme.dynamicBorder,
                width: 1.2,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  hasPending
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: hasPending ? AppTheme.primary : AppTheme.dynamicTextMuted,
                  size: 22,
                ),
                if (hasPending)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.dynamicBackground,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.errorRed.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _pendingCount > 9 ? '9+' : '$_pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
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
