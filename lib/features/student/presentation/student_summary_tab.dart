import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

class StudentSummaryTab extends StatelessWidget {
  const StudentSummaryTab({
    super.key,
    required this.studentName,
    required this.onNavigate,
  });

  final String studentName;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > 720 ? 28.0 : 16.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              28,
            ),
            children: [
              Text(
                'Hola, $studentName',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Este es el resumen de tu experiencia formativa.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              const _FormationCarousel(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Módulos de alumna',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'Tu espacio',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ModuleCard(
                title: 'MIS CURSOS',
                description: 'Consulta tus cursos registrados, clases y material didáctico.',
                icon: Icons.menu_book_rounded,
                accent: AppTheme.primary,
                action: 'IR A MIS CURSOS',
                onTap: () => onNavigate(1),
              ),
              const SizedBox(height: 12),
              _ModuleCard(
                title: 'MI ASISTENCIA',
                description:
                    'Revisa tu participación y el historial de tus clases.',
                icon: Icons.event_available_rounded,
                accent: AppTheme.tertiary,
                action: 'IR A MI ASISTENCIA',
                onTap: () => onNavigate(2),
              ),
              const SizedBox(height: 12),
              _ModuleCard(
                title: 'ENCUESTAS Y APORTES',
                description: 'Responde las evaluaciones de tus talleres y consulta tus aportes.',
                icon: Icons.rate_review_rounded,
                accent: AppTheme.secondary,
                action: 'IR A ENCUESTAS',
                onTap: () => onNavigate(3),
              ),
              const SizedBox(height: 18),
              _OpportunityBanner(onTap: () => onNavigate(1)),
            ],
          );
        },
      ),
    );
  }
}

class _FormationCarousel extends StatefulWidget {
  const _FormationCarousel();

  @override
  State<_FormationCarousel> createState() => _FormationCarouselState();
}

class _FormationCarouselState extends State<_FormationCarousel> {
  static const _formations = [
    _Formation(
      area: 'Área 1 · Estética y Belleza',
      title: 'Diseño y Estética de Cejas',
      description: 'Visagismo, micropigmentación y técnicas de cuidado facial.',
      tag: 'CEJAS',
      icon: Icons.face_retouching_natural_rounded,
      color: AppTheme.primary,
      imagePath: 'assets/images/cejas.png',
    ),
    _Formation(
      area: 'Área 2 · Gastronomía Tradicional',
      title: 'Panadería y Masas Artesanales',
      description: 'Panificación tradicional, fermentación, amasado y horneado.',
      tag: 'PANADERÍA',
      icon: Icons.bakery_dining_rounded,
      color: AppTheme.warningOrange,
      imagePath: 'assets/images/panaderia.png',
    ),
    _Formation(
      area: 'Área 3 · Pastelería y Dulces',
      title: 'Repostería y Decoración Artística',
      description: 'Técnicas de pastelería comercial, masas dulces y decoración.',
      tag: 'REPOSTERÍA',
      icon: Icons.cake_rounded,
      color: AppTheme.secondary,
      imagePath: 'assets/images/reposteria.png',
    ),
  ];

  late final PageController _pageController;
  Timer? _autoplay;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoplay();
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoplay() {
    _autoplay?.cancel();
    _autoplay = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
    _startAutoplay();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.surfaceContainer, AppTheme.surfaceContainerLow],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'FORMACIONES IMMUJER',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const Icon(Icons.circle, color: AppTheme.tertiary, size: 8),
              const SizedBox(width: 5),
              Text(
                'ACTIVO',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.tertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Explora las áreas formativas para impulsar tu autonomía profesional.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: Listener(
              onPointerDown: (_) => _autoplay?.cancel(),
              onPointerUp: (_) => _startAutoplay(),
              child: PageView.builder(
                controller: _pageController,
                itemCount: _formations.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) =>
                    _FormationCard(formation: _formations[index]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Row(
                children: List.generate(_formations.length, (index) {
                  final selected = index == _currentPage;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Semantics(
                      button: true,
                      label: 'Mostrar formación ${index + 1}',
                      child: GestureDetector(
                        onTap: () => _goToPage(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: selected ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.outlineVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(),
              _CarouselArrow(
                icon: Icons.chevron_left_rounded,
                label: 'Formación anterior',
                onTap: () => _goToPage(
                  (_currentPage - 1 + _formations.length) % _formations.length,
                ),
              ),
              const SizedBox(width: 7),
              _CarouselArrow(
                icon: Icons.chevron_right_rounded,
                label: 'Siguiente formación',
                onTap: () => _goToPage((_currentPage + 1) % _formations.length),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormationCard extends StatelessWidget {
  const _FormationCard({required this.formation});

  final _Formation formation;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: AssetImage(formation.imagePath),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.surfaceContainer.withValues(alpha: 0.55),
              AppTheme.surfaceContainer.withValues(alpha: 0.94),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formation.area.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.onSurface,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formation.tag,
                    style: GoogleFonts.plusJakartaSans(
                      color: formation.color,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(formation.icon, color: formation.color, size: 25),
            const SizedBox(height: 5),
            Text(
              formation.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              formation.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: label,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.surfaceBright,
        foregroundColor: AppTheme.onSurface,
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 5),
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
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.4,
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
                foregroundColor: AppTheme.onPrimary,
                minimumSize: const Size.fromHeight(42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    action,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunityBanner extends StatelessWidget {
  const _OpportunityBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBright,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OPORTUNIDADES DE FORMACIÓN',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Conoce las novedades de tus cursos',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Formation {
  const _Formation({
    required this.area,
    required this.title,
    required this.description,
    required this.tag,
    required this.icon,
    required this.color,
    required this.imagePath,
  });

  final String area;
  final String title;
  final String description;
  final String tag;
  final IconData icon;
  final Color color;
  final String imagePath;
}
