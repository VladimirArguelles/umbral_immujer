import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_form_widgets.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_tokens.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// File size, accepted extensions, and image compression settings section.
class GeneralSettingsStorageSection extends StatelessWidget {
  const GeneralSettingsStorageSection({
    super.key,
    required this.values,
    required this.modifiedKeys,
    required this.controllers,
    required this.newFormatController,
    required this.onValueChanged,
  });

  final Map<String, dynamic> values;
  final Set<String> modifiedKeys;
  final Map<String, TextEditingController> controllers;
  final TextEditingController newFormatController;
  final void Function(String key, dynamic value) onValueChanged;

  @override
  Widget build(BuildContext context) {
    final rawFormatos = values['formatos_permitidos_comprobantes'];
    final formatos = (rawFormatos is List)
        ? rawFormatos
              .map((e) => e.toString().toLowerCase().replaceAll('.', ''))
              .toList()
        : ['jpg', 'jpeg', 'png', 'pdf'];
    final compresionActiva = values['compresion_imagenes_activa'] == true;

    return GeneralSettingsSectionCard(
      title: 'Gestión de Archivos y Almacenamiento',
      subtitle:
          'Límites de tamaño, formatos autorizados y optimización de comprobantes',
      icon: Symbols.cloud_upload,
      accentColor: GeneralSettingsTokens.emerald,
      children: [
        GeneralSettingsTextField(
          controller: controllers['max_file_size_mb_comprobante'],
          isModified: modifiedKeys.contains('max_file_size_mb_comprobante'),
          label: 'Tamaño Máximo de Comprobante de Pago',
          helperText:
              'Peso tope permitido al subir imágenes o PDFs desde el portal del alumno.',
          suffixText: 'Megabytes (MB)',
          icon: Symbols.inventory_2,
          isNumeric: true,
          validator: (v) {
            final n = num.tryParse(v ?? '');
            if (n == null || n <= 0) {
              return 'Ingresa un tamaño válido mayor a 0 MB';
            }
            return null;
          },
          onChanged: (val) => onValueChanged(
            'max_file_size_mb_comprobante',
            num.tryParse(val) ?? 5,
          ),
        ),
        const SizedBox(height: 20),
        _AllowedFormatsEditor(
          formats: formatos,
          newFormatController: newFormatController,
          onFormatsUpdated: (updated) =>
              onValueChanged('formatos_permitidos_comprobantes', updated),
        ),
        const SizedBox(height: 20),
        GeneralSettingsSwitchTile(
          title: 'Compresión Automática de Imágenes',
          subtitle:
              'Reduce el peso de capturas antes de la subida para ahorrar ancho de banda y almacenamiento.',
          icon: Symbols.compress,
          value: compresionActiva,
          activeColor: GeneralSettingsTokens.emerald,
          onChanged: (val) => onValueChanged('compresion_imagenes_activa', val),
        ),
      ],
    );
  }
}

class _AllowedFormatsEditor extends StatelessWidget {
  const _AllowedFormatsEditor({
    required this.formats,
    required this.newFormatController,
    required this.onFormatsUpdated,
  });

  final List<String> formats;
  final TextEditingController newFormatController;
  final ValueChanged<List<String>> onFormatsUpdated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Symbols.extension,
              size: 18,
              color: GeneralSettingsTokens.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Formatos Permitidos para Comprobantes',
                softWrap: true,
                style: GoogleFonts.plusJakartaSans(
                  color: GeneralSettingsTokens.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Extensiones admitidas por la cámara y selector de archivos.',
          style: GoogleFonts.plusJakartaSans(
            color: GeneralSettingsTokens.textMuted,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final fmt in formats)
              Chip(
                backgroundColor: GeneralSettingsTokens.cardInner,
                side: const BorderSide(color: GeneralSettingsTokens.border),
                avatar: const Icon(
                  Symbols.description,
                  size: 16,
                  color: GeneralSettingsTokens.emerald,
                ),
                label: Text(
                  fmt.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: GeneralSettingsTokens.textMain,
                  ),
                ),
                deleteIcon: const Icon(
                  Icons.close,
                  size: 14,
                  color: GeneralSettingsTokens.textMuted,
                ),
                onDeleted: formats.length > 1
                    ? () {
                        final updated = List<String>.from(formats)..remove(fmt);
                        onFormatsUpdated(updated);
                      }
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: newFormatController,
                  style: const TextStyle(
                    color: GeneralSettingsTokens.textMain,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Añadir extensión (ej: webp, heic)...',
                    hintStyle: const TextStyle(
                      color: GeneralSettingsTokens.textDim,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: GeneralSettingsTokens.cardInner,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: GeneralSettingsTokens.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: GeneralSettingsTokens.border,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GeneralSettingsTokens.cardInner,
                foregroundColor: GeneralSettingsTokens.textMain,
                side: const BorderSide(color: GeneralSettingsTokens.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                final nuevo = newFormatController.text
                    .trim()
                    .toLowerCase()
                    .replaceAll('.', '');
                if (nuevo.isNotEmpty && !formats.contains(nuevo)) {
                  final updated = List<String>.from(formats)..add(nuevo);
                  newFormatController.clear();
                  onFormatsUpdated(updated);
                }
              },
              icon: const Icon(
                Symbols.add,
                size: 18,
                color: GeneralSettingsTokens.emerald,
              ),
              label: const Text(
                'Añadir Formato',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Global maintenance switch and official BCV exchange rate section.
class GeneralSettingsEnvironmentSection extends StatelessWidget {
  const GeneralSettingsEnvironmentSection({
    super.key,
    required this.values,
    required this.modifiedKeys,
    required this.controllers,
    required this.onToggleMaintenance,
    required this.onValueChanged,
  });

  final Map<String, dynamic> values;
  final Set<String> modifiedKeys;
  final Map<String, TextEditingController> controllers;
  final ValueChanged<bool> onToggleMaintenance;
  final void Function(String key, dynamic value) onValueChanged;

  @override
  Widget build(BuildContext context) {
    final modoMantenimiento = values['modo_mantenimiento'] == true;

    return GeneralSettingsSectionCard(
      title: 'Entorno del Sistema y Mantenimiento',
      subtitle: 'Control de disponibilidad operacional y tasa cambiaria oficial',
      icon: Symbols.tune,
      accentColor: GeneralSettingsTokens.amber,
      children: [
        GeneralSettingsSwitchTile(
          title: 'Modo Mantenimiento Global',
          subtitle: modoMantenimiento
              ? 'ACTIVADO: El acceso para estudiantes y profesores se encuentra bloqueado.'
              : 'DESACTIVADO: La plataforma opera normalmente con todas las funciones activas.',
          icon: Symbols.construction,
          value: modoMantenimiento,
          activeColor: GeneralSettingsTokens.amber,
          onChanged: onToggleMaintenance,
        ),
        const SizedBox(height: 16),
        GeneralSettingsTextField(
          controller: controllers['tasa_cambio_oficial'],
          isModified: modifiedKeys.contains('tasa_cambio_oficial'),
          label: 'Tasa de Cambio Oficial de Referencia (Bs / USD)',
          helperText:
              'Referencia oficial para el cálculo y auditoría de insumos en bolívares.',
          prefixText: 'Bs. ',
          icon: Symbols.currency_exchange,
          isNumeric: true,
          validator: (v) {
            final n = double.tryParse(v ?? '');
            if (n == null || n <= 0) {
              return 'Ingresa una tasa numérica válida mayor a 0';
            }
            return null;
          },
          onChanged: (val) => onValueChanged(
            'tasa_cambio_oficial',
            double.tryParse(val) ?? 36.50,
          ),
        ),
      ],
    );
  }
}

/// Log retention and failed login threshold security settings section.
class GeneralSettingsSecuritySection extends StatelessWidget {
  const GeneralSettingsSecuritySection({
    super.key,
    required this.modifiedKeys,
    required this.controllers,
    required this.onValueChanged,
  });

  final Set<String> modifiedKeys;
  final Map<String, TextEditingController> controllers;
  final void Function(String key, dynamic value) onValueChanged;

  @override
  Widget build(BuildContext context) {
    return GeneralSettingsSectionCard(
      title: 'Seguridad y Registros de Auditoría',
      subtitle:
          'Políticas de retención de trazas y protección contra ataques de fuerza bruta',
      icon: Symbols.shield,
      accentColor: AppTheme.secondary,
      children: [
        GeneralSettingsTextField(
          controller: controllers['dias_retencion_logs'],
          isModified: modifiedKeys.contains('dias_retencion_logs'),
          label: 'Días de Retención de Logs de Auditoría',
          helperText:
              'Trazas con antigüedad mayor serán depuradas periódicamente.',
          suffixText: 'días',
          icon: Symbols.manage_history,
          isNumeric: true,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 7) {
              return 'Se requiere una retención mínima de 7 días';
            }
            return null;
          },
          onChanged: (val) =>
              onValueChanged('dias_retencion_logs', int.tryParse(val) ?? 90),
        ),
        const SizedBox(height: 16),
        GeneralSettingsTextField(
          controller: controllers['limite_intentos_login'],
          isModified: modifiedKeys.contains('limite_intentos_login'),
          label: 'Límite de Intentos Fallidos de Inicio de Sesión',
          helperText:
              'Número de fallos consecutivos antes de imponer bloqueo temporal.',
          suffixText: 'intentos',
          icon: Symbols.login,
          isNumeric: true,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 3) return 'Mínimo 3 intentos permitidos';
            return null;
          },
          onChanged: (val) =>
              onValueChanged('limite_intentos_login', int.tryParse(val) ?? 5),
        ),
      ],
    );
  }
}
