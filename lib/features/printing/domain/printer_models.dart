import 'dart:typed_data';

/// Tipo de conexión de la impresora
enum TipoConexionImpresora {
  bluetooth('bluetooth', 'Bluetooth'),
  red('red', 'Red / Wi-Fi (TCP/IP)'),
  sistema('sistema', 'Impresora del Sistema / SO');

  final String dbValue;
  final String label;
  const TipoConexionImpresora(this.dbValue, this.label);

  static TipoConexionImpresora fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'bluetooth':
        return TipoConexionImpresora.bluetooth;
      case 'red':
      case 'wifi':
      case 'network':
        return TipoConexionImpresora.red;
      case 'sistema':
      case 'system':
      default:
        return TipoConexionImpresora.sistema;
    }
  }
}

/// Modelo de Configuración de Impresora persistida
class ConfiguracionImpresora {
  final String id;
  final String? userId;
  final TipoConexionImpresora tipoConexion;
  final String identificador; // MAC address, IP:Puerto o nombre en el SO
  final String nombreImpresora;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ConfiguracionImpresora({
    required this.id,
    this.userId,
    required this.tipoConexion,
    required this.identificador,
    required this.nombreImpresora,
    this.createdAt,
    this.updatedAt,
  });

  factory ConfiguracionImpresora.fromMap(Map<String, dynamic> map) {
    return ConfiguracionImpresora(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      tipoConexion: TipoConexionImpresora.fromString(map['tipo_conexion']?.toString()),
      identificador: map['identificador']?.toString() ?? '',
      nombreImpresora: map['nombre_impresora']?.toString() ?? 'Impresora',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (userId != null) 'user_id': userId,
      'tipo_conexion': tipoConexion.dbValue,
      'identificador': identificador,
      'nombre_impresora': nombreImpresora,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  ConfiguracionImpresora copyWith({
    String? id,
    String? userId,
    TipoConexionImpresora? tipoConexion,
    String? identificador,
    String? nombreImpresora,
  }) {
    return ConfiguracionImpresora(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tipoConexion: tipoConexion ?? this.tipoConexion,
      identificador: identificador ?? this.identificador,
      nombreImpresora: nombreImpresora ?? this.nombreImpresora,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Fila para tickets formateados
class TicketRow {
  final String columna1;
  final String? columna2;
  final String? columna3;

  const TicketRow({
    required this.columna1,
    this.columna2,
    this.columna3,
  });
}

/// Datos universales de impresión (Patrón Strategy / Dispatcher)
class TicketData {
  final String titulo;
  final String? subtitulo;
  final List<TicketRow> items;
  final Map<String, String> totales;
  final String? pieDePagina;
  final Uint8List? pdfBytes;
  final String? qrData;

  const TicketData({
    required this.titulo,
    this.subtitulo,
    this.items = const [],
    this.totales = const {},
    this.pieDePagina,
    this.pdfBytes,
    this.qrData,
  });

  /// Genera una representación en texto plano para impresoras térmicas
  String toPlainText() {
    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln('       $titulo       ');
    if (subtitulo != null && subtitulo!.isNotEmpty) {
      buffer.writeln('  $subtitulo  ');
    }
    buffer.writeln('================================');
    for (final item in items) {
      if (item.columna3 != null) {
        buffer.writeln('${item.columna1} | ${item.columna2} | ${item.columna3}');
      } else if (item.columna2 != null) {
        buffer.writeln('${item.columna1.padRight(20)} ${item.columna2}');
      } else {
        buffer.writeln(item.columna1);
      }
    }
    if (totales.isNotEmpty) {
      buffer.writeln('--------------------------------');
      totales.forEach((k, v) {
        buffer.writeln('${k.padRight(20)} $v');
      });
    }
    buffer.writeln('================================');
    if (pieDePagina != null && pieDePagina!.isNotEmpty) {
      buffer.writeln(pieDePagina);
      buffer.writeln('================================');
    }
    buffer.writeln('\n\n\n');
    return buffer.toString();
  }
}

/// Contrato abstracto para las estrategias de impresión (Patrón Strategy)
abstract class PrinterStrategy {
  Future<bool> printTicket(TicketData ticket, ConfiguracionImpresora config);
  Future<bool> testConnection(ConfiguracionImpresora config);
}
