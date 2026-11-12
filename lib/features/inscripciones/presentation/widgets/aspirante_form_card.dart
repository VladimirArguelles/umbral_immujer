import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/inscripciones/domain/inscripcion_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Formulario validado y responsivo para registrar nuevos aspirantes en un curso.
class AspiranteFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController cedulaController;
  final TextEditingController nombresController;
  final TextEditingController apellidosController;
  final TextEditingController telefonoController;
  final TextEditingController correoController;
  final String documentType;
  final ValueChanged<String> onDocumentTypeChanged;
  final List<CursoConCupos> cursos;
  final String? selectedCursoId;
  final ValueChanged<String?> onCursoChanged;
  final bool isSubmitting;
  final bool isCheckingCedula;
  final bool canSubmit;
  final String? duplicateWarning;
  final String? existingStudentHint;
  final VoidCallback onCheckCedula;
  final VoidCallback onSubmit;

  const AspiranteFormCard({
    super.key,
    required this.formKey,
    required this.cedulaController,
    required this.nombresController,
    required this.apellidosController,
    required this.telefonoController,
    required this.correoController,
    required this.documentType,
    required this.onDocumentTypeChanged,
    required this.cursos,
    required this.selectedCursoId,
    required this.onCursoChanged,
    required this.isSubmitting,
    required this.isCheckingCedula,
    required this.canSubmit,
    this.duplicateWarning,
    this.existingStudentHint,
    required this.onCheckCedula,
    required this.onSubmit,
  });

  CursoConCupos? get _selectedCurso {
    if (selectedCursoId == null) return null;
    for (final c in cursos) {
      if (c.id == selectedCursoId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedCurso = _selectedCurso;
    final availableIds = cursos
        .where((c) => c.puedeInscribir)
        .map((c) => c.id)
        .toSet();
    final safeDropdownValue =
        (selectedCursoId != null && availableIds.contains(selectedCursoId))
            ? selectedCursoId
            : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Symbols.person_add,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registro de Aspirante',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dynamicText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'El aspirante quedará habilitado para ingresar al módulo Alumnos.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.dynamicTextMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // Selector de Curso con indicador de cupos y bloqueo automático
            Text(
              'Curso a inscribir *',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.dynamicText,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey('curso_dropdown_${safeDropdownValue ?? "none"}_${cursos.length}'),
              initialValue: safeDropdownValue,
              isExpanded: true,
              dropdownColor: AppTheme.dynamicSurfaceContainer,
              style: TextStyle(color: AppTheme.dynamicText, fontSize: 13.5),
              decoration: const InputDecoration(
                hintText: 'Selecciona un curso con cupos disponibles',
                prefixIcon: Icon(Symbols.school, size: 20),
                isDense: true,
              ),
              items: cursos.map((curso) {
                final disabled = !curso.puedeInscribir;
                return DropdownMenuItem<String>(
                  value: curso.id,
                  enabled: !disabled,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${curso.nombre} (${curso.inscritosCount}/${curso.cupoMaximo})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: disabled
                                ? AppTheme.dynamicTextMuted
                                : AppTheme.dynamicText,
                            fontWeight: disabled
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (curso.cuposAgotados) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Cupos Agotados',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.errorRed,
                            ),
                          ),
                        ),
                      ] else if (!curso.admisionAbierta) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warningOrange.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Cerrado',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.warningOrange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: isSubmitting ? null : onCursoChanged,
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Selecciona un curso disponible';
                }
                return null;
              },
            ),

            if (selectedCurso != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (selectedCurso.cuposAgotados
                          ? AppTheme.errorRed
                          : AppTheme.successGreen)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (selectedCurso.cuposAgotados
                            ? AppTheme.errorRed
                            : AppTheme.successGreen)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedCurso.cuposAgotados
                          ? Symbols.error
                          : Symbols.event_seat,
                      size: 18,
                      color: selectedCurso.cuposAgotados
                          ? AppTheme.errorRed
                          : AppTheme.successGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedCurso.resumenCupos,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selectedCurso.cuposAgotados
                              ? AppTheme.errorRed
                              : AppTheme.dynamicText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Cédula + verificación de duplicado en el curso
            Text(
              'Cédula de Identidad *',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.dynamicText,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 78,
                  child: DropdownButtonFormField<String>(
                    initialValue: documentType,
                    dropdownColor: AppTheme.dynamicSurfaceContainer,
                    style: TextStyle(
                      color: AppTheme.dynamicText,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'V', child: Text('V-')),
                      DropdownMenuItem(value: 'E', child: Text('E-')),
                    ],
                    onChanged: isSubmitting
                        ? null
                        : (v) {
                            if (v != null) onDocumentTypeChanged(v);
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: cedulaController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.dynamicText),
                    decoration: InputDecoration(
                      hintText: 'Ej. 24123456',
                      prefixIcon: const Icon(Symbols.badge, size: 20),
                      isDense: true,
                      suffixIcon: isCheckingCedula
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Verificar cédula en el curso',
                              icon: const Icon(
                                Symbols.person_search,
                                color: AppTheme.primary,
                              ),
                              onPressed: onCheckCedula,
                            ),
                    ),
                    onEditingComplete: onCheckCedula,
                    validator: (val) {
                      final digits =
                          (val ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.length < 6) {
                        return 'Ingresa una cédula válida (mín. 6 dígitos)';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            if (duplicateWarning != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Symbols.warning,
                      color: AppTheme.errorRed,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        duplicateWarning!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (existingStudentHint != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Symbols.info,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        existingStudentHint!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.dynamicText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Nombres y Apellidos responsivos
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 460;
                final nombresField = TextFormField(
                  controller: nombresController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: AppTheme.dynamicText),
                  decoration: const InputDecoration(
                    labelText: 'Nombres *',
                    hintText: 'Ej. María José',
                    prefixIcon: Icon(Symbols.person, size: 20),
                    isDense: true,
                  ),
                  validator: (val) => (val == null || val.trim().length < 2)
                      ? 'Ingresa los nombres'
                      : null,
                );
                final apellidosField = TextFormField(
                  controller: apellidosController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: AppTheme.dynamicText),
                  decoration: const InputDecoration(
                    labelText: 'Apellidos *',
                    hintText: 'Ej. Pérez Rodríguez',
                    prefixIcon: Icon(Symbols.person_outline, size: 20),
                    isDense: true,
                  ),
                  validator: (val) => (val == null || val.trim().length < 2)
                      ? 'Ingresa los apellidos'
                      : null,
                );

                if (isCompact) {
                  return Column(
                    children: [
                      nombresField,
                      const SizedBox(height: 12),
                      apellidosField,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: nombresField),
                    const SizedBox(width: 12),
                    Expanded(child: apellidosField),
                  ],
                );
              },
            ),

            const SizedBox(height: 14),

            // Teléfono y Correo responsivos
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 460;
                final telefonoField = TextFormField(
                  controller: telefonoController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: AppTheme.dynamicText),
                  decoration: const InputDecoration(
                    labelText: 'Teléfono *',
                    hintText: '04141234567',
                    prefixIcon: Icon(Symbols.call, size: 20),
                    isDense: true,
                  ),
                  validator: (val) {
                    final digits =
                        (val ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 10) {
                      return 'Teléfono inválido (mín. 10 dígitos)';
                    }
                    return null;
                  },
                );
                final correoField = TextFormField(
                  controller: correoController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: AppTheme.dynamicText),
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico *',
                    hintText: 'aspirante@correo.com',
                    prefixIcon: Icon(Symbols.mail, size: 20),
                    isDense: true,
                  ),
                  validator: (val) {
                    final text = (val ?? '').trim();
                    if (text.isEmpty ||
                        !text.contains('@') ||
                        !text.contains('.')) {
                      return 'Ingresa un correo electrónico válido';
                    }
                    return null;
                  },
                );

                if (isCompact) {
                  return Column(
                    children: [
                      telefonoField,
                      const SizedBox(height: 12),
                      correoField,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: telefonoField),
                    const SizedBox(width: 12),
                    Expanded(child: correoField),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (!canSubmit || isSubmitting || duplicateWarning != null)
                  ? null
                  : onSubmit,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppTheme.onPrimary,
                      ),
                    )
                  : const Icon(Symbols.how_to_reg),
              label: Text(
                isSubmitting
                    ? 'Registrando aspirante...'
                    : 'Registrar e Inscribir Aspirante',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
