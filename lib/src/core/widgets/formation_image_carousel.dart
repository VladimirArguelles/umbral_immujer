import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

class FormationItem {
  final String area;
  final String title;
  final String description;
  final String tag;
  final IconData icon;
  final Color color;
  final String imagePath;

  const FormationItem({
    required this.area,
    required this.title,
    required this.description,
    required this.tag,
    required this.icon,
    required this.color,
    required this.imagePath,
  });
}

class FormationImageCarousel extends StatefulWidget {
  const FormationImageCarousel({super.key});

  @override
  State<FormationImageCarousel> createState() => _FormationImageCarouselState();
}

class _FormationImageCarouselState extends State<FormationImageCarousel> {
  static const _formations = [
    FormationItem(
      area: 'Área 1 · Estética y Belleza',
      title: 'Diseño y Estética de Cejas',
      description: 'Visagismo, micropigmentación y técnicas de cuidado facial.',
      tag: 'CEJAS',
      icon: Icons.face_retouching_natural_rounded,
      color: AppTheme.primary,
      imagePath: 'assets/images/cejas.png',
    ),
    FormationItem(
      area: 'Área 2 · Gastronomía Tradicional',
      title: 'Panadería y Masas Artesanales',
      description: 'Panificación tradicional, fermentación, amasado y horneado.',
      tag: 'PANADERÍA',
      icon: Icons.bakery_dining_rounded,
      color: AppTheme.warningOrange,
      imagePath: 'assets/images/panaderia.png',
    ),
    FormationItem(
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
            offset: const Offset(0, 8),
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
            'Explora las áreas formativas para impulsar la autonomía profesional.',
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
                onPageChanged: (index) => setState(() => _currentPage = index % _formations.length),
                itemBuilder: (context, index) =>
                    _FormationImageCard(formation: _formations[index % _formations.length]),
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
              _CarouselArrowBtn(
                icon: Icons.chevron_left_rounded,
                label: 'Formación anterior',
                onTap: () => _goToPage(
                  (_currentPage - 1 + _formations.length) % _formations.length,
                ),
              ),
              const SizedBox(width: 7),
              _CarouselArrowBtn(
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

class _FormationImageCard extends StatelessWidget {
  const _FormationImageCard({required this.formation});

  final FormationItem formation;

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

class _CarouselArrowBtn extends StatelessWidget {
  const _CarouselArrowBtn({
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
