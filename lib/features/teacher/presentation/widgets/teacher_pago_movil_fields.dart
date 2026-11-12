import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Venezuelan banks supported for teacher Pago Móvil deposits.
const List<String> teacherPagoMovilBanks = [
  'Banco de Venezuela (0102)',
  'Banesco (0134)',
  'Mercantil (0105)',
  'BBVA Provincial (0108)',
  'Banco Nacional de Crédito BNC (0191)',
  'Bancaribe (0114)',
  'Banco Exterior (0115)',
  'Banco Bicentenario (0175)',
  'Bancamiga (0172)',
  'Banplus (0174)',
  '100% Banco (0156)',
  'Otro Banco',
];

/// Displays the official BCV exchange rate badge used when creating/editing surveys.
class TeacherBcvRateBadge extends StatelessWidget {
  const TeacherBcvRateBadge({
    super.key,
    required this.rate,
    this.valueDate,
  });

  final double rate;
  final String? valueDate;

  @override
  Widget build(BuildContext context) {
    final datePart = valueDate != null ? ': $valueDate' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.mintNeon.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.currency_exchange,
            size: 15,
            color: AppTheme.mintNeon,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tasa BCV oficial (Fecha Valor$datePart): Bs. ${rate.toStringAsFixed(2)} / USD',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.mintNeon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared Pago Móvil form block reused by Create and Edit survey sheets/dialogs.
class TeacherPagoMovilFields extends StatelessWidget {
  const TeacherPagoMovilFields({
    super.key,
    required this.cedulaController,
    required this.telefonoController,
    required this.selectedBank,
    required this.customBankController,
    required this.onBankChanged,
  });

  final TextEditingController cedulaController;
  final TextEditingController telefonoController;
  final String selectedBank;
  final TextEditingController customBankController;
  final ValueChanged<String> onBankChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.phone_android_rounded,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Datos de Pago Móvil para Depósito de Alumnos',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Los alumnos verán estos datos para realizar su transferencia o pago móvil de insumos.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: cedulaController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Cédula de Identidad del Titular *',
              prefixIcon: Icon(Icons.badge_outlined),
              hintText: 'Ej. 12345678 o V-12345678',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Por favor ingresa la cédula para el Pago Móvil'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: telefonoController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Número de Teléfono Pago Móvil *',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: 'Ej. 04141234567',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Por favor ingresa el teléfono para el Pago Móvil'
                : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: selectedBank,
            decoration: const InputDecoration(
              labelText: 'Banco Destino',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
            items: teacherPagoMovilBanks
                .map(
                  (bank) => DropdownMenuItem(
                    value: bank,
                    child: Text(
                      bank,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) onBankChanged(val);
            },
          ),
          if (selectedBank == 'Otro Banco') ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: customBankController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Banco',
                prefixIcon: Icon(Icons.account_balance),
                hintText: 'Ej. Banco Activo',
              ),
              validator: (v) {
                if (selectedBank == 'Otro Banco' &&
                    (v == null || v.trim().isEmpty)) {
                  return 'Ingresa el nombre del banco';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }
}
