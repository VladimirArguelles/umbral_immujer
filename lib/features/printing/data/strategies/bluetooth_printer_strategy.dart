import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../domain/printer_models.dart';
import 'system_printer_strategy.dart';

class BluetoothPrinterStrategy implements PrinterStrategy {
  @override
  Future<bool> printTicket(TicketData ticket, ConfiguracionImpresora config) async {
    if (kIsWeb) {
      return SystemPrinterStrategy().printTicket(ticket, config);
    }

    try {
      final device = BluetoothDevice.fromId(config.identificador);
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 6),
        autoConnect: false,
      );

      final services = await device.discoverServices();
      BluetoothCharacteristic? writeCharacteristic;

      for (final service in services) {
        for (final char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            writeCharacteristic = char;
            break;
          }
        }
        if (writeCharacteristic != null) break;
      }

      if (writeCharacteristic != null) {
        final textBytes = utf8.encode(ticket.toPlainText());
        // Enviar en paquetes de 20 a 100 bytes para evitar buffer overflow BLE
        const chunkSize = 64;
        for (var i = 0; i < textBytes.length; i += chunkSize) {
          final end = (i + chunkSize < textBytes.length) ? i + chunkSize : textBytes.length;
          final chunk = textBytes.sublist(i, end);
          await writeCharacteristic.write(
            chunk,
            withoutResponse: writeCharacteristic.properties.writeWithoutResponse,
          );
        }
        await device.disconnect();
        return true;
      }

      await device.disconnect();
      return await SystemPrinterStrategy().printTicket(ticket, config);
    } catch (_) {
      return await SystemPrinterStrategy().printTicket(ticket, config);
    }
  }

  @override
  Future<bool> testConnection(ConfiguracionImpresora config) async {
    if (kIsWeb) return true;
    try {
      final device = BluetoothDevice.fromId(config.identificador);
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 4),
        autoConnect: false,
      );
      final isConnected = device.isConnected;
      await device.disconnect();
      return isConnected;
    } catch (_) {
      return false;
    }
  }
}
