import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/inscripciones/presentation/widgets/inscripciones_admin_panel_widget.dart';
import 'package:umbral_immujer/features/superadmin/data/supabase_general_settings_repository.dart';
import 'package:umbral_immujer/features/superadmin/domain/general_settings_repository.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_academic_automation_sections.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_chrome.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_dialogs.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_storage_security_sections.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_tokens.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/responsive.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';
import 'package:umbral_immujer/src/core/widgets/super_admin_nav_bar.dart';

class ConfiguracionGeneralScreen extends StatefulWidget {
  const ConfiguracionGeneralScreen({super.key, this.repository});

  final GeneralSettingsRepository? repository;

  @override
  State<ConfiguracionGeneralScreen> createState() =>
      _ConfiguracionGeneralScreenState();
}

class _ConfiguracionGeneralScreenState
    extends State<ConfiguracionGeneralScreen> {
  late final GeneralSettingsRepository _repository;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  final Map<String, dynamic> _initialValues = {};
  final Map<String, dynamic> _currentValues = {};
  final Map<String, TextEditingController> _controllers = {};
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nuevoFormatoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseGeneralSettingsRepository();
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

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fetched = await _repository.fetchSettings();
      _initialValues
        ..clear()
        ..addAll(fetched);
      _currentValues
        ..clear()
        ..addAll(fetched);

      for (final entry in defaultGeneralSettings.entries) {
        if (!_currentValues.containsKey(entry.key) ||
            _currentValues[entry.key] == null) {
          _currentValues[entry.key] = entry.value;
          _initialValues[entry.key] = entry.value;
        }
      }

      _syncControllers();

      if (mounted) {
        setState(() => _isLoading = false);
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

  void _syncControllers() {
    const controllerKeys = [
      'tolerancia_minutos_asistencia',
      'bloqueo_edicion_asistencia_dias',
      'webhook_notificaciones',
      'recordatorio_pagos_dias_previos',
      'plantilla_mensaje_bienvenida',
      'max_file_size_mb_comprobante',
      'tasa_cambio_oficial',
      'dias_retencion_logs',
      'limite_intentos_login',
    ];
    for (final key in controllerKeys) {
      final text =
          _currentValues[key]?.toString() ??
          defaultGeneralSettings[key]?.toString() ??
          '';
      if (_controllers.containsKey(key)) {
        _controllers[key]!.text = text;
      } else {
        _controllers[key] = TextEditingController(text: text);
      }
    }
  }

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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      showGeneralSettingsToast(
        context,
        'Por favor corrige los campos con errores antes de guardar.',
        isError: true,
      );
      return;
    }

    final modifiedKeys = _getModifiedKeys();
    if (modifiedKeys.isEmpty) {
      showGeneralSettingsToast(context, 'No hay cambios pendientes por guardar.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updates = {
        for (final key in modifiedKeys) key: _currentValues[key],
      };
      await _repository.saveSettings(updates);
      for (final key in modifiedKeys) {
        _initialValues[key] = _currentValues[key];
      }
      if (mounted) {
        showGeneralSettingsToast(
          context,
          '¡Configuración guardada exitosamente! (${modifiedKeys.length} parámetros actualizados)',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showGeneralSettingsToast(
          context,
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

  Future<void> _confirmResetValues() async {
    final modifiedKeys = _getModifiedKeys();
    if (modifiedKeys.isEmpty) {
      await _loadSettings();
      if (mounted) {
        showGeneralSettingsToast(
          context,
          'Valores recargados desde la base de datos.',
        );
      }
      return;
    }

    final confirm = await confirmGeneralSettingsReset(
      context,
      modifiedCount: modifiedKeys.length,
    );
    if (!mounted) return;
    if (confirm) {
      await _loadSettings();
      if (mounted) {
        showGeneralSettingsToast(
          context,
          'Valores restablecidos desde la base de datos.',
        );
      }
    }
  }

  Future<void> _toggleModoMantenimiento(bool newValue) async {
    final confirm = await confirmMaintenanceModeToggle(
      context,
      enableMaintenance: newValue,
    );
    if (confirm && mounted) {
      setState(() => _currentValues['modo_mantenimiento'] = newValue);
    }
  }

  void _updateValue(String key, dynamic value) {
    setState(() => _currentValues[key] = value);
  }

  @override
  Widget build(BuildContext context) {
    final modifiedKeys = _getModifiedKeys();
    final modifiedCount = modifiedKeys.length;

    return Theme(
      data: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: GeneralSettingsTokens.bg,
        colorScheme: const ColorScheme.dark(
          primary: GeneralSettingsTokens.primary,
          surface: GeneralSettingsTokens.card,
        ),
      ),
      child: Scaffold(
        backgroundColor: GeneralSettingsTokens.bg,
        appBar: GeneralSettingsAppBar(
          isBusy: _isLoading || _isSaving,
          onResetPressed: _confirmResetValues,
        ),
        body: _isLoading
            ? const DashboardSkeleton()
            : _errorMessage != null
            ? _buildErrorState()
            : _buildFormBody(modifiedKeys, modifiedCount),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GeneralSettingsBottomBar(
              modifiedCount: modifiedCount,
              isSaving: _isSaving,
              onSave: _saveChanges,
            ),
            const SuperAdminBottomNavBar(currentIndex: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Symbols.cloud_off,
              size: 48,
              color: GeneralSettingsTokens.primary,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: GeneralSettingsTokens.primary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GeneralSettingsTokens.card,
                foregroundColor: GeneralSettingsTokens.textMain,
                side: const BorderSide(color: GeneralSettingsTokens.border),
              ),
              onPressed: _loadSettings,
              icon: const Icon(Symbols.refresh, size: 18),
              label: const Text('Reintentar Conexión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormBody(Set<String> modifiedKeys, int modifiedCount) {
    final academic = GeneralSettingsAcademicSection(
      values: _currentValues,
      modifiedKeys: modifiedKeys,
      controllers: _controllers,
      onValueChanged: _updateValue,
    );
    final storage = GeneralSettingsStorageSection(
      values: _currentValues,
      modifiedKeys: modifiedKeys,
      controllers: _controllers,
      newFormatController: _nuevoFormatoController,
      onValueChanged: _updateValue,
    );
    final automation = GeneralSettingsAutomationSection(
      modifiedKeys: modifiedKeys,
      controllers: _controllers,
      onValueChanged: _updateValue,
      onShowSuccessToast: (msg) =>
          showGeneralSettingsToast(context, msg, isSuccess: true),
    );
    final environment = GeneralSettingsEnvironmentSection(
      values: _currentValues,
      modifiedKeys: modifiedKeys,
      controllers: _controllers,
      onToggleMaintenance: _toggleModoMantenimiento,
      onValueChanged: _updateValue,
    );
    final security = GeneralSettingsSecuritySection(
      modifiedKeys: modifiedKeys,
      controllers: _controllers,
      onValueChanged: _updateValue,
    );

    return Form(
      key: _formKey,
      child: Responsive.constrainedContainer(
        maxWidth: 1200,
        child: ResponsiveBuilder(
          builder: (context, screenType, constraints) {
            final isMultiCol = screenType != ScreenType.mobile;
            final padding = Responsive.screenPadding(context);

            if (isMultiCol) {
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  padding.left,
                  20,
                  padding.right,
                  100,
                ),
                children: [
                  if (modifiedCount > 0)
                    GeneralSettingsPendingBanner(count: modifiedCount),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            academic,
                            const SizedBox(height: 20),
                            storage,
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            const InscripcionesAdminPanelWidget(),
                            const SizedBox(height: 20),
                            automation,
                            const SizedBox(height: 20),
                            environment,
                            const SizedBox(height: 20),
                            security,
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                20,
                padding.right,
                100,
              ),
              children: [
                if (modifiedCount > 0)
                  GeneralSettingsPendingBanner(count: modifiedCount),
                const InscripcionesAdminPanelWidget(),
                const SizedBox(height: 20),
                academic,
                const SizedBox(height: 20),
                automation,
                const SizedBox(height: 20),
                storage,
                const SizedBox(height: 20),
                environment,
                const SizedBox(height: 20),
                security,
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}
