import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/superadmin/presentation/gestion_alumnos_page.dart';
import 'package:umbral_immujer/features/superadmin/presentation/gestion_cursos_page.dart';
import 'package:umbral_immujer/features/superadmin/presentation/gestion_profesores_page.dart';
import 'package:umbral_immujer/features/superadmin/presentation/gestion_usuarios_page.dart';
import 'package:umbral_immujer/features/superadmin/presentation/widgets/super_admin_theme_tokens.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

class _QuickAddEntry {
  const _QuickAddEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// Shows the Super Admin quick-actions modal dialog.
Future<void> showSuperAdminQuickAddDialog(
  BuildContext context, {
  required VoidCallback onRefreshMetrics,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      void openPage(Widget page) {
        Navigator.pop(dialogContext);
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page))
            .then((_) => onRefreshMetrics());
      }

      void goRoute(String route) {
        Navigator.pop(dialogContext);
        context.go(route);
      }

      final entries = [
        _QuickAddEntry(
          icon: Symbols.manage_accounts,
          color: AppTheme.primary,
          title: 'Gestión de Usuarios',
          subtitle:
              'Consultar, asignar roles y administrar usuarios registrados',
          onTap: () => openPage(const GestionUsuariosPage()),
        ),
        _QuickAddEntry(
          icon: Symbols.school,
          color: SuperAdminTokens.accent,
          title: 'Gestión de Alumnos',
          subtitle: 'Filtrar por curso, editar, añadir y eliminar alumnos',
          onTap: () => openPage(const GestionAlumnosPage()),
        ),
        _QuickAddEntry(
          icon: Symbols.badge,
          color: SuperAdminTokens.mintBright,
          title: 'Gestión Profesores',
          subtitle: 'Filtrar por curso, asignar, editar y registrar docentes',
          onTap: () => openPage(const GestionProfesoresPage()),
        ),
        _QuickAddEntry(
          icon: Symbols.picture_as_pdf,
          color: AppTheme.primary,
          title: 'Centro de Reportes y PDF',
          subtitle:
              'Generación, impresión y descarga de matrículas, asistencias y planes',
          onTap: () => goRoute('/reports'),
        ),
        _QuickAddEntry(
          icon: Symbols.menu_book,
          color: AppTheme.primary,
          title: 'Gestión Curso',
          subtitle: 'Seleccionar curso, editar, añadir, eliminar y ver temas',
          onTap: () => openPage(const GestionCursosPage()),
        ),
        _QuickAddEntry(
          icon: Symbols.how_to_reg,
          color: AppTheme.successGreen,
          title: 'Módulo Inscripciones',
          subtitle: 'Registrar aspirantes, cupos en vivo y accesos temporales',
          onTap: () => goRoute('/inscripciones'),
        ),
        _QuickAddEntry(
          icon: Symbols.terminal,
          color: const Color(0xFF38BDF8),
          title: 'Consola de Diagnóstico',
          subtitle: 'Monitoreo y depuración en vivo de excepciones y errores',
          onTap: () => goRoute('/admin/error-console'),
        ),
      ];

      return AlertDialog(
        backgroundColor: SuperAdminTokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Symbols.bolt, color: SuperAdminTokens.accent, size: 24),
            const SizedBox(width: 8),
            Text(
              'Acciones Rápidas',
              style: GoogleFonts.plusJakartaSans(
                color: SuperAdminTokens.textMain,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _QuickAddTile(entry: entries[i]),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: SuperAdminTokens.textMuted),
            ),
          ),
        ],
      );
    },
  );
}

class _QuickAddTile extends StatelessWidget {
  const _QuickAddTile({required this.entry});

  final _QuickAddEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: entry.color.withAlpha(40),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(entry.icon, color: entry.color, size: 22),
      ),
      title: Text(
        entry.title,
        style: GoogleFonts.plusJakartaSans(
          color: SuperAdminTokens.textMain,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        entry.subtitle,
        style: const TextStyle(color: SuperAdminTokens.textMuted, fontSize: 12),
      ),
      trailing: const Icon(
        Symbols.chevron_right,
        color: SuperAdminTokens.textDim,
        size: 20,
      ),
      onTap: entry.onTap,
    );
  }
}
