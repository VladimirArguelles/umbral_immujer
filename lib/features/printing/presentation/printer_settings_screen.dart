import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import '../data/printer_repository.dart';
import '../domain/printer_models.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterRepository _repo = PrinterRepository();

  TipoConexionImpresora _selectedTipo = TipoConexionImpresora.sistema;
  ConfiguracionImpresora? _currentConfig;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;

  // Motores de escaneo
  // 1. Sistema
  List<Printer> _systemPrinters = [];
  bool _loadingSystemPrinters = false;
  Printer? _selectedSystemPrinter;

  // 2. Red / Wi-Fi
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.100');
  final TextEditingController _portController = TextEditingController(text: '9100');
  final TextEditingController _networkNameController = TextEditingController(text: 'Impresora Térmica LAN');

  // 3. Bluetooth
  List<ScanResult> _bluetoothResults = [];
  bool _isScanningBluetooth = false;
  StreamSubscription<List<ScanResult>>? _bluetoothScanSub;
  ScanResult? _selectedBluetoothDevice;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _bluetoothScanSub?.cancel();
    if (!kIsWeb) {
      FlutterBluePlus.stopScan();
    }
    _ipController.dispose();
    _portController.dispose();
    _networkNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    final cfg = await _repo.getConfiguracionImpresora();
    if (!mounted) return;
    setState(() {
      _currentConfig = cfg;
      if (cfg != null) {
        _selectedTipo = cfg.tipoConexion;
        if (cfg.tipoConexion == TipoConexionImpresora.red) {
          final parts = cfg.identificador.split(':');
          _ipController.text = parts[0];
          if (parts.length > 1) _portController.text = parts[1];
          _networkNameController.text = cfg.nombreImpresora;
        }
      }
      _isLoading = false;
    });

    // Cargar automáticamente impresoras del sistema al iniciar
    _scanSystemPrinters();
  }

  // ===========================================================================
  // ESCANEO SISTEMA
  // ===========================================================================
  Future<void> _scanSystemPrinters() async {
    setState(() => _loadingSystemPrinters = true);
    try {
      final list = await Printing.listPrinters();
      if (!mounted) return;
      setState(() {
        _systemPrinters = list;
        _loadingSystemPrinters = false;
        if (_currentConfig?.tipoConexion == TipoConexionImpresora.sistema) {
          for (final p in list) {
            if (p.url == _currentConfig!.identificador || p.name == _currentConfig!.nombreImpresora) {
              _selectedSystemPrinter = p;
              break;
            }
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSystemPrinters = false);
    }
  }

  // ===========================================================================
  // ESCANEO BLUETOOTH
  // ===========================================================================
  Future<void> _startBluetoothScan() async {
    if (kIsWeb) {
      _showSnack('El escaneo Bluetooth directo está disponible en la app móvil Android/iOS.');
      return;
    }

    setState(() {
      _isScanningBluetooth = true;
      _bluetoothResults.clear();
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      _bluetoothScanSub?.cancel();
      _bluetoothScanSub = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        setState(() {
          _bluetoothResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
        });
      });

      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) setState(() => _isScanningBluetooth = false);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningBluetooth = false);
        _showSnack('Error al iniciar escaneo Bluetooth: $e');
      }
    }
  }

  // ===========================================================================
  // GUARDAR CONFIGURACIÓN
  // ===========================================================================
  Future<void> _guardarConfiguracion() async {
    setState(() => _isSaving = true);
    ConfiguracionImpresora? toSave;

    switch (_selectedTipo) {
      case TipoConexionImpresora.sistema:
        if (_selectedSystemPrinter == null) {
          _showSnack('Selecciona una impresora del sistema.');
          setState(() => _isSaving = false);
          return;
        }
        toSave = ConfiguracionImpresora(
          id: _currentConfig?.id ?? '',
          tipoConexion: TipoConexionImpresora.sistema,
          identificador: _selectedSystemPrinter!.url,
          nombreImpresora: _selectedSystemPrinter!.name,
        );
        break;

      case TipoConexionImpresora.red:
        final ip = _ipController.text.trim();
        final port = _portController.text.trim();
        if (ip.isEmpty) {
          _showSnack('Ingresa la dirección IP de la impresora.');
          setState(() => _isSaving = false);
          return;
        }
        toSave = ConfiguracionImpresora(
          id: _currentConfig?.id ?? '',
          tipoConexion: TipoConexionImpresora.red,
          identificador: '$ip:${port.isEmpty ? "9100" : port}',
          nombreImpresora: _networkNameController.text.trim().isEmpty
              ? 'Impresora Red ($ip)'
              : _networkNameController.text.trim(),
        );
        break;

      case TipoConexionImpresora.bluetooth:
        if (_selectedBluetoothDevice == null) {
          _showSnack('Selecciona un dispositivo Bluetooth de la lista.');
          setState(() => _isSaving = false);
          return;
        }
        toSave = ConfiguracionImpresora(
          id: _currentConfig?.id ?? '',
          tipoConexion: TipoConexionImpresora.bluetooth,
          identificador: _selectedBluetoothDevice!.device.remoteId.str,
          nombreImpresora: _selectedBluetoothDevice!.device.platformName.isNotEmpty
              ? _selectedBluetoothDevice!.device.platformName
              : 'Impresora Bluetooth',
        );
        break;
    }

    try {
      await _repo.guardarConfiguracionImpresora(toSave);
      if (!mounted) return;
      setState(() {
        _currentConfig = toSave;
        _isSaving = false;
      });
      _showSnack('¡Impresora "${toSave.nombreImpresora}" guardada como predeterminada!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('Error al guardar configuración: $e');
    }
  }

  // ===========================================================================
  // IMPRESIÓN DE PRUEBA
  // ===========================================================================
  Future<void> _ejecutarPruebaImpresion() async {
    setState(() => _isTesting = true);
    final testTicket = TicketData(
      titulo: 'UMBRAL IMMUJER',
      subtitulo: 'Prueba de Conexión de Impresora',
      items: const [
        TicketRow(columna1: 'Estado de Conexión', columna2: 'OPERATIVO'),
        TicketRow(columna1: 'Motor de Impresión', columna2: 'Patrón Strategy'),
        TicketRow(columna1: 'Despacho Universal', columna2: 'Exitoso'),
      ],
      totales: {
        'Fecha y Hora': DateTime.now().toLocal().toString().split('.')[0],
        'Dispositivo': _currentConfig?.nombreImpresora ?? 'Sistema',
      },
      pieDePagina: 'Instituto Municipal de la Mujer\nSistema de Gestión Integral Umbral',
    );

    try {
      final ok = await _repo.enviarAImprimirUniversal(testTicket, customConfig: _currentConfig);
      if (!mounted) return;
      if (ok) {
        _showSnack('¡Prueba de impresión enviada exitosamente!');
      } else {
        _showSnack('No se pudo completar la impresión de prueba.');
      }
    } catch (e) {
      _showSnack('Fallo en prueba de impresión: $e');
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dynamicBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.dynamicCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.dynamicText),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/coordinator');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajustes de Impresora y Tickets',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.dynamicText,
              ),
            ),
            Text(
              'Configura la impresora térmica para reportes y recibos (Bluetooth, Wi-Fi o SO)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppTheme.dynamicTextMuted,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCurrentPrinterCard(),
                      const SizedBox(height: 16),
                      _buildSelectorTipoConexion(),
                      const SizedBox(height: 16),
                      switch (_selectedTipo) {
                        TipoConexionImpresora.sistema => _buildSistemaView(),
                        TipoConexionImpresora.red => _buildRedView(),
                        TipoConexionImpresora.bluetooth => _buildBluetoothView(),
                      },
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isTesting ? null : _ejecutarPruebaImpresion,
                              icon: _isTesting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.print_outlined),
                              label: const Text('Impresión de Prueba'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: const BorderSide(color: AppTheme.primary),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _guardarConfiguracion,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: const Text('Guardar Impresora'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentPrinterCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.print_rounded, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impresora Predeterminada Activa',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dynamicTextMuted,
                  ),
                ),
                Text(
                  _currentConfig != null
                      ? '${_currentConfig!.nombreImpresora} (${_currentConfig!.tipoConexion.label})'
                      : 'Ninguna configurada (Usa el diálogo del sistema)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dynamicText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorTipoConexion() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.dynamicSurfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: TipoConexionImpresora.values.map((tipo) {
          final isSelected = _selectedTipo == tipo;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _selectedTipo = tipo);
                if (tipo == TipoConexionImpresora.sistema && _systemPrinters.isEmpty) {
                  _scanSystemPrinters();
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  tipo.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.dynamicText,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Vista: Impresoras del Sistema
  Widget _buildSistemaView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Impresoras Instaladas en el Sistema',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.dynamicText),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Actualizar impresoras',
                onPressed: _loadingSystemPrinters ? null : _scanSystemPrinters,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingSystemPrinters)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_systemPrinters.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No se detectaron impresoras instaladas en el sistema.',
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.dynamicTextMuted),
                ),
              ),
            )
          else
            ..._systemPrinters.map((p) {
              final isSelected = _selectedSystemPrinter?.url == p.url ||
                  (_selectedSystemPrinter == null && p.isDefault);
              return InkWell(
                onTap: () => setState(() => _selectedSystemPrinter = p),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.dynamicSurfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.dynamicBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppTheme.primary : AppTheme.dynamicTextMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.dynamicText)),
                            Text(p.url, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.dynamicTextMuted)),
                          ],
                        ),
                      ),
                      if (p.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Predeterminada', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // Vista: Impresora en Red / Wi-Fi
  Widget _buildRedView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conexión de Impresora Térmica por Red / TCP',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.dynamicText),
          ),
          const SizedBox(height: 6),
          Text(
            'Compatible con impresoras de tickets conectadas por cable Ethernet o Wi-Fi (Puerto estándar 9100).',
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.dynamicTextMuted),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _networkNameController,
            decoration: const InputDecoration(
              labelText: 'Nombre Descriptivo de la Impresora',
              prefixIcon: Icon(Icons.label_outline),
              hintText: 'Ej. Impresora Cocina / Caja',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _ipController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Dirección IP de la Impresora',
                    prefixIcon: Icon(Icons.lan_outlined),
                    hintText: 'Ej. 192.168.1.200',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Puerto',
                    hintText: '9100',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Vista: Impresora Bluetooth
  Widget _buildBluetoothView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Impresoras Bluetooth Portátiles',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.dynamicText),
              ),
              ElevatedButton.icon(
                onPressed: _isScanningBluetooth ? null : _startBluetoothScan,
                icon: _isScanningBluetooth
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bluetooth_searching, size: 16),
                label: Text(_isScanningBluetooth ? 'Buscando...' : 'Escanear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (kIsWeb)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.dynamicSurfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El enlace directo Bluetooth BLE se ejecuta en la versión móvil Android/iOS.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.dynamicText),
                    ),
                  ),
                ],
              ),
            )
          else if (_bluetoothResults.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  _isScanningBluetooth
                      ? 'Buscando dispositivos Bluetooth cercanos...'
                      : 'Presiona "Escanear" para buscar tu impresora Bluetooth.',
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.dynamicTextMuted),
                ),
              ),
            )
          else
            ..._bluetoothResults.map((r) {
              final isSelected = _selectedBluetoothDevice?.device.remoteId == r.device.remoteId;
              return InkWell(
                onTap: () => setState(() => _selectedBluetoothDevice = r),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.dynamicSurfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.dynamicBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppTheme.primary : AppTheme.dynamicTextMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.bluetooth, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.device.platformName.isNotEmpty ? r.device.platformName : 'Dispositivo sin nombre',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.dynamicText),
                            ),
                            Text(
                              '${r.device.remoteId.str} • RSSI: ${r.rssi} dBm',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.dynamicTextMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
