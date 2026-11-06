import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/assistant/data/assistant_repository.dart';
import 'package:umbral_immujer/features/assistant/domain/assistant_models.dart';
import 'package:umbral_immujer/features/assistant/presentation/screens/mia_chat_screen.dart';
import 'package:umbral_immujer/src/core/theme/app_colors.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

/// Modal interactivo del Asistente Virtual Mía para despliegue emergente.
class MiaAssistantModal extends StatefulWidget {
  final UserProfile? profile;
  final String? currentModule;

  const MiaAssistantModal({
    super.key,
    this.profile,
    this.currentModule,
  });

  static Future<void> show(
    BuildContext context, {
    UserProfile? profile,
    String? currentModule,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => MiaAssistantModal(
        profile: profile,
        currentModule: currentModule,
      ),
    );
  }

  @override
  State<MiaAssistantModal> createState() => _MiaAssistantModalState();
}

class _MiaAssistantModalState extends State<MiaAssistantModal> {
  late final AssistantRepository _repository;
  late final AssistantModuleContext _moduleContext;
  String _greeting = '¡Hola!';
  bool _isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _repository = AssistantRepository();
    _moduleContext = AssistantModuleContext.fromKey(
      widget.currentModule,
      widget.profile?.rol,
    );
    _loadGreeting();
  }

  Future<void> _loadGreeting() async {
    final greeting = await _repository.getPersonalizedGreeting(
      currentProfile: widget.profile,
    );
    if (!mounted) return;
    setState(() {
      _greeting = greeting;
      _isLoadingName = false;
    });
  }

  void _startChat([String? initialPrompt]) {
    Navigator.of(context).pop();
    MiaChatScreen.open(
      context,
      profile: widget.profile,
      currentModule: widget.currentModule,
      initialMessage: initialPrompt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    final cardBg = AppColors.dynamicCard;
    final border = AppColors.dynamicBorder;
    final textMain = AppColors.dynamicText;
    final textMuted = AppColors.dynamicTextMuted;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGlow.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera institucional de Mía
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.22),
                          cardBg,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border(bottom: BorderSide(color: border, width: 0.8)),
                    ),
                    child: Row(
                      children: [
                        // Avatar flotante de Mía
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: AppColors.mintNeon,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGlow,
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Symbols.smart_toy,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Umbral AI Assistant',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: textMain,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.mintNeon.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.mintNeon.withValues(alpha: 0.6),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: AppColors.mintNeon,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'EN LÍNEA',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.mintNeon,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Asistente Virtual • UMBRAL IMMUJER',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textMuted),
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Cuerpo del diálogo
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Saludo personalizado dinámico
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _isLoadingName
                              ? Text(
                                  '¡Hola! 👋',
                                  key: const ValueKey('loading-greeting'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: textMain,
                                  ),
                                )
                              : Text(
                                  '$_greeting 👋',
                                  key: const ValueKey('loaded-greeting'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: textMain,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),

                        // Chip indicador del módulo activo
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _moduleContext.icon,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Contexto: ${_moduleContext.title}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Descripción breve de ayuda
                        Text(
                          _moduleContext.description,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            height: 1.45,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Preguntas frecuentes rápidas del módulo
                        Text(
                          'TEMAS FRECUENTES EN ESTE MÓDULO',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _moduleContext.quickPrompts.take(3).map((prompt) {
                            return InkWell(
                              onTap: () => _startChat(prompt),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkCardInner
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Symbols.auto_awesome,
                                      size: 13,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        prompt,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: textMain,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),

                        // Botón de acción principal: "Iniciar conversación"
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _startChat(),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8B5CF6),
                                    Color(0xFF6D28D9),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryGlow,
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Symbols.chat,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Iniciar conversación',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// Botón de cabecera compacto para integrar en `AppBar.actions` o cabeceras de módulos.
class MiaAssistantHeaderButton extends StatelessWidget {
  final UserProfile? profile;
  final String? moduleContext;
  final bool showBadge;

  const MiaAssistantHeaderButton({
    super.key,
    this.profile,
    this.moduleContext,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: 'Umbral AI Assistant',
        child: InkWell(
          onTap: () => MiaAssistantModal.show(
            context,
            profile: profile,
            currentModule: moduleContext,
          ),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Symbols.smart_toy,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    if (showBadge)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.mintNeon,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 6),
                Text(
                  'Umbral AI',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget flotante (FAB o Botón Asistente) para pantallas principales.
class MiaAssistantWidget extends StatelessWidget {
  final UserProfile? profile;
  final String? currentModule;
  final bool isFloating;

  const MiaAssistantWidget({
    super.key,
    this.profile,
    this.currentModule,
    this.isFloating = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isFloating) {
      return MiaAssistantHeaderButton(
        profile: profile,
        moduleContext: currentModule,
      );
    }

    return FloatingActionButton.extended(
      onPressed: () => MiaAssistantModal.show(
        context,
        profile: profile,
        currentModule: currentModule,
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(Symbols.smart_toy, size: 20),
      label: Text(
        'Preguntar a Umbral AI',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
