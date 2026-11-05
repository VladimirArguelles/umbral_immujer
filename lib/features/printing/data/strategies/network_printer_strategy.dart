import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../domain/printer_models.dart';
import 'network_socket_client.dart';
import 'system_printer_strategy.dart';

class NetworkPrinterStrategy implements PrinterStrategy {
  final NetworkSocketClient _socketClient = NetworkSocketClient();

  @override
  Future<bool> printTicket(TicketData ticket, ConfiguracionImpresora config) async {
    if (kIsWeb) {
      // En Web los sockets TCP directos no están permitidos en el sandbox del navegador; delegar a System
      return SystemPrinterStrategy().printTicket(ticket, config);
    }

    try {
      final parts = config.identificador.split(':');
      final host = parts[0].trim();
      final port = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 9100 : 9100;

      // Comandos ESC/POS estándar (Inicializar, Texto, Corte de Papel)
      const initCommand = [0x1B, 0x40]; // ESC @
      const cutCommand = [0x1D, 0x56, 0x41, 0x10]; // GS V A 16 (Corte)

      final data = <int>[
        ...initCommand,
        ...utf8.encode(ticket.toPlainText()),
        ...cutCommand,
      ];

      final success = await _socketClient.sendData(host, port, data);
      if (success) return true;

      return await SystemPrinterStrategy().printTicket(ticket, config);
    } catch (_) {
      return await SystemPrinterStrategy().printTicket(ticket, config);
    }
  }

  @override
  Future<bool> testConnection(ConfiguracionImpresora config) async {
    if (kIsWeb) return true;
    try {
      final parts = config.identificador.split(':');
      final host = parts[0].trim();
      final port = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 9100 : 9100;

      return await _socketClient.testConnection(host, port);
    } catch (_) {
      return false;
    }
  }
}
