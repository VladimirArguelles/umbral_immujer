import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Resultado estructurado de la consulta de tasa del Banco Central de Venezuela (BCV)
class BcvRateResult {
  final double rate;
  final String currency;
  final DateTime updatedAt;
  final String source;

  const BcvRateResult({
    required this.rate,
    required this.currency,
    required this.updatedAt,
    required this.source,
  });
}

/// Servicio para la consulta automatizada de la tasa oficial del BCV
class BcvRateService {
  static const String _primaryUrl = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const String _fallbackUrl = 'https://ve.dolarapi.com/v1/dolares';

  /// Obtiene la tasa oficial del BCV desde el endpoint público con respaldo automático y timeout
  static Future<BcvRateResult> fetchOfficialRate() async {
    try {
      final response = await http
          .get(
            Uri.parse(_primaryUrl),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final promedio = data['promedio'];
        final double rate = _parseRate(promedio);

        if (rate <= 0) {
          throw const FormatException('Monto de tasa BCV inválido o no positivo.');
        }

        final rawDate = data['fechaActualizacion'] as String?;
        final updatedAt = _calculateEffectiveDate(rawDate);

        return BcvRateResult(
          rate: rate,
          currency: (data['moneda'] ?? 'USD').toString(),
          updatedAt: updatedAt,
          source: (data['fuente'] ?? 'oficial').toString(),
        );
      }
    } on SocketException {
      // Reintentar en fallback si hay error de red
    } on TimeoutException {
      // Reintentar en fallback si hay timeout
    } catch (_) {
      // Continuar a fallback
    }

    // Intento con endpoint de respaldo
    try {
      final fallbackResponse = await http
          .get(
            Uri.parse(_fallbackUrl),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (fallbackResponse.statusCode == 200) {
        final list = jsonDecode(utf8.decode(fallbackResponse.bodyBytes)) as List;
        final oficialItem = list.firstWhere(
          (item) => item is Map && item['fuente'] == 'oficial',
          orElse: () => list.isNotEmpty && list.first is Map ? list.first : null,
        );

        if (oficialItem == null) {
          throw const FormatException('Respuesta sin datos oficiales del BCV.');
        }

        final promedio = oficialItem['promedio'];
        final double rate = _parseRate(promedio);

        if (rate <= 0) {
          throw const FormatException('Monto de tasa BCV inválido en fallback.');
        }

        final rawDate = oficialItem['fechaActualizacion'] as String?;
        final updatedAt = _calculateEffectiveDate(rawDate);

        return BcvRateResult(
          rate: rate,
          currency: (oficialItem['moneda'] ?? 'USD').toString(),
          updatedAt: updatedAt,
          source: 'BCV Oficial (DolarAPI)',
        );
      } else {
        throw HttpException('Respuesta del servidor no válida (HTTP ${fallbackResponse.statusCode})');
      }
    } on SocketException catch (e) {
      throw SocketException('No se pudo conectar con el servicio de tasa cambiaria: ${e.message}');
    } on TimeoutException {
      throw TimeoutException('Tiempo de espera agotado al consultar la tasa del BCV.');
    }
  }

  static DateTime _calculateEffectiveDate(String? rawDate) {
    final now = DateTime.now();
    if (now.weekday == DateTime.friday) {
      return DateTime(now.year, now.month, now.day + 3);
    } else if (now.weekday == DateTime.saturday) {
      return DateTime(now.year, now.month, now.day + 2);
    } else if (now.weekday == DateTime.sunday) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    return rawDate != null
        ? (DateTime.tryParse(rawDate)?.toLocal() ?? now)
        : now;
  }

  static double _parseRate(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final clean = value.toString().trim().replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }
}
