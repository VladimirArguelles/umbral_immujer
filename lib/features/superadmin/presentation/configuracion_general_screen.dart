import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

class ConfiguracionGeneralScreen extends StatefulWidget {
  const ConfiguracionGeneralScreen({super.key});

  @override
  State<ConfiguracionGeneralScreen> createState() =>
      _ConfiguracionGeneralScreenState();
}

class _ConfiguracionGeneralScreenState
    extends State<ConfiguracionGeneralScreen> {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Estados de carga y guardado
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Valores originales cargados desde la base de datos
  final Map<String, dynamic> _initialValues = {};

  // Valores de trabajo actuales (editables)
  final Map<String, dynamic> _currentValues = {};

  // Controladores de texto para campos editables
  final Map<String, TextEditingController> _controllers = {};

  // Form Key para validaciones
  final _formKey = GlobalKey<FormState>();

  // Controlador para agregar formatos de archivo
  final TextEditingController _nuevoFormatoController =
      TextEditingController();

  // Colores del tema oscuro requeridos por especificación
  static const Color cBg = Color(0xFF0F172A); // Slate 900
  static const Color cCard = Color(0xFF1E293B); // Slate 800
  static const Color cCardInner = Color(0xFF0F172A); // Slate 900
  static const Color cBorder = Color(0xFF334155); // Slate 700
  static const Color cPrimary = Color(0xFFF43F5E); // Rose 500
  static const Color cPrimaryGlow = Color(0x40F43F5E);
  static const Color cEmerald = Color(0xFF10B981); // Emerald 500
  static const Color cSky = Color(0xFF38BDF8); // Sky 400
  static const Color cAmber = Color(0xFFF59E0B); // Amber 500
  static const Color cTextMain = Color(0xFFF8FAFC); // Slate 50
  static const Color cTextMuted = Color(0xFF94A3B8); // Slate 400
  static const Color cTextDim = Color(0xFF64748B); // Slate 500

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _nuevoFormatoController.dispose();
    super.dispose();
  }

  /// Carga todas las configuraciones desde la tabla 'configuracion_general'
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('configuracion_general')
          .select('clave, valor, descripcion');

      final list = response as List;
      _initialValues.clear();
      _currentValues.clear();

      for (final item in list) {
        final clave = item['clave'] as String;
        final rawVal = item['valor'];
        _initialValues[clave] = rawVal;
        _currentValues[clave] = rawVal;
      }

      // Asegurar valores por defecto si no existen en BD
      _ensureDefault('tolerancia_minutos_asistencia', 15);
      _ensureDefault('porcentaje_minimo_asistencia_aprobacion', 75);
      _ensureDefault('bloqueo_edicion_asistencia_dias', 3);
      _ensureDefault('n8n_webhook_notificaciones', 'https://n8n.umbral.gob/webhook/notify');
      _ensureDefault('recordatorio_pagos_dias_previos', 2);
      _ensureDefault('plantilla_mensaje_bienvenida', '¡Bienvenida a UMBRAL IMMUJER! Tu registro ha sido procesado exitosamente.');
      _ensureDefault('max_file_size_mb_comprobante', 5);
      _ensureDefault('formatos_permitidos_comprobantes', ['jpg', 'jpeg', 'png', 'pdf']);
      _ensureDefault('compresion_imagenes_activa', true);
      _ensureDefault('modo_mantenimiento', false);
      _ensureDefault('version_minima_app', '1.0.0');
      _ensureDefault('tasa_cambio_oficial', 36.50);
      _ensureDefault('dias_retencion_logs', 90);
      _ensureDefault('limite_intentos_login', 5);

      // Sincronizar o crear controladores
      _syncControllers();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar la configuración general: $e';
        });
      }
    }
  }

  void _ensureDefault(String key, dynamic defaultValue) {
    if (!_currentValues.containsKey(key) || _currentValues[key] == null) {
      _currentValues[key] = defaultValue;
      _initialValues[key] = defaultValue;
    }
  }

  void _syncControllers() {
    _setControllerText('tolerancia_minutos_asistencia', _currentValues['tolerancia_minutos_asistencia']?.toString() ?? '15');
    _setControllerText('bloqueo_edicion_asistencia_dias', _currentValues['bloqueo_edicion_asistencia_dias']?.toString() ?? '3');
    _setControllerText('n8n_webhook_notificaciones', _currentValues['n8n_webhook_notificaciones']?.toString() ?? '');
    _setControllerText('recordatorio_pagos_dias_previos', _currentValues['recordatorio_pagos_dias_previos']?.toString() ?? '2');
    _setControllerText('plantilla_mensaje_bienvenida', _currentValues['plantilla_mensaje_bienvenida']?.toString() ?? '');
    _setControllerText('max_file_size_mb_comprobante', _currentValues['max_file_size_mb_comprobante']?.toString() ?? '5');
    _setControllerText('version_minima_app', _currentValues['version_minima_app']?.toString() ?? '1.0.0');
    _setControllerText('tasa_cambio_oficial', _currentValues['tasa_cambio_oficial']?.toString() ?? '36.50');
    _setControllerText('dias_retencion_logs', _currentValues['dias_retencion_logs']?.toString() ?? '90');
    _setControllerText('limite_intentos_login', _currentValues['limite_intentos_login']?.toString() ?? '5');
  }

  void _setControllerText(String key, String text) {
    if (_controllers.containsKey(key)) {
      _controllers[key]!.text = text;
    } else {
      _controllers[key] = TextEditingController(text: text);
    }
  }

  /// Calcula cuántas claves han sido modificadas respecto a los valores iniciales
  Set<String> _getModifiedKeys() {
    final modified = <String>{};

    for (final entry in _currentValues.entries) {
      final key = entry.key;
      final current = entry.value;
      final initial = _initialValues[key];

      if (current is List && initial is List) {
        if (jsonEncode(current) != jsonEncode(initial)) {
          modified.add(key);
        }
      } else if (current != initial) {
        modified.add(key);
      }
    }
    return modified;
  }

  /// Guarda los cambios en Supabase por lotes (Batch Update)
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      _showToast(
        'Por favor corrige los campos con errores antes de guardar.',
        isError: true,
      );
      return;
    }

    final modifiedKeys = _getModifiedKeys();

    if (modifiedKeys.isEmpty) {
      _showToast('No hay cambios pendientes por guardar.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final updates = modifiedKeys.map((key) {
        return {
          'clave': key,
          'valor': _currentValues[key],
          'actualizado_en': now,
        };
      }).toList();

      // Upsert batch en Supabase garantizando atomicidad
      await _supabase.from('configuracion_general').upsert(
            updates,
            onConflict: 'clave',
          );

      // Actualizar los valores iniciales para sincronizar el estado limpio
      for (final key in modifiedKeys) {
        _initialValues[key] = _currentValues[key];
      }

      if (mounted) {
        _showToast(
          '¡Configuración guardada exitosamente! (${modifiedKeys.length} parámetros actualizados)',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showToast(
          'Error al guardar en Supabase: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Diálogo para restablecer los valores frescos de la base de datos
  Future<void> _confirmResetValues() async {
    final modifiedKeys = _getModifiedKeys();
    if (modifiedKeys.isEmpty) {
      _loadSettings();
      _showToast('Valores recargados desde la base de datos.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cBorder),
        ),
        title: Row(
          children: [
            const Icon(Symbols.restart_alt, color: cAmber, size: 24),
            const SizedBox(width: 10),
            Text(
              'Restablecer Valores',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: cTextMain,
              ),
            ),
          ],
        ),
        content: Text(
          'Tienes ${modifiedKeys.length} cambio(s) sin guardar.\n\n¿Deseas descartarlos y recargar los valores originales de la base de datos?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: cTextMuted,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: cTextDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cAmber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Descartar y Restablecer',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _loadSettings();
      if (mounted) {
        _showToast('Valores restablecidos desde la base de datos.');
      }
    }
  }

  /// Diálogo especial de confirmación para activar/desactivar Modo Mantenimiento
  Future<void> _toggleModoMantenimiento(bool newValue) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: newValue ? cAmber : cBorder,
            width: newValue ? 1.5 : 1.0,
          ),
        ),
        title: Row(
          children: [
            Icon(
              newValue ? Symbols.warning : Symbols.check_circle,
              color: newValue ? cAmber : cEmerald,
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              newValue
                  ? '¿Activar Modo Mantenimiento?'
                  : '¿Desactivar Modo Mantenimiento?',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: cTextMain,
              ),
            ),
          ],
        ),
        content: Text(
          newValue
              ? 'ALERTA: Al activar el Modo Mantenimiento, las estudiantes y profesores verán una pantalla de mantenimiento y no podrán registrar asistencias ni subir comprobantes.\n\n¿Estás seguro de continuar?'
              : 'La plataforma UMBRAL volverá a estar disponible públicamente para todos los roles de usuario.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: cTextMuted,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: cTextDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newValue ? cAmber : cEmerald,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              newValue ? 'Sí, Activar Mantenimiento' : 'Reanudar Operaciones',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _currentValues['modo_mantenimiento'] = newValue;
      });
    }
  }

  void _showToast(String message,
      {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Symbols.error
                  : isSuccess
                      ? Symbols.check_circle
                      : Symbols.info,
              color: isError
                  ? Colors.white
                  : isSuccess
                      ? Colors.white
                      : cSky,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE11D48) // Rose 600
            : isSuccess
                ? const Color(0xFF059669) // Emerald 600
                : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError
                ? const Color(0xFFFB7185)
                : isSuccess
                    ? const Color(0xFF34D399)
                    : cBorder,
          ),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modifiedCount = _getModifiedKeys().length;

    return Theme(
      data: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: cBg,
        colorScheme: const ColorScheme.dark(
          primary: cPrimary,
          surface: cCard,
        ),
      ),
      child: Scaffold(
        backgroundColor: cBg,
        appBar: _buildAppBar(),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: cPrimary),
                    SizedBox(height: 16),
                    Text(
                      'Cargando configuración de Supabase...',
                      style: TextStyle(color: cTextMuted, fontSize: 13),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Symbols.cloud_off,
                              size: 48, color: cPrimary),
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: cPrimary, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cCard,
                              foregroundColor: cTextMain,
                              side: const BorderSide(color: cBorder),
                            ),
                            onPressed: _loadSettings,
                            icon: const Icon(Symbols.refresh, size: 18),
                            label: const Text('Reintentar Conexión'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                          children: [
                            if (modifiedCount > 0) _buildPendingChangesBanner(modifiedCount),
                            _buildAcademicSection(),
                            const SizedBox(height: 20),
                            _buildAutomationSection(),
                            const SizedBox(height: 20),
                            _buildStorageSection(),
                            const SizedBox(height: 20),
                            _buildEnvironmentSection(),
                            const SizedBox(height: 20),
                            _buildSecuritySection(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
        bottomNavigationBar: _buildBottomActionBar(modifiedCount),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: cCard,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: cTextMain),
        tooltip: 'Volver al Panel',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/superadmin');
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Configuración General',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: cTextMain,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cPrimary.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cPrimary.withAlpha(80)),
                ),
                child: const Text(
                  'SUPER ADMIN',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: cPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Control de parámetros, auditoría, automatizaciones e integraciones de UMBRAL',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: cTextMuted,
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _isLoading || _isSaving ? null : _confirmResetValues,
          icon: const Icon(Symbols.restart_alt, size: 18, color: cTextMuted),
          label: Text(
            'Restablecer',
            style: GoogleFonts.plusJakartaSans(
              color: cTextMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(color: cBorder, height: 1),
      ),
    );
  }

  Widget _buildPendingChangesBanner(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cAmber.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cAmber.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.edit_note, color: cAmber, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tienes $count parámetro(s) con cambios locales pendientes por sincronizar en Supabase.',
              style: GoogleFonts.plusJakartaSans(
                color: cTextMain,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN A: AUDITORÍA ACADÉMICA Y ASISTENCIA
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAcademicSection() {
    final porcentaje = (_currentValues['porcentaje_minimo_asistencia_aprobacion'] as num?)?.toDouble() ?? 75.0;

    return _buildSectionCard(
      title: 'Auditoría Académica y Asistencia',
      subtitle: 'Parámetros de tolerancia, bloqueo de fechas y porcentaje para pase de curso',
      icon: Symbols.fact_check,
      accentColor: cPrimary,
      children: [
        _buildTextField(
          keyName: 'tolerancia_minutos_asistencia',
          label: 'Tolerancia en Minutos para Asistencia',
          helperText: 'Tiempo límite después de la hora de inicio para considerar presencia válida.',
          suffixText: 'minutos',
          icon: Symbols.timer,
          isNumeric: true,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 0) return 'Ingresa un número entero mayor o igual a 0';
            return null;
          },
          onChanged: (val) {
            _currentValues['tolerancia_minutos_asistencia'] = int.tryParse(val) ?? 15;
            setState(() {});
          },
        ),
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Symbols.percent, size: 18, color: cTextMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Porcentaje Mínimo de Asistencia para Aprobación',
                      style: GoogleFonts.plusJakartaSans(
                        color: cTextMain,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: porcentaje >= 75 ? cEmerald.withAlpha(35) : cAmber.withAlpha(35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: porcentaje >= 75 ? cEmerald : cAmber,
                    ),
                  ),
                  child: Text(
                    '${porcentaje.toInt()}%',
                    style: GoogleFonts.plusJakartaSans(
                      color: porcentaje >= 75 ? cEmerald : cAmber,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Umbral requerido para emitir certificados y considerar aprobada a la alumna.',
              style: GoogleFonts.plusJakartaSans(color: cTextMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 10),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: cPrimary,
                inactiveTrackColor: cBorder,
                thumbColor: cPrimary,
                overlayColor: cPrimaryGlow,
                trackHeight: 5,
              ),
              child: Slider(
                value: porcentaje.clamp(50.0, 100.0),
                min: 50.0,
                max: 100.0,
                divisions: 50,
                label: '${porcentaje.toInt()}%',
                onChanged: (newVal) {
                  setState(() {
                    _currentValues['porcentaje_minimo_asistencia_aprobacion'] = newVal.toInt();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          keyName: 'bloqueo_edicion_asistencia_dias',
          label: 'Días de Bloqueo para Edición de Asistencia',
          helperText: 'Pasados estos días desde la clase, solo el Super Admin podrá modificar el registro.',
          suffixText: 'días',
          icon: Symbols.lock_clock,
          isNumeric: true,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 1) return 'Ingresa al menos 1 día de plazo';
            return null;
          },
          onChanged: (val) {
            _currentValues['bloqueo_edicion_asistencia_dias'] = int.tryParse(val) ?? 3;
            setState(() {});
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN B: AUTOMATIZACIONES Y NOTIFICACIONES (n8n / WhatsApp)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAutomationSection() {
    return _buildSectionCard(
      title: 'Automatización y Notificaciones (n8n / WhatsApp)',
      subtitle: 'Integración vía Webhooks HTTP, recordatorios de cuotas y mensajería',
      icon: Symbols.alt_route,
      accentColor: cSky,
      children: [
        _buildTextField(
          keyName: 'n8n_webhook_notificaciones',
          label: 'Webhook de Notificaciones (n8n / API Gateway)',
          helperText: 'Endpoint que recibe los eventos de recordatorios y confirmaciones.',
          icon: Symbols.webhook,
          keyboardType: TextInputType.url,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'El webhook es requerido';
            final uri = Uri.tryParse(v.trim());
            if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
              return 'Ingresa una URL válida (ej: https://n8n.servidor.com/webhook/...)';
            }
            return null;
          },
          onChanged: (val) {
            _currentValues['n8n_webhook_notificaciones'] = val.trim();
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          keyName: 'recordatorio_pagos_dias_previos',
          label: 'Días Previos para Recordatorio de Pago / Insumos',
          helperText: 'Anticipación con la que se disparará el recordatorio vía WhatsApp.',
          suffixText: 'días antes',
          icon: Symbols.notification_important,
          isNumeric: true,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 1) return 'Ingresa al menos 1 día';
            return null;
          },
          onChanged: (val) {
            _currentValues['recordatorio_pagos_dias_previos'] = int.tryParse(val) ?? 2;
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          keyName: 'plantilla_mensaje_bienvenida',
          label: 'Plantilla de Mensaje de Bienvenida',
          helperText: 'Variables dinámicas soportadas: {nombre}, {cedula}, {curso}.',
          icon: Symbols.chat,
          maxLines: 4,
          minLines: 3,
          onChanged: (val) {
            _currentValues['plantilla_mensaje_bienvenida'] = val;
            setState(() {});
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN C: GESTIÓN DE ARCHIVOS Y ALMACENAMIENTO
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStorageSection() {
    final rawFormatos = _currentValues['formatos_permitidos_comprobantes'];
    final List<String> formatos = (rawFormatos is List)
        ? rawFormatos.map((e) => e.toString().toLowerCase().replaceAll('.', '')).toList()
        : ['jpg', 'jpeg', 'png', 'pdf'];

    final bool compresionActiva = _currentValues['compresion_imagenes_activa'] == true;

    return _buildSectionCard(
      title: 'Gestión de Archivos y Almacenamiento',
      subtitle: 'Límites de tamaño, formatos autorizados y optimización de comprobantes',
      icon: Symbols.cloud_upload,
      accentColor: cEmerald,
      children: [
        _buildTextField(
          keyName: 'max_file_size_mb_comprobante',
          label: 'Tamaño Máximo de Comprobante de Pago',
          helperText: 'Peso tope permitido al subir imágenes o PDFs desde el portal de la alumna.',
          suffixText: 'Megabytes (MB)',
          icon: Symbols.inventory_2,
          isNumeric: true,
          validator: (v) {
            final n = num.tryParse(v ?? '');
            if (n == null || n <= 0) return 'Ingresa un tamaño válido mayor a 0 MB';
            return null;
          },
          onChanged: (val) {
            _currentValues['max_file_size_mb_comprobante'] = num.tryParse(val) ?? 5;
            setState(() {});
          },
        ),
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Symbols.extension, size: 18, color: cTextMuted),
                const SizedBox(width: 8),
                Text(
                  'Formatos Permitidos para Comprobantes',
                  style: GoogleFonts.plusJakartaSans(
                    color: cTextMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Extensiones admitidas por la cámara y selector de archivos.',
              style: GoogleFonts.plusJakartaSans(color: cTextMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...formatos.map((fmt) {
                  return Chip(
                    backgroundColor: cCardInner,
                    side: const BorderSide(color: cBorder),
                    avatar: const Icon(Symbols.description, size: 16, color: cEmerald),
                    label: Text(
                      fmt.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: cTextMain,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14, color: cTextMuted),
                    onDeleted: formatos.length > 1
                        ? () {
                            setState(() {
                              formatos.remove(fmt);
                              _currentValues['formatos_permitidos_comprobantes'] = formatos;
                            });
                          }
                        : null,
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _nuevoFormatoController,
                      style: const TextStyle(color: cTextMain, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Añadir extensión (ej: webp, heic)...',
                        hintStyle: const TextStyle(color: cTextDim, fontSize: 12),
                        filled: true,
                        fillColor: cCardInner,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: cBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: cBorder),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cCardInner,
                    foregroundColor: cTextMain,
                    side: const BorderSide(color: cBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onPressed: () {
                    final nuevo = _nuevoFormatoController.text.trim().toLowerCase().replaceAll('.', '');
                    if (nuevo.isNotEmpty && !formatos.contains(nuevo)) {
                      setState(() {
                        formatos.add(nuevo);
                        _currentValues['formatos_permitidos_comprobantes'] = formatos;
                        _nuevoFormatoController.clear();
                      });
                    }
                  },
                  icon: const Icon(Symbols.add, size: 18, color: cEmerald),
                  label: const Text('Añadir Formato', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSwitchTile(
          title: 'Compresión Automática de Imágenes',
          subtitle: 'Reduce el peso de capturas antes de la subida para ahorrar ancho de banda y almacenamiento.',
          icon: Symbols.compress,
          value: compresionActiva,
          activeColor: cEmerald,
          onChanged: (val) {
            setState(() {
              _currentValues['compresion_imagenes_activa'] = val;
            });
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN D: ENTORNO DEL SISTEMA Y MANTENIMIENTO
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEnvironmentSection() {
    final bool modoMantenimiento = _currentValues['modo_mantenimiento'] == true;

    return _buildSectionCard(
      title: 'Entorno del Sistema y Mantenimiento',
      subtitle: 'Control de disponibilidad operacional, versión mínima y tasa cambiaria',
      icon: Symbols.tune,
      accentColor: cAmber,
      children: [
        _buildSwitchTile(
          title: 'Modo Mantenimiento Global',
          subtitle: modoMantenimiento
              ? 'ACTIVADO: El acceso para estudiantes y profesores se encuentra bloqueado.'
              : 'DESACTIVADO: La plataforma opera normalmente con todas las funciones activas.',
          icon: Symbols.construction,
          value: modoMantenimiento,
          activeColor: cAmber,
          onChanged: (val) => _toggleModoMantenimiento(val),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          keyName: 'version_minima_app',
          label: 'Versión Mínima Requerida de la App',
          helperText: 'Clientes móviles con versiones inferiores forzarán actualización.',
          icon: Symbols.phone_android,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'La versión es requerida';
            if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(v.trim())) {
              return 'Formato semántico requerido: Mayor.Menor.Parche (ej: 1.0.0)';
            }
            return null;
          },
          onChanged: (val) {
            _currentValues['version_minima_app'] = val.trim();
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          keyName: 'tasa_cambio_oficial',
          label: 'Tasa de Cambio Oficial de Referencia (Bs / USD)',
          helperText: 'Referencia oficial para el cálculo y auditoría de insumos en bolívares.',
          prefixText: 'Bs. ',
          icon: Symbols.currency_exchange,
          isNumeric: true,
          validator: (v) {
            final n = double.tryParse(v ?? '');
            if (n == null || n <= 0) return 'Ingresa una tasa numérica válida mayor a 0';
            return null;
          },
          onChanged: (val) {
            _currentValues['tasa_cambio_oficial'] = double.tryParse(val) ?? 36.50;
            setState(() {});
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN E: SEGURIDAD Y AUDITORÍA DE LOGS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSecuritySection() {
    return _buildSectionCard(
      title: 'Seguridad y Registros de Auditoría',
      subtitle: 'Políticas de retención de trazas y protección contra ataques de fuerza bruta',
      icon: Symbols.shield,
      accentColor: const Color(0xFFA855F7), // Purple 500
      children: [
        _buildTextField(
          keyName: 'dias_retencion_logs',
          label: 'Días de Retención de Logs de Auditoría',
          helperText: 'Trazas con antigüedad mayor serán depuradas periódicamente.',
          suffixText: 'días',
          icon: Symbols.manage_history,
          isNumeric: true,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 7) return 'Se requiere una retención mínima de 7 días';
            return null;
          },
          onChanged: (val) {
            _currentValues['dias_retencion_logs'] = int.tryParse(val) ?? 90;
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          keyName: 'limite_intentos_login',
          label: 'Límite de Intentos Fallidos de Inicio de Sesión',
          helperText: 'Número de fallos consecutivos antes de imponer bloqueo temporal.',
          suffixText: 'intentos',
          icon: Symbols.login,
          isNumeric: true,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 3) return 'Mínimo 3 intentos permitidos';
            return null;
          },
          onChanged: (val) {
            _currentValues['limite_intentos_login'] = int.tryParse(val) ?? 5;
            setState(() {});
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withAlpha(80)),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: cTextMain,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: cTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: cBorder, height: 1),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String keyName,
    required String label,
    required String helperText,
    required IconData icon,
    String? suffixText,
    String? prefixText,
    bool isNumeric = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    int minLines = 1,
    String? Function(String?)? validator,
    required ValueChanged<String> onChanged,
  }) {
    final controller = _controllers[keyName];
    final isModified = _getModifiedKeys().contains(keyName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: isModified ? cPrimary : cTextMain,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            if (isModified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cPrimary.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Modificado',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: cPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: minLines,
          keyboardType: keyboardType ??
              (isNumeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text),
          inputFormatters: isNumeric
              ? [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ]
              : null,
          style: const TextStyle(color: cTextMain, fontSize: 13.5),
          decoration: InputDecoration(
            filled: true,
            fillColor: cCardInner,
            prefixIcon: Icon(icon, color: isModified ? cPrimary : cTextDim, size: 20),
            prefixText: prefixText,
            prefixStyle: const TextStyle(color: cTextMain, fontWeight: FontWeight.bold),
            suffixText: suffixText,
            suffixStyle: const TextStyle(color: cTextMuted, fontSize: 12),
            helperText: helperText,
            helperMaxLines: 2,
            helperStyle: const TextStyle(color: cTextDim, fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isModified ? cPrimary.withAlpha(150) : cBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cPrimary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cCardInner,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? activeColor.withAlpha(120) : cBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (value ? activeColor : cTextDim).withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? activeColor : cTextMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: cTextMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: cTextMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: value,
            activeThumbColor: activeColor,
            activeTrackColor: activeColor.withAlpha(100),
            inactiveThumbColor: cTextDim,
            inactiveTrackColor: cBorder,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(int modifiedCount) {
    return Container(
      decoration: BoxDecoration(
        color: cCard.withAlpha(245),
        border: const Border(top: BorderSide(color: cBorder)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modifiedCount > 0
                      ? '$modifiedCount cambio(s) pendiente(s)'
                      : 'Sin cambios pendientes',
                  style: GoogleFonts.plusJakartaSans(
                    color: modifiedCount > 0 ? cAmber : cTextMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  'Tabla: public.configuracion_general',
                  style: GoogleFonts.plusJakartaSans(
                    color: cTextDim,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: cPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: cPrimaryGlow,
              ),
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 20),
              label: Text(
                _isSaving ? 'Guardando en Supabase...' : 'Guardar Cambios',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
