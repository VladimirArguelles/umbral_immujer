import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/widgets/formation_image_carousel.dart';

/// Home summary tab for the Teacher module with carousel and module shortcuts.
class TeacherSummaryTab extends StatelessWidget {
  const TeacherSummaryTab({
    super.key,
    required this.teacherName,
    required this.isSuperAdmin,
    required this.onNavigate,
  });

  final String teacherName;
  final bool isSuperAdmin;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.dynamicBackground,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.school,
                  color: AppTheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, $teacherName',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSuperAdmin
                          ? 'Supervisión de docencia, asistencias y planeación'
                          : 'Panel de gestión académica y control de clases',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FormationImageCarousel(),
          const SizedBox(height: 16),
          Text(
            'HERRAMIENTAS DEL MÓDULO',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.outline,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _TeacherActionCard(
            title: 'PASE DE ASISTENCIA',
            description:
                'Toma asistencia diaria de alumnos, visualiza asistencias y confirmaciones.',
            icon: Icons.playlist_add_check_circle_rounded,
            accent: AppTheme.primary,
            actionLabel: 'IR A ASISTENCIA',
            onTap: () => onNavigate(1),
          ),
          const SizedBox(height: 12),
          _TeacherActionCard(
            title: 'CREAR ENCUESTA',
            description:
                'Configura encuestas previas para estimar insumos y confirmar participación.',
            icon: Icons.add_chart_rounded,
            accent: AppTheme.secondary,
            actionLabel: 'IR A ENCUESTAS',
            onTap: () => onNavigate(2),
          ),
          const SizedBox(height: 12),
          _TeacherActionCard(
            title: 'AUDITORÍA DE RECAUDACIÓN',
            description:
                'Monitorea comprobantes de aportes y saldo de insumos por clase.',
            icon: Icons.payments_rounded,
            accent: AppTheme.tertiary,
            actionLabel: 'IR A RECAUDACIÓN',
            onTap: () => onNavigate(3),
          ),
          const SizedBox(height: 12),
          _TeacherActionCard(
            title: 'GESTIÓN DE ALUMNOS',
            description:
                'Listado de alumnos matriculados, temas de clase y solicitudes.',
            icon: Icons.people_alt_rounded,
            accent: AppTheme.successGreen,
            actionLabel: 'IR A GESTIÓN DE ALUMNOS',
            onTap: () => onNavigate(4),
          ),
          const SizedBox(height: 12),
          _TeacherActionCard(
            title: 'MÓDULO INSCRIPCIONES',
            description:
                'Registrar aspirantes y consultar cupos disponibles en tiempo real.',
            icon: Icons.how_to_reg_rounded,
            accent: AppTheme.primary,
            actionLabel: 'ABRIR INSCRIPCIONES',
            onTap: () => context.go('/inscripciones'),
          ),
        ],
      ),
    );
  }
}

class _TeacherActionCard extends StatelessWidget {
  const _TeacherActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dynamicBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark ? 0.06 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.dynamicTextMuted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppTheme.pureWhite,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
