import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/core/services/error_console_service.dart';
import 'package:umbral_immujer/core/services/error_tracking_service.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';

/// Pantalla de consola de diagnóstico técnico en estilo terminal oscuro (#0F172A).
/// Monitoriza de forma reactiva y exclusiva las excepciones del sistema (`system_exceptions`).
class ErrorConsoleScreen extends StatefulWidget {
  const ErrorConsoleScreen({super.key});

  @override
  State<ErrorConsoleScreen> createState() => _ErrorConsoleScreenState();
}

class _ErrorConsoleScreenState extends State<ErrorConsoleScreen> {
  final SupabaseClient _supabase = SupabaseConfig.client;
  List<SystemExceptionItem> _exceptions = [];
  bool _isLoading = true;
  bool _isRunningSecurityAudit = false;
  String? _errorMessage;
  RealtimeChannel? _realtimeChannel;

  // Filtros activos
  String _selectedSeverity = 'all'; // 'all', 'critical', 'error', 'warning'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchExceptions();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    try {
      _realtimeChannel = _supabase
          .channel('system_exceptions_console_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'system_exceptions',
            callback: (_) => _fetchExceptions(silent: true),
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _fetchExceptions({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _supabase
          .from('system_exceptions')
          .select()
          .order('timestamp', ascending: false)
          .limit(100);

      final list = (response as List)
          .map((row) => SystemExceptionItem.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();

      if (mounted) {
        setState(() {
          _exceptions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runSecurityAudit() async {
    if (_isRunningSecurityAudit) return;
    setState(() => _isRunningSecurityAudit = true);

    try {
      final result = await _supabase.rpc('auditar_exposicion_seguridad');
      await _fetchExceptions(silent: true);

      final findingsCount = result is Map ? (result['findings_count'] ?? 0) : 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              findingsCount == 0
                  ? 'Auditoría completada: Sin brechas de exposición detectadas.'
                  : 'Auditoría completada: $findingsCount brecha(s) de seguridad detectada(s) y registrada(s).',
            ),
            backgroundColor: findingsCount == 0
                ? const Color(0xFF065F46)
                : const Color(0xFF991B1B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al ejecutar auditoría de seguridad: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRunningSecurityAudit = false);
      }
    }
  }

  Future<void> _clearAllExceptions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: [
            const Icon(Symbols.delete_forever, color: Color(0xFFF87171), size: 24),
            const SizedBox(width: 10),
            Text(
              'Limpiar Diagnóstico',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Deseas purgar todas las excepciones registradas en la base de datos y la memoria local?',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFCBD5E1),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar Todo'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('system_exceptions').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      ErrorConsoleService.instance.limpiarLogs();
      if (mounted) {
        setState(() {
          _exceptions.clear();
        });
      }
      await _fetchExceptions(silent: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consola de diagnóstico reiniciada: registros técnicos eliminados.'),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al limpiar registros: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<SystemExceptionItem> get _filteredExceptions {
    return _exceptions.where((item) {
      if (_selectedSeverity != 'all' && item.severity != _selectedSeverity) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesMsg = item.errorMessage.toLowerCase().contains(q);
        final matchesMod = item.module.toLowerCase().contains(q);
        final matchesStack = item.stackTrace?.toLowerCase().contains(q) ?? false;
        final matchesRoute = (item.metadata['full_route']?.toString().toLowerCase().contains(q) ?? false);
        if (!matchesMsg && !matchesMod && !matchesStack && !matchesRoute) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredExceptions;
    final totalCount = _exceptions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/superadmin');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: Colors.white, size: 22),
          tooltip: 'Regresar',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/superadmin');
            }
          },
        ),
        title: Row(
          children: [
            const Icon(Symbols.terminal, color: Color(0xFF38BDF8), size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Consola de Diagnóstico',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF10B981), width: 0.8),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.firaCode(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.refresh, color: Color(0xFF38BDF8), size: 20),
            tooltip: 'Actualizar telemetría',
            onPressed: () => _fetchExceptions(),
          ),
          IconButton(
            icon: const Icon(Symbols.delete_sweep, color: Color(0xFFF87171), size: 20),
            tooltip: 'Limpiar consola y base de datos',
            onPressed: _clearAllExceptions,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Barra de Métricas y Filtros
          _buildFilterBar(totalCount, filtered.length),

          // Lista de Excepciones del Sistema
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                  )
                : _errorMessage != null
                    ? _buildErrorState()
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) => _buildExceptionCard(filtered[index]),
                          ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildFilterBar(int total, int filteredCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF13192B),
        border: Border(bottom: BorderSide(color: Color(0xFF2E384D), width: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Campo de búsqueda en vivo
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Filtrar por mensaje, módulo o stack trace...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                      prefixIcon: const Icon(Symbols.search, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  '$filteredCount / $total',
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Chips de Severidad + Botón de Auditoría de Seguridad
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSeverityChip('all', 'Todas', const Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      _buildSeverityChip('critical', 'Críticas', const Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      _buildSeverityChip('error', 'Errores', const Color(0xFFF97316)),
                      const SizedBox(width: 6),
                      _buildSeverityChip('warning', 'Advertencias', const Color(0xFFF59E0B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isRunningSecurityAudit ? null : _runSecurityAudit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF7F1D1D),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                icon: _isRunningSecurityAudit
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Symbols.shield_lock, size: 16),
                label: Text(
                  _isRunningSecurityAudit
                      ? 'Auditando...'
                      : 'Ejecutar Auditoría de Seguridad Ahora',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
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

  Widget _buildSeverityChip(String value, String label, Color accentColor) {
    final isSelected = _selectedSeverity == value;

    return InkWell(
      onTap: () => setState(() => _selectedSeverity = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.2) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFF334155),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExceptionCard(SystemExceptionItem item) {
    final bool isSecurityAlert = item.module == 'security_alert';
    Color cardColor;
    IconData icon;
    String badgeText;

    if (isSecurityAlert) {
      cardColor = const Color(0xFFEF4444);
      icon = Symbols.gpp_maybe;
      badgeText = 'ALERTA DE SEGURIDAD';
    } else {
      switch (item.severity) {
        case 'critical':
          cardColor = const Color(0xFFEF4444);
          icon = Symbols.emergency;
          badgeText = 'CRÍTICO';
          break;
        case 'warning':
          cardColor = const Color(0xFFF59E0B);
          icon = Symbols.warning;
          badgeText = 'AVISO';
          break;
        case 'error':
        default:
          cardColor = const Color(0xFFF97316);
          icon = Symbols.error;
          badgeText = 'ERROR';
          break;
      }
    }

    final puntoViolado = item.metadata['punto_violado']?.toString() ??
        item.metadata['tabla']?.toString() ??
        item.metadata['bucket']?.toString() ??
        item.module;
    final infoComprometida = item.metadata['info_comprometida']?.toString() ??
        item.metadata['columnas_expuestas']?.toString() ??
        item.errorMessage;
    final usuarioNombre = item.metadata['usuario_nombre']?.toString() ?? 'Anónimo / Sistema';
    final usuarioRol = item.metadata['usuario_rol']?.toString();
    final usuarioOrigenId = item.metadata['usuario_origen_id']?.toString() ?? item.userId;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13192B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardColor.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cardColor, size: 20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.firaCode(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: cardColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.metadata['full_route']?.toString() ?? item.module,
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      color: const Color(0xFF38BDF8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimestamp(item.timestamp),
                style: GoogleFonts.firaCode(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              item.errorMessage,
              style: GoogleFonts.firaCode(
                fontSize: 12,
                color: const Color(0xFFE2E8F0),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          children: [
            const Divider(color: Color(0xFF1E293B)),
            const SizedBox(height: 8),

            if (isSecurityAlert)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1219),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.55),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Symbols.shield_lock, size: 16, color: Color(0xFFF87171)),
                        const SizedBox(width: 6),
                        Text(
                          'DETALLE FORENSE DE SEGURIDAD',
                          style: GoogleFonts.firaCode(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF87171),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildForensicRow('Punto violado / expuesto', puntoViolado),
                    const SizedBox(height: 6),
                    _buildForensicRow('Información comprometida / bloqueo', infoComprometida),
                    const SizedBox(height: 6),
                    _buildForensicRow(
                      'Usuario origen',
                      usuarioRol != null
                          ? '$usuarioNombre ($usuarioRol)${usuarioOrigenId != null ? ' • ID: $usuarioOrigenId' : ''}'
                          : '$usuarioNombre${usuarioOrigenId != null ? ' • ID: $usuarioOrigenId' : ''}',
                    ),
                  ],
                ),
              ),

            // Ruta Completa y Específica del Error o Falla
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Symbols.route, size: 18, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RUTA COMPLETA ESPECÍFICA:',
                          style: GoogleFonts.firaCode(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          item.metadata['full_route']?.toString() ?? item.module,
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Symbols.content_copy, size: 16, color: Color(0xFF94A3B8)),
                    tooltip: 'Copiar ruta de la falla',
                    onPressed: () {
                      final routeToCopy = item.metadata['full_route']?.toString() ?? item.module;
                      Clipboard.setData(ClipboardData(text: routeToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ruta de la falla copiada al portapapeles.'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Mensaje de Error Completo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F19),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: SelectableText(
                item.errorMessage,
                style: GoogleFonts.firaCode(
                  fontSize: 11.5,
                  color: const Color(0xFFFCA5A5),
                  height: 1.4,
                ),
              ),
            ),

            // Stack Trace Scrolleable
            if (item.stackTrace != null && item.stackTrace!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      item.stackTrace!,
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        color: const Color(0xFF94A3B8),
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Metadatos y Botón Copiar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.userId != null)
                  Text(
                    'Usuario: ${item.userId!.substring(0, 8)}...',
                    style: GoogleFonts.firaCode(fontSize: 10, color: const Color(0xFF64748B)),
                  )
                else
                  const SizedBox.shrink(),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: 'Error: ${item.errorMessage}\nStack: ${item.stackTrace ?? "N/A"}',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reporte copiado al portapapeles.'),
                        backgroundColor: Color(0xFF1E293B),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Symbols.content_copy, size: 14),
                  label: const Text('Copiar Detalle', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Icon(Symbols.verified, size: 48, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            Text(
              'Consola limpia: 0 excepciones registradas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No hay fallos de renderizado ni errores técnicos pendientes.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForensicRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.firaCode(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: GoogleFonts.firaCode(
            fontSize: 11,
            color: const Color(0xFFFEE2E2),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Symbols.cloud_off, size: 44, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              'Error al conectar con system_exceptions:',
              style: GoogleFonts.firaCode(color: const Color(0xFFF87171), fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _fetchExceptions(),
              icon: const Icon(Symbols.refresh, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: const Color(0xFF38BDF8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
