import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/inscripciones/domain/inscripcion_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Tarjeta visual responsiva que muestra el estado de cupos en tiempo real de un curso.
class CursoCupoCard extends StatelessWidget {
  final CursoConCupos curso;
  final bool isSelected;
  final VoidCallback? onTap;

  const CursoCupoCard({
    super.key,
    required this.curso,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = curso.cuposAgotados;
    final isClosed = !curso.admisionAbierta;
    final isDisabled = !curso.puedeInscribir;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (isFull) {
      statusColor = AppTheme.errorRed;
      statusLabel = 'Cupos Agotados';
      statusIcon = Symbols.block;
    } else if (isClosed) {
      statusColor = AppTheme.warningOrange;
      statusLabel = 'Admisión Cerrada';
      statusIcon = Symbols.lock_clock;
    } else if (curso.cuposDisponibles <= 5) {
      statusColor = AppTheme.warningOrange;
      statusLabel = 'Últimos cupos';
      statusIcon = Symbols.hourglass_bottom;
    } else {
      statusColor = AppTheme.successGreen;
      statusLabel = 'Disponible';
      statusIcon = Symbols.check_circle;
    }

    final borderColor = isSelected && !isDisabled
        ? AppTheme.primary
        : isDisabled
            ? statusColor.withValues(alpha: 0.4)
            : AppTheme.dynamicBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected && !isDisabled
            ? AppTheme.primary.withValues(alpha: 0.1)
            : AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: isSelected && !isDisabled ? 1.8 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isDisabled ? null : onTap,
          child: Opacity(
            opacity: isDisabled ? 0.78 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isDisabled ? statusColor : AppTheme.primary)
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Symbols.menu_book,
                          size: 18,
                          color: isDisabled ? statusColor : AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              curso.nombre,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.dynamicText,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (curso.horario != null &&
                                curso.horario!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                curso.horario!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: AppTheme.dynamicTextMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: curso.porcentajeOcupacion,
                      minHeight: 7,
                      backgroundColor: AppTheme.dynamicSurfaceHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          curso.resumenCupos,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isFull
                                ? AppTheme.errorRed
                                : AppTheme.dynamicTextMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected && !isDisabled) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
