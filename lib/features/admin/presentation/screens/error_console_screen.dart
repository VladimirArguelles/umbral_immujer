import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/core/services/error_console_service.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';

/// Pantalla de consola de diagnóstico de errores y auditoría de IA en estilo terminal oscuro (#0F172A).
/// Permite al Super Admin visualizar excepciones en memoria e historial de interacciones de Umby / Gemini.
class ErrorConsoleScreen extends StatefulWidget {
  const ErrorConsoleScreen({super.key});

  @override
  State<ErrorConsoleScreen> createState() => _ErrorConsoleScreenState();
}

class _ErrorConsoleScreenState extends State<ErrorConsoleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _assistantLogs = [];
  bool _isLoadingAssistantLogs = false;
  String? _assistantLogsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _cargarAssistantLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarAssistantLogs() async {
    setState(() {
      _isLoadingAssistantLogs = true;
      _assistantLogsError = null;
    });

    try {
      final data = await SupabaseConfig.client
          .from('assistant_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(60);

      if (mounted) {
        setState(() {
          _assistantLogs = List<Map<String, dynamic>>.from(data);
          _isLoadingAssistantLogs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _assistantLogsError = e.toString();
          _isLoadingAssistantLogs = false;
        });
      }
    }
  }

  Future<void> _confirmarYEliminarLog(String id) async {
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: [
            const Icon(Symbols.delete_forever, color: Color(0xFFF87171), size: 22),
            const SizedBox(width: 8),
            Text(
              'Eliminar consulta',
              style: GoogleFonts.firaCode(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Deseas eliminar permanentemente este registro de consulta revisado?',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFCBD5E1),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseConfig.client.from('assistant_logs').delete().eq('id', id);
      if (mounted) {
        setState(() {
          _assistantLogs.removeWhere((log) => log['id']?.toString() == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro de consulta eliminado de la auditoría.'),
            backgroundColor: Color(0xFF1E293B),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar registro: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmarYEliminarTodosLosLogs() async {
    if (_assistantLogs.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: [
            const Icon(Symbols.delete_sweep, color: Color(0xFFF87171), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Eliminar auditoría',
                style: GoogleFonts.firaCode(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          _assistantLogs.length == 1
              ? '¿Deseas eliminar permanentemente el registro de consulta revisada de Umby / Gemini?'
              : '¿Deseas eliminar permanentemente los ${_assistantLogs.length} registros de consultas revisadas de Umby / Gemini?',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFCBD5E1),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar todos'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseConfig.client
          .from('assistant_logs')
          .delete()
          .neq('id', '00000000-0000-0000-0000-000000000000');

      if (mounted) {
        setState(() {
          _assistantLogs.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se han eliminado todos los registros de auditoría.'),
            backgroundColor: Color(0xFF1E293B),
            duration: Duration(seconds: 2),
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

  @override
  Widget build(BuildContext context) {
    final isAssistantTab = _tabController.index == 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: Colors.white, size: 22),
          tooltip: 'Regresar',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
            Expanded(
              child: Text(
                'Consola Diagnóstico',
                style: GoogleFonts.firaCode(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF10B981), width: 0.8),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.firaCode(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.refresh, color: Color(0xFF38BDF8), size: 20),
            tooltip: 'Recargar auditoría IA',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            visualDensity: VisualDensity.compact,
            onPressed: _cargarAssistantLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Color(0xFFF87171), size: 20),
            tooltip: isAssistantTab
                ? 'Eliminar consultas revisadas de IA'
                : 'Limpiar logs de memoria',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              if (isAssistantTab) {
                _confirmarYEliminarTodosLosLogs();
              } else {
                ErrorConsoleService.instance.limpiarLogs();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Consola reiniciada: registros en memoria borrados.'),
                    backgroundColor: Color(0xFF1E293B),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          labelStyle: GoogleFonts.firaCode(fontSize: 11.5, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.firaCode(fontSize: 11.5),
          tabs: [
            const Tab(
              icon: Icon(Symbols.bug_report, size: 17),
              text: 'Excepciones',
            ),
            Tab(
              icon: const Icon(Symbols.smart_toy, size: 17),
              text: _assistantLogs.isEmpty
                  ? 'Auditoría Umby'
                  : 'Auditoría (${_assistantLogs.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMemoryLogsTab(),
          _buildAssistantLogsTab(),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 1: EXCEPCIONES EN VIVO
  // ===========================================================================
  Widget _buildMemoryLogsTab() {
    return AnimatedBuilder(
      animation: ErrorConsoleService.instance,
      builder: (context, _) {
        final logs = ErrorConsoleService.instance.logs;
        if (logs.isEmpty) return _buildTerminalEmptyState();

        return Column(
          children: [
            _buildStatusBar(
              'BÚFER: ${logs.length}/${ErrorConsoleService.maxLogs} entradas en memoria | Auto-rotativo',
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildLogCard(context, logs[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // PESTAÑA 2: AUDITORÍA DE IA Y CONSULTAS DE UMBY
  // ===========================================================================
  Widget _buildAssistantLogsTab() {
    if (_isLoadingAssistantLogs) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      );
    }

    if (_assistantLogsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.error, color: Color(0xFFEF4444), size: 44),
              const SizedBox(height: 12),
              Text(
                'Error al consultar assistant_logs:',
                style: GoogleFonts.firaCode(color: const Color(0xFFF87171), fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                _assistantLogsError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cargarAssistantLogs,
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

    if (_assistantLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Icon(Symbols.smart_toy, color: Color(0xFF38BDF8), size: 44),
              ),
              const SizedBox(height: 18),
              Text(
                r'$ select * from assistant_logs',
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  color: const Color(0xFF38BDF8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No hay interacciones pendientes o registradas en assistant_logs.\nLas consultas de los usuarios se registrarán aquí automáticamente.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildAssistantStatusBar(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _assistantLogs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _buildAssistantLogCard(_assistantLogs[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantStatusBar() {
    final count = _assistantLogs.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: const Color(0xFF1E293B).withValues(alpha: 0.6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Auditoría: $count ${count == 1 ? "registro" : "registros"}',
              style: GoogleFonts.firaCode(fontSize: 11, color: const Color(0xFF94A3B8)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _confirmarYEliminarTodosLosLogs,
            icon: const Icon(Symbols.delete_sweep, size: 15, color: Color(0xFFF87171)),
            label: Text(
              'Eliminar ($count)',
              style: GoogleFonts.firaCode(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF87171),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantLogCard(Map<String, dynamic> item) {
    final logId = item['id']?.toString() ?? '';
    final userNombre = item['user_nombre'] as String? ?? 'Anónimo';
    final userRol = (item['user_rol'] as String? ?? 'alumno').toUpperCase();
    final modulo = (item['modulo_id'] as String? ?? 'general').toUpperCase();
    final modelo = item['modelo_ia'] as String? ?? 'gemini-2.5-flash';
    final question = item['user_question'] as String? ?? '';
    final answer = item['bot_answer'] as String? ?? '';
    final ticketId = item['ticket_id'] as String?;
    final createdAtRaw = item['created_at'] as String?;

    String horaFormateada = '';
    if (createdAtRaw != null) {
      try {
        final dt = DateTime.parse(createdAtRaw).toLocal();
        horaFormateada =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      } catch (_) {
        horaFormateada = createdAtRaw;
      }
    }

    final isGemini = modelo.toLowerCase().contains('gemini');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        collapsedIconColor: const Color(0xFF94A3B8),
        iconColor: const Color(0xFF38BDF8),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isGemini
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : const Color(0xFFF59E0B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isGemini ? Symbols.neurology : Symbols.memory,
            color: isGemini ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            size: 20,
          ),
        ),
        title: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '[$modulo]',
                style: GoogleFonts.firaCode(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF38BDF8),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isGemini
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                modelo,
                style: GoogleFonts.firaCode(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isGemini ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                ),
              ),
            ),
            if (ticketId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFEF4444), width: 0.8),
                ),
                child: Text(
                  'TICKET #${ticketId.substring(0, 8)}',
                  style: GoogleFonts.firaCode(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF87171),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '👤 $userNombre ($userRol) • $horaFormateada',
                style: GoogleFonts.firaCode(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 2),
              Text(
                '💬 "$question"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: const Color(0xFFF1F5F9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RESPUESTA GENERADA POR UMBY / GEMINI:',
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Symbols.content_copy, size: 16, color: Color(0xFF38BDF8)),
                          tooltip: 'Copiar interacción',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: 'PREGUNTA ($userNombre - $modulo):\n$question\n\nRESPUESTA:\n$answer',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Interacción copiada al portapapeles.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 14),
                        IconButton(
                          icon: const Icon(Symbols.delete_outline, size: 17, color: Color(0xFFF87171)),
                          tooltip: 'Eliminar esta consulta revisada',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _confirmarYEliminarLog(logId),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  answer.trim().isNotEmpty ? answer : 'Sin contenido de respuesta registrado.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFFCBD5E1),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E293B).withValues(alpha: 0.6),
      child: Text(
        text,
        style: GoogleFonts.firaCode(fontSize: 11, color: const Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _buildTerminalEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Symbols.terminal, color: Color(0xFF10B981), size: 44),
            ),
            const SizedBox(height: 18),
            Text(
              r'$ umbral --diagnostico-status',
              style: GoogleFonts.firaCode(
                fontSize: 14,
                color: const Color(0xFF38BDF8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay errores ni excepciones capturadas en memoria.\nEl sistema se encuentra operando normalmente.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, LogItem item) {
    final hora =
        '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: const Color(0xFF94A3B8),
          iconColor: const Color(0xFF38BDF8),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Symbols.error, color: Color(0xFFEF4444), size: 18),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  item.origen,
                  style: GoogleFonts.firaCode(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF1F5F9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('[$hora]', style: GoogleFonts.firaCode(fontSize: 11, color: const Color(0xFF38BDF8))),
            ],
          ),
          subtitle: Text(
            item.mensaje,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFFFCA5A5)),
          ),
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STACK TRACE / CAUSA TÉCNICA:',
                        style: GoogleFonts.firaCode(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Symbols.content_copy, size: 16, color: Color(0xFF38BDF8)),
                        tooltip: 'Copiar causa',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '${item.mensaje}\n\n${item.causa}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Diagnóstico copiado al portapapeles.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    item.causa.trim().isNotEmpty ? item.causa : 'Sin detalles de stack trace disponibles.',
                    style: GoogleFonts.firaCode(fontSize: 11, color: const Color(0xFFCBD5E1), height: 1.4),
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
