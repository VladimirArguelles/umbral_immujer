import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/core/services/error_console_service.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_colors.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Modelo de notificación para el Super Admin
class SuperAdminNotificationItem {
  final String id;
  final String titulo;
  final String mensaje;
  final String tipo;
  final Map<String, dynamic> datos;
  final bool leido;
  final DateTime createdAt;

  const SuperAdminNotificationItem({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.datos,
    required this.leido,
    required this.createdAt,
  });

  factory SuperAdminNotificationItem.fromMap(Map<String, dynamic> map) {
    return SuperAdminNotificationItem(
      id: map['id']?.toString() ?? '',
      titulo: map['titulo']?.toString() ?? 'Notificación',
      mensaje: map['mensaje']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? 'general',
      datos: map['datos'] is Map ? Map<String, dynamic>.from(map['datos']) : {},
      leido: map['leido'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isOperationalIssue => tipo == 'incidencia_operacion';
  String? get dondeEstaElProblema =>
      datos['donde_esta_el_problema']?.toString();
  String? get queDebeRevisar => datos['que_debe_revisar']?.toString();
  String? get usuarioNombre => datos['usuario_nombre']?.toString();
  String? get usuarioRol => datos['usuario_rol']?.toString();
  String? get modulo => datos['modulo']?.toString();
}

/// Botón con Campana y Badge interactivo de notificaciones para la interfaz de Super Admin
class SuperAdminNotificationBellButton extends StatefulWidget {
  final VoidCallback? onNotificationCountChanged;

  const SuperAdminNotificationBellButton({
    super.key,
    this.onNotificationCountChanged,
  });

  @override
  State<SuperAdminNotificationBellButton> createState() =>
      _SuperAdminNotificationBellButtonState();
}

class _SuperAdminNotificationBellButtonState
    extends State<SuperAdminNotificationBellButton> {
  final SupabaseClient _supabase = SupabaseConfig.client;
  int _unreadCount = 0;
  Timer? _pollingTimer;
  RealtimeChannel? _notificationsChannel;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _notificationsChannel = _supabase
        .channel(
          'super-admin-notifications-${DateTime.now().microsecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones',
          callback: (_) => _loadUnreadCount(),
        )
        .subscribe();
    // Consulta periódica cada 30 segundos
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    final channel = _notificationsChannel;
    if (channel != null) {
      unawaited(
        _supabase.removeChannel(channel).then<void>((_) {}).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          ErrorConsoleService.instance.registrarError(
            origen: 'SuperAdminNotificationBellButton.dispose',
            error: error,
            causa: stackTrace,
          );
        }),
      );
    }
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final res = await _supabase
          .from('notificaciones')
          .select('id')
          .or('rol_destino.eq.super_admin,rol_destino.eq.todos')
          .eq('tipo', 'incidencia_operacion')
          .eq('leido', false)
          .count();

      if (!mounted) return;
      setState(() {
        _unreadCount = res.count;
      });
      widget.onNotificationCountChanged?.call();
    } catch (error, stackTrace) {
      ErrorConsoleService.instance.registrarError(
        origen: 'SuperAdminNotificationBellButton._loadUnreadCount',
        error: error,
        causa: stackTrace,
      );
    }
  }

  Future<void> _openNotificationsModal() async {
    await SuperAdminNotificationsModal.show(context);
    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    final buttonBg = isDark
        ? AppColors.darkCard.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.9);
    final border = AppColors.outline;

    return Tooltip(
      message: 'Notificaciones del Sistema e Incidencias',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openNotificationsModal,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: buttonBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Symbols.notifications,
                  size: 22,
                  color: AppColors.primary,
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          _unreadCount > 9 ? '9+' : '$_unreadCount',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
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

/// Diálogo modal de notificaciones y diagnósticos del sistema para Super Admin.
class SuperAdminNotificationsModal extends StatefulWidget {
  const SuperAdminNotificationsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => const SuperAdminNotificationsModal(),
    );
  }

  @override
  State<SuperAdminNotificationsModal> createState() =>
      _SuperAdminNotificationsModalState();
}

class _SuperAdminNotificationsModalState
    extends State<SuperAdminNotificationsModal> {
  final SupabaseClient _supabase = SupabaseConfig.client;
  List<SuperAdminNotificationItem> _notifications = [];
  RealtimeChannel? _notificationsChannel;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedFilter = 0; // 0 = Todas, 1 = Solo incidencias operativas

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _notificationsChannel = _supabase
        .channel(
          'super-admin-notification-list-${DateTime.now().microsecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones',
          callback: (_) => _fetchNotifications(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    final channel = _notificationsChannel;
    if (channel != null) {
      unawaited(
        _supabase.removeChannel(channel).then<void>((_) {}).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          ErrorConsoleService.instance.registrarError(
            origen: 'SuperAdminNotificationsModal.dispose',
            error: error,
            causa: stackTrace,
          );
        }),
      );
    }
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pendingIssueRows = await _supabase
          .from('notificaciones')
          .select('*')
          .or('rol_destino.eq.super_admin,rol_destino.eq.todos')
          .eq('tipo', 'incidencia_operacion')
          .eq('leido', false)
          .order('created_at', ascending: false)
          .limit(40);
      final recentRows = await _supabase
          .from('notificaciones')
          .select('*')
          .or('rol_destino.eq.super_admin,rol_destino.eq.todos')
          .order('created_at', ascending: false)
          .limit(40);

      if (!mounted) return;
      final notificationsById = <String, SuperAdminNotificationItem>{};
      for (final row in [...pendingIssueRows, ...recentRows]) {
        final notification = SuperAdminNotificationItem.fromMap(row);
        notificationsById.putIfAbsent(notification.id, () => notification);
      }
      final notifications = notificationsById.values.toList()
        ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar las notificaciones: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _supabase
          .from('notificaciones')
          .update({
            'leido': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == id);
        if (idx != -1) {
          final old = _notifications[idx];
          _notifications[idx] = SuperAdminNotificationItem(
            id: old.id,
            titulo: old.titulo,
            mensaje: old.mensaje,
            tipo: old.tipo,
            datos: old.datos,
            leido: true,
            createdAt: old.createdAt,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo marcar la incidencia como atendida: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openIssueDetails(SuperAdminNotificationItem item) async {
    if (!item.leido) await _markAsRead(item.id);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final cardBg = AppTheme.isDark ? const Color(0xFF13111C) : Colors.white;
        final border = AppTheme.isDark
            ? const Color(0xFF2D283E)
            : const Color(0xFFE2E8F0);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width < 652 ? size.width - 32 : 620,
              maxHeight: size.height - 32,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    Text(
                      item.titulo,
                      softWrap: true,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.isDark
                            ? Colors.white
                            : AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.mensaje,
                      softWrap: true,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.isDark
                            ? const Color(0xFFB8B3C5)
                            : const Color(0xFF475569),
                      ),
                    ),
                    if (item.datos.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Metadatos',
                        softWrap: true,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.isDark
                              ? Colors.white
                              : AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...item.datos.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                softWrap: true,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                entry.value?.toString() ?? '—',
                                softWrap: true,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppTheme.isDark
                                      ? const Color(0xFFB8B3C5)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _supabase.from('notificaciones').delete().eq('id', id);

      if (!mounted) return;
      setState(() {
        _notifications.removeWhere((n) => n.id == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notificación eliminada',
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al eliminar notificación: $e',
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _supabase
          .from('notificaciones')
          .update({
            'leido': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .or('rol_destino.eq.super_admin,rol_destino.eq.todos')
          .eq('leido', false);

      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (old) => SuperAdminNotificationItem(
                id: old.id,
                titulo: old.titulo,
                mensaje: old.mensaje,
                tipo: old.tipo,
                datos: old.datos,
                leido: true,
                createdAt: old.createdAt,
              ),
            )
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron marcar las notificaciones: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteReviewedNotifications() async {
    final reviewedCount = _notifications.where((n) => n.leido).length;
    if (reviewedCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.isDark
            ? const Color(0xFF13111C)
            : Colors.white,
        title: Text(
          'Eliminar notificaciones revisadas',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Deseas eliminar permanentemente las $reviewedCount notificaciones que ya fueron revisadas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('notificaciones')
          .delete()
          .eq('leido', true)
          .or('rol_destino.eq.super_admin,rol_destino.eq.todos');

      if (!mounted) return;
      setState(() {
        _notifications.removeWhere((n) => n.leido);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notificaciones revisadas eliminadas.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar notificaciones: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    final cardBg = isDark ? const Color(0xFF13111C) : Colors.white;
    final border = isDark ? const Color(0xFF2D283E) : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final filteredList = _notifications.where((n) {
      if (_selectedFilter == 1) {
        return n.isOperationalIssue;
      }
      return true;
    }).toList();

    final unreadCount = _notifications.where((n) => !n.leido).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 32,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.18), cardBg],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(bottom: BorderSide(color: border, width: 0.8)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Symbols.notifications_active,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Alertas & Diagnósticos',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: textMain,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.error.withValues(
                                          alpha: 0.6,
                                        ),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '$unreadCount sin leer',
                                      softWrap: true,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Incidencias operativas reportadas por usuarios y equipos del sistema',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textMuted),
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Barra de filtros y acciones (Wrap adaptativo para evitar cualquier desborde horizontal)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text('Todas (${_notifications.length})'),
                      selected: _selectedFilter == 0,
                      onSelected: (val) => setState(() => _selectedFilter = 0),
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _selectedFilter == 0 ? Colors.white : textMuted,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: cardBg,
                      side: BorderSide(
                        color: _selectedFilter == 0
                            ? AppColors.primary
                            : border,
                      ),
                    ),
                    ChoiceChip(
                      avatar: const Icon(
                        Symbols.warning,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      label: Text(
                        'Incidencias (${_notifications.where((n) => n.isOperationalIssue).length})',
                      ),
                      selected: _selectedFilter == 1,
                      onSelected: (val) => setState(() => _selectedFilter = 1),
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _selectedFilter == 1 ? Colors.white : textMuted,
                      ),
                      selectedColor: AppColors.warning,
                      backgroundColor: cardBg,
                      side: BorderSide(
                        color: _selectedFilter == 1
                            ? AppColors.warning
                            : border,
                      ),
                    ),
                    if (_notifications.any((n) => n.leido))
                      TextButton.icon(
                        onPressed: _deleteReviewedNotifications,
                        icon: const Icon(Symbols.delete_sweep, size: 16),
                        label: Text(
                          'Eliminar revisadas (${_notifications.where((n) => n.leido).length})',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (unreadCount > 0)
                      TextButton.icon(
                        onPressed: _markAllAsRead,
                        icon: const Icon(Symbols.done_all, size: 16),
                        label: const Text(
                          'Marcar todas',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 0.8),

              // Cuerpo con lista de notificaciones
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : filteredList.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 32,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.mintNeon.withValues(
                                    alpha: 0.12,
                                  ),
                                  border: Border.all(
                                    color: AppColors.mintNeon.withValues(
                                      alpha: 0.35,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Symbols.check_circle,
                                  size: 32,
                                  color: AppColors.mintNeon,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: Text(
                                  'No hay incidencias ni notificaciones pendientes',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: textMain,
                                    height: 1.35,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: Text(
                                  'Las consultas y fallas reportadas por usuarios aparecerán aquí automáticamente.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: textMuted,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredList.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          return _buildNotificationCard(
                            item: item,
                            isDark: isDark,
                            cardBg: cardBg,
                            border: border,
                            textMain: textMain,
                            textMuted: textMuted,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required SuperAdminNotificationItem item,
    required bool isDark,
    required Color cardBg,
    required Color border,
    required Color textMain,
    required Color textMuted,
  }) {
    final isIssue = item.isOperationalIssue;
    final accentColor = isIssue ? AppColors.warning : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isIssue ? () => _openIssueDetails(item) : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1726) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: item.leido ? border : accentColor.withValues(alpha: 0.6),
              width: item.leido ? 1 : 1.5,
            ),
            boxShadow: item.leido
                ? []
                : [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          isIssue ? Symbols.warning : Symbols.info,
                          size: 13,
                          color: accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isIssue ? 'INCIDENCIA UMBY' : 'NOTIFICACIÓN',
                          softWrap: true,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.modulo != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(
                          item.modulo!.toUpperCase(),
                          softWrap: true,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    _formatTimeAgo(item.createdAt),
                    softWrap: true,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!item.leido)
                    IconButton(
                      icon: const Icon(Symbols.check_circle, size: 18),
                      color: AppColors.mintNeon,
                      tooltip: 'Marcar como atendida',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _markAsRead(item.id),
                    ),
                  IconButton(
                    icon: const Icon(Symbols.delete_outline, size: 18),
                    color: AppColors.error,
                    tooltip: 'Eliminar notificación',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _deleteNotification(item.id),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.titulo,
                softWrap: true,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.mensaje,
                softWrap: true,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: textMuted,
                  height: 1.4,
                ),
              ),
              if (isIssue &&
                  (item.dondeEstaElProblema != null ||
                      item.queDebeRevisar != null)) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF221C30)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Symbols.psychology,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ANÁLISIS DE LA IA (UMBY)',
                              softWrap: true,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.warning,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.dondeEstaElProblema != null) ...[
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            style: GoogleFonts.plusJakartaSans(fontSize: 12),
                            children: [
                              TextSpan(
                                text: '📍 Dónde se encuentra el problema:\n',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  color: textMain,
                                ),
                              ),
                              TextSpan(
                                text: item.dondeEstaElProblema,
                                style: GoogleFonts.plusJakartaSans(
                                  color: textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          softWrap: true,
                        ),
                      ],
                      if (item.queDebeRevisar != null) ...[
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            style: GoogleFonts.plusJakartaSans(fontSize: 12),
                            children: [
                              TextSpan(
                                text: '🛠️ Qué debe revisar el Super Admin:\n',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  color: textMain,
                                ),
                              ),
                              TextSpan(
                                text: item.queDebeRevisar,
                                style: GoogleFonts.plusJakartaSans(
                                  color: textMuted,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                          softWrap: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
