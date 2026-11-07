import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/core/services/error_console_service.dart';

/// Pantalla de consola de diagnóstico de errores en estilo terminal oscuro (#0F172A).
/// Permite al Super Admin visualizar, depurar e inspeccionar excepciones en tiempo de ejecución.
class ErrorConsoleScreen extends StatelessWidget {
  const ErrorConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            const Icon(Symbols.terminal, color: Color(0xFF38BDF8), size: 22),
            const SizedBox(width: 10),
            Text(
              'Consola de Diagnóstico',
              style: GoogleFonts.firaCode(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Color(0xFFF87171)),
            tooltip: 'Limpiar logs de memoria',
            onPressed: () {
              ErrorConsoleService.instance.limpiarLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Consola reiniciada: registros en memoria borrados.'),
                  backgroundColor: Color(0xFF1E293B),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: ErrorConsoleService.instance,
        builder: (context, _) {
          final logs = ErrorConsoleService.instance.logs;
          if (logs.isEmpty) return _buildTerminalEmptyState();

          return Column(
            children: [
              _buildStatusBar(logs.length),
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
      ),
    );
  }

  Widget _buildStatusBar(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E293B).withValues(alpha: 0.6),
      child: Text(
        'BÚFER: $count/${ErrorConsoleService.maxLogs} entradas registradas | Auto-rotativo',
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
              style: GoogleFonts.firaCode(fontSize: 14, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w600),
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
                  style: GoogleFonts.firaCode(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFF1F5F9)),
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
                        style: GoogleFonts.firaCode(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                      ),
                      IconButton(
                        icon: const Icon(Symbols.content_copy, size: 16, color: Color(0xFF38BDF8)),
                        tooltip: 'Copiar causa',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '${item.mensaje}\n\n${item.causa}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Diagnóstico copiado al portapapeles.'), duration: Duration(seconds: 2)),
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
