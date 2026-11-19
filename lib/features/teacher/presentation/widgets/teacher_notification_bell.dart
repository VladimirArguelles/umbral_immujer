import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_payment_dialogs.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_survey_breakdown_sheet.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

/// Botón interactivo de notificaciones para el módulo de Profesores.
/// Recibe alertas en tiempo real de respuestas a encuestas y comprobantes de pago subidos.
class TeacherNotificationBell extends StatefulWidget {
  const TeacherNotificationBell({
    super.key,
    required this.teacherRepository,
    this.isSuperAdmin = false,
    this.profile,
    this.onNavigateTab,
  });

  final TeacherRepository teacherRepository;
  final bool isSuperAdmin;
  final UserProfile? profile;
  final ValueChanged<int>? onNavigateTab;

  @override
  State<TeacherNotificationBell> createState() => _TeacherNotificationBellState();
}

class _TeacherNotificationBellState extends State<TeacherNotificationBell> {
  List<TeacherNotificationItem> _notifications = [];
  RealtimeChannel? _channel;
  int _unreadCount = 0;
  bool _hasInitialLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeSubscription();
  }

  @override
  void didUpdateWidget(covariant TeacherNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teacherRepository != widget.teacherRepository ||
        oldWidget.isSuperAdmin != widget.isSuperAdmin ||
        oldWidget.profile?.id != widget.profile?.id) {
      _loadNotifications();
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
    try {
      final client = SupabaseConfig.client;
      final ch = client.channel(
        'teacher_survey_bell_${DateTime.now().microsecondsSinceEpoch}',
      );
      _channel = ch;

      ch
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'respuestas_encuesta',
            callback: (_) {
              if (mounted) _loadNotifications(isRealtimeTrigger: true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[TeacherNotificationBell] Error al suscribir a Realtime: $e');
    }
  }

  Future<Set<String>> _getSeenNotificationIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = widget.profile?.id ??
          SupabaseConfig.client.auth.currentUser?.id ??
          'teacher_guest';
      final list = prefs.getStringList('seen_teacher_notifications_$uid') ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _markAllAsSeen([List<TeacherNotificationItem>? listToMark]) async {
    final targets = listToMark ?? _notifications;
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = widget.profile?.id ??
          SupabaseConfig.client.auth.currentUser?.id ??
          'teacher_guest';
      final seen = (prefs.getStringList('seen_teacher_notifications_$uid') ?? [])
          .toSet();
      for (final n in targets) {
        seen.add(n.id);
      }
      await prefs.setStringList(
        'seen_teacher_notifications_$uid',
        seen.toList(),
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _unreadCount = 0;
      });
    }
  }

  Future<void> _loadNotifications({bool isRealtimeTrigger = false}) async {
    try {
      final list = await widget.teacherRepository.getTeacherNotifications(
        isSuperAdmin: widget.isSuperAdmin,
        profesorId: widget.profile?.id,
      );

      final seenIds = await _getSeenNotificationIds();
      final unread = list.where((n) => !seenIds.contains(n.id)).length;

      if (!mounted) return;

      final previousUnread = _unreadCount;

      setState(() {
        _notifications = list;
        _unreadCount = unread;
      });

      // SnackBar informativo si llega una nueva notificación en tiempo real
      if (isRealtimeTrigger && _hasInitialLoaded && unread > previousUnread) {
        final newest = list.firstWhere(
          (n) => !seenIds.contains(n.id),
          orElse: () => list.first,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newest.isPayment
                      ? Icons.receipt_long_rounded
                      : Icons.campaign_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    newest.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      _hasInitialLoaded = true;
    } catch (e) {
      debugPrint('[TeacherNotificationBell] Error al cargar notificaciones: $e');
    }
  }

  void _showNotificationsSheet(BuildContext context) {
    // Al abrir la notificación se elimina la existencia de notificación en el botón
    _markAllAsSeen(_notifications);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.dynamicCard,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Padding(
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
                // Encabezado Principal
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
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Notificaciones Docentes',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.dynamicText,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppTheme.dynamicTextMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(bottomSheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Subtítulo y Acción "Marcar vistas"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Respuestas de encuestas y pagos recibidos',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.dynamicTextMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_notifications.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          _markAllAsSeen(_notifications);
                          Navigator.of(bottomSheetContext).pop();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.done_all_rounded,
                                size: 14,
                                color: AppTheme.mintNeon,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Marcar vistas',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.mintNeon,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                if (_notifications.isEmpty) ...[
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 48,
                            color: AppTheme.mintNeon.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '¡Sin novedades pendientes!',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.dynamicText,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Cuando tus alumnos respondan encuestas o suban pagos, aparecerán aquí.',
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
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        return _TeacherNotificationCard(
                          item: item,
                          onOpenBreakdown: () {
                            Navigator.of(bottomSheetContext).pop();
                            showTeacherSurveyBreakdownModal(
                              context: context,
                              teacherRepository: widget.teacherRepository,
                              surveyId: item.surveyId,
                              surveyTitle: item.cursoNombre,
                            );
                          },
                          onOpenPayment: () {
                            if (item.comprobanteUrl != null &&
                                item.comprobanteUrl!.isNotEmpty) {
                              showTeacherPaymentProofDialog(
                                context,
                                item.comprobanteUrl!,
                                title: 'Capture de ${item.alumnoNombre}',
                              );
                            } else {
                              Navigator.of(bottomSheetContext).pop();
                              widget.onNavigateTab?.call(3); // Ir a Recaudación
                            }
                          },
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
    final bool hasUnread = _unreadCount > 0;

    return Semantics(
      label: hasUnread
          ? 'Notificaciones: $_unreadCount alertas pendientes'
          : 'Notificaciones del docente',
      button: true,
      child: Tooltip(
        message: hasUnread
            ? 'Tienes $_unreadCount notificación(es) nueva(s)'
            : 'Notificaciones docentes',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showNotificationsSheet(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasUnread
                  ? AppTheme.primary.withValues(alpha: 0.14)
                  : AppTheme.dynamicCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasUnread
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
                  hasUnread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: hasUnread ? AppTheme.primary : AppTheme.dynamicTextMuted,
                  size: 22,
                ),
                if (hasUnread)
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
                          _unreadCount > 9 ? '9+' : '$_unreadCount',
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

/// Tarjeta de notificación individual para el profesor
class _TeacherNotificationCard extends StatelessWidget {
  const _TeacherNotificationCard({
    required this.item,
    required this.onOpenBreakdown,
    required this.onOpenPayment,
  });

  final TeacherNotificationItem item;
  final VoidCallback onOpenBreakdown;
  final VoidCallback onOpenPayment;

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String badgeLabel;
    IconData icon;

    if (item.isPayment) {
      badgeColor = AppTheme.mintNeon;
      badgeLabel = 'PAGO SUBIDO';
      icon = Icons.receipt_long_rounded;
    } else if (item.isAffirmative) {
      badgeColor = AppTheme.mintNeon;
      badgeLabel = 'ASISTIRÁ';
      icon = Icons.check_circle_rounded;
    } else {
      badgeColor = AppTheme.errorRed;
      badgeLabel = 'NO ASISTIRÁ';
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dynamicSurfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.dynamicBorder,
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: badgeColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      Formatters.timeAgo(item.timestamp),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicTextMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.dynamicText,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (item.isPayment)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    side: const BorderSide(color: AppTheme.mintNeon, width: 1),
                  ),
                  onPressed: onOpenPayment,
                  icon: const Icon(
                    Icons.image_outlined,
                    size: 14,
                    color: AppTheme.mintNeon,
                  ),
                  label: const Text(
                    'Ver Capture de Pago',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.mintNeon,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onOpenBreakdown,
                icon: const Icon(
                  Icons.bar_chart_rounded,
                  size: 14,
                ),
                label: const Text(
                  'Ver Respuestas y Progreso',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
