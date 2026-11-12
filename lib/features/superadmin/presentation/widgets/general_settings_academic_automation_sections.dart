import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_form_widgets.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_tokens.dart';
import 'package:umbral_immujer/src/core/services/push_notification_service.dart';

/// Academic auditing and attendance threshold configuration section.
class GeneralSettingsAcademicSection extends StatelessWidget {
  const GeneralSettingsAcademicSection({
    super.key,
    required this.values,
    required this.modifiedKeys,
    required this.controllers,
    required this.onValueChanged,
  });

  final Map<String, dynamic> values;
  final Set<String> modifiedKeys;
  final Map<String, TextEditingController> controllers;
  final void Function(String key, dynamic value) onValueChanged;

  @override
  Widget build(BuildContext context) {
    final porcentaje =
        (values['porcentaje_minimo_asistencia_aprobacion'] as num?)
            ?.toDouble() ??
        75.0;

    return GeneralSettingsSectionCard(
      title: 'Auditoría Académica y Asistencia',
      subtitle:
          'Parámetros de tolerancia, bloqueo de fechas y porcentaje para pase de curso',
      icon: Symbols.fact_check,
      accentColor: GeneralSettingsTokens.primary,
      children: [
        GeneralSettingsTextField(
          controller: controllers['tolerancia_minutos_asistencia'],
          isModified: modifiedKeys.contains('tolerancia_minutos_asistencia'),
          label: 'Tolerancia en Minutos para Asistencia',
          helperText:
              'Tiempo límite después de la hora de inicio para considerar presencia válida.',
          suffixText: 'minutos',
          icon: Symbols.timer,
          isNumeric: true,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 0) {
              return 'Ingresa un número entero mayor o igual a 0';
            }
            return null;
          },
          onChanged: (val) => onValueChanged(
            'tolerancia_minutos_asistencia',
            int.tryParse(val) ?? 15,
          ),
        ),
        const SizedBox(height: 20),
        _MinimumAttendanceSlider(
          percentage: porcentaje,
          onChanged: (newVal) => onValueChanged(
            'porcentaje_minimo_asistencia_aprobacion',
            newVal.toInt(),
          ),
        ),
        const SizedBox(height: 16),
        GeneralSettingsTextField(
          controller: controllers['bloqueo_edicion_asistencia_dias'],
          isModified: modifiedKeys.contains('bloqueo_edicion_asistencia_dias'),
          label: 'Días de Bloqueo para Edición de Asistencia',
          helperText:
              'Pasados estos días desde la clase, solo el Super Admin podrá modificar el registro.',
          suffixText: 'días',
          icon: Symbols.lock_clock,
          isNumeric: true,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 1) return 'Ingresa al menos 1 día de plazo';
            return null;
          },
          onChanged: (val) => onValueChanged(
            'bloqueo_edicion_asistencia_dias',
            int.tryParse(val) ?? 3,
          ),
        ),
      ],
    );
  }
}

class _MinimumAttendanceSlider extends StatelessWidget {
  const _MinimumAttendanceSlider({
    required this.percentage,
    required this.onChanged,
  });

  final double percentage;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final badgeColor = percentage >= 75
        ? GeneralSettingsTokens.emerald
        : GeneralSettingsTokens.amber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Symbols.percent,
                    size: 18,
                    color: GeneralSettingsTokens.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Porcentaje Mínimo de Asistencia para Aprobación',
                      style: GoogleFonts.plusJakartaSans(
                        color: GeneralSettingsTokens.textMain,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: badgeColor),
              ),
              child: Text(
                '${percentage.toInt()}%',
                style: GoogleFonts.plusJakartaSans(
                  color: badgeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Umbral requerido para emitir certificados y considerar aprobado al alumno.',
          style: GoogleFonts.plusJakartaSans(
            color: GeneralSettingsTokens.textMuted,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: GeneralSettingsTokens.primary,
            inactiveTrackColor: GeneralSettingsTokens.border,
            thumbColor: GeneralSettingsTokens.primary,
            overlayColor: GeneralSettingsTokens.primaryGlow,
            trackHeight: 5,
          ),
          child: Slider(
            value: percentage.clamp(50.0, 100.0),
            min: 50.0,
            max: 100.0,
            divisions: 50,
            label: '${percentage.toInt()}%',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Webhooks, automated reminders, and push notification testing section.
class GeneralSettingsAutomationSection extends StatelessWidget {
  const GeneralSettingsAutomationSection({
    super.key,
    required this.modifiedKeys,
    required this.controllers,
    required this.onValueChanged,
    required this.onShowSuccessToast,
  });

  final Set<String> modifiedKeys;
  final Map<String, TextEditingController> controllers;
  final void Function(String key, dynamic value) onValueChanged;
  final ValueChanged<String> onShowSuccessToast;

  @override
  Widget build(BuildContext context) {
    return GeneralSettingsSectionCard(
      title: 'Automatización y Notificaciones (WhatsApp / Webhook)',
      subtitle:
          'Integración vía Webhook directo HTTP, recordatorios de cuotas y mensajería',
      icon: Symbols.alt_route,
      accentColor: GeneralSettingsTokens.sky,
      children: [
        GeneralSettingsTextField(
          controller: controllers['webhook_notificaciones'],
          isModified: modifiedKeys.contains('webhook_notificaciones'),
          label: 'Webhook de Notificaciones (API Gateway / WhatsApp)',
          helperText:
              'Endpoint que recibe los eventos de recordatorios y confirmaciones.',
          icon: Symbols.webhook,
          keyboardType: TextInputType.url,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'El webhook es requerido';
            final uri = Uri.tryParse(v.trim());
            if (uri == null ||
                (!uri.isScheme('http') && !uri.isScheme('https'))) {
              return 'Ingresa una URL válida (ej: https://api.servidor.com/webhook/...)';
            }
            return null;
          },
          onChanged: (val) =>
              onValueChanged('webhook_notificaciones', val.trim()),
        ),
        const SizedBox(height: 16),
        GeneralSettingsTextField(
          controller: controllers['recordatorio_pagos_dias_previos'],
          isModified: modifiedKeys.contains('recordatorio_pagos_dias_previos'),
          label: 'Días Previos para Recordatorio de Pago / Insumos',
          helperText:
              'Anticipación con la que se disparará el recordatorio vía WhatsApp.',
          suffixText: 'días antes',
          icon: Symbols.notification_important,
          isNumeric: true,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 1) return 'Ingresa al menos 1 día';
            return null;
          },
          onChanged: (val) => onValueChanged(
            'recordatorio_pagos_dias_previos',
            int.tryParse(val) ?? 2,
          ),
        ),
        const SizedBox(height: 16),
        GeneralSettingsTextField(
          controller: controllers['plantilla_mensaje_bienvenida'],
          isModified: modifiedKeys.contains('plantilla_mensaje_bienvenida'),
          label: 'Plantilla de Mensaje de Bienvenida',
          helperText:
              'Variables dinámicas soportadas: {nombre}, {cedula}, {curso}.',
          icon: Symbols.chat,
          maxLines: 4,
          minLines: 3,
          onChanged: (val) =>
              onValueChanged('plantilla_mensaje_bienvenida', val),
        ),
        const SizedBox(height: 18),
        _PushTesterBox(onShowSuccessToast: onShowSuccessToast),
      ],
    );
  }
}

class _PushTesterBox extends StatelessWidget {
  const _PushTesterBox({required this.onShowSuccessToast});

  final ValueChanged<String> onShowSuccessToast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GeneralSettingsTokens.cardInner,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: GeneralSettingsTokens.sky.withAlpha(90),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GeneralSettingsTokens.sky.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Symbols.notifications_active,
                  color: GeneralSettingsTokens.sky,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notificaciones Push (Barra de Estado / FCM)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: GeneralSettingsTokens.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Disparadores de prueba para validar avisos en el dispositivo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: GeneralSettingsTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(
                  Symbols.schedule,
                  size: 16,
                  color: GeneralSettingsTokens.sky,
                ),
                label: const Text(
                  'Horario de Clases',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () {
                  PushNotificationService.instance.alertClassScheduleChange(
                    cursoNombre: 'Costura y Confección',
                    nuevoHorario: 'Lunes y Miércoles 2:00 PM',
                  );
                  onShowSuccessToast(
                    'Notificación enviada a la barra de estado: Horario',
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(
                  Symbols.payments,
                  size: 16,
                  color: GeneralSettingsTokens.emerald,
                ),
                label: const Text(
                  'Aprobación de Aporte',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () {
                  PushNotificationService.instance.alertPaymentApproved(
                    cursoNombre: 'Panadería Artesanal',
                    monto: 15.0,
                  );
                  onShowSuccessToast(
                    'Notificación enviada a la barra de estado: Aporte',
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(
                  Symbols.fact_check,
                  size: 16,
                  color: GeneralSettingsTokens.amber,
                ),
                label: const Text(
                  'Recordatorio de Asistencia',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () {
                  PushNotificationService.instance.alertAttendanceReminder(
                    cursoNombre: 'Peluquería Básica',
                  );
                  onShowSuccessToast(
                    'Notificación enviada a la barra de estado: Asistencia',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
