import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/general_settings_tokens.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Card container grouping related configuration fields under a common header.
class GeneralSettingsSectionCard extends StatelessWidget {
  const GeneralSettingsSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GeneralSettingsTokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GeneralSettingsTokens.border),
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
                        color: GeneralSettingsTokens.textMain,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: GeneralSettingsTokens.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: GeneralSettingsTokens.border, height: 1),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

/// Validated form field that highlights unsaved changes with a modified badge.
class GeneralSettingsTextField extends StatelessWidget {
  const GeneralSettingsTextField({
    super.key,
    required this.controller,
    required this.isModified,
    required this.label,
    required this.helperText,
    required this.icon,
    required this.onChanged,
    this.suffixText,
    this.prefixText,
    this.isNumeric = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines = 1,
    this.validator,
  });

  final TextEditingController? controller;
  final bool isModified;
  final String label;
  final String helperText;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final String? suffixText;
  final String? prefixText;
  final bool isNumeric;
  final TextInputType? keyboardType;
  final int maxLines;
  final int minLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: isModified
                      ? GeneralSettingsTokens.primary
                      : GeneralSettingsTokens.textMain,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            if (isModified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: GeneralSettingsTokens.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Modificado',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: GeneralSettingsTokens.primary,
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
          keyboardType:
              keyboardType ??
              (isNumeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text),
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : null,
          style: const TextStyle(
            color: GeneralSettingsTokens.textMain,
            fontSize: 13.5,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: GeneralSettingsTokens.cardInner,
            prefixIcon: Icon(
              icon,
              color: isModified
                  ? GeneralSettingsTokens.primary
                  : GeneralSettingsTokens.textDim,
              size: 20,
            ),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              color: GeneralSettingsTokens.textMain,
              fontWeight: FontWeight.bold,
            ),
            suffixText: suffixText,
            suffixStyle: const TextStyle(
              color: GeneralSettingsTokens.textMuted,
              fontSize: 12,
            ),
            helperText: helperText,
            helperMaxLines: 2,
            helperStyle: const TextStyle(
              color: GeneralSettingsTokens.textDim,
              fontSize: 11,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: GeneralSettingsTokens.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isModified
                    ? GeneralSettingsTokens.primary.withAlpha(150)
                    : GeneralSettingsTokens.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.activeOutline,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.errorRed),
            ),
          ),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Toggle card used for boolean settings like image compression or maintenance.
class GeneralSettingsSwitchTile extends StatelessWidget {
  const GeneralSettingsSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GeneralSettingsTokens.cardInner,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? activeColor.withAlpha(120)
              : GeneralSettingsTokens.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (value ? activeColor : GeneralSettingsTokens.textDim)
                  .withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? activeColor : GeneralSettingsTokens.textMuted,
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
                    color: GeneralSettingsTokens.textMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: GeneralSettingsTokens.textMuted,
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
            inactiveThumbColor: GeneralSettingsTokens.textDim,
            inactiveTrackColor: GeneralSettingsTokens.border,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
