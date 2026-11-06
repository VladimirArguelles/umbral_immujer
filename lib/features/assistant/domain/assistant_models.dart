import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

/// Modelo de mensaje dentro de la sesión de chat con Mía.
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestions;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestions = const [],
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<String>? suggestions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}

/// Contexto operativo del módulo desde el cual se invoca al Asistente Mía.
class AssistantModuleContext {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String description;
  final List<String> quickPrompts;

  const AssistantModuleContext({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.description,
    required this.quickPrompts,
  });

  /// Resuelve el contexto del asistente basado en una clave o ruta de módulo.
  static AssistantModuleContext fromKey(String? key, [UserRole? role]) {
    final normalized = (key ?? '').toLowerCase().trim();

    if (normalized.contains('alumno') || normalized.contains('student')) {
      return const AssistantModuleContext(
        id: 'alumnos',
        title: 'Módulo de Alumnos',
        subtitle: 'Cursos, asistencias, encuestas y aportes prácticos',
        icon: Symbols.school,
        description:
            'Te ayudo a revisar el estado de tus cursos, consultar tus registros de asistencia, responder encuestas de satisfacción y gestionar comprobantes de aportes para clases prácticas.',
        quickPrompts: [
          '¿Cómo confirmo mi asistencia a una clase práctica?',
          '¿Dónde veo el historial de mis asistencias?',
          '¿Cómo responder una encuesta de satisfacción?',
          '¿Cómo actualizar mis datos y foto en Mi Perfil?',
        ],
      );
    }

    if (normalized.contains('profesor') || normalized.contains('teacher')) {
      return const AssistantModuleContext(
        id: 'profesores',
        title: 'Módulo de Profesores',
        subtitle: 'Asistencias, encuestas, insumos y propuestas de temas',
        icon: Symbols.badge,
        description:
            'Te oriento en la toma de asistencias por fecha, el cálculo de aportes por clase práctica, la activación de encuestas y el envío de solicitudes de temarios a coordinación.',
        quickPrompts: [
          '¿Cómo registrar la asistencia de una clase?',
          '¿Cómo crear una encuesta para mis alumnos?',
          '¿Cómo solicitar la aprobación de un nuevo tema?',
          '¿Dónde gestiono Mi Perfil y mis datos docentes?',
        ],
      );
    }

    if (normalized.contains('coord') ||
        normalized.contains('coordinacion') ||
        normalized.contains('coordinator')) {
      return const AssistantModuleContext(
        id: 'coordinacion',
        title: 'Módulo de Coordinación',
        subtitle: 'Navegación de interfaz, aprobaciones y supervisión',
        icon: Symbols.military_tech,
        description:
            'Te oriento en la navegación entre las secciones de tu panel (Cursos, En Vivo, Profesores, Insumos), la revisión y aprobación de solicitudes docentes y la emisión de reportes.',
        quickPrompts: [
          '¿Cómo navegar entre Cursos, En Vivo, Profesores e Insumos?',
          '¿Dónde reviso y apruebo las solicitudes de temarios?',
          '¿Cómo consultar reportes consolidados y registros?',
          '¿Dónde encuentro y edito Mi Perfil?',
        ],
      );
    }

    if (normalized.contains('superadmin') || normalized.contains('admin')) {
      return const AssistantModuleContext(
        id: 'superadmin',
        title: 'Panel Super Admin',
        subtitle: 'Telemetría global, sincronización BCV y configuración',
        icon: Symbols.admin_panel_settings,
        description:
            'Asistencia técnica para telemetría en vivo, gestión global de usuarios y roles, tasa cambiaria oficial BCV, auditoría y parámetros de la plataforma UMBRAL.',
        quickPrompts: [
          '¿Cómo funciona la sincronización automática de la tasa BCV?',
          '¿Cómo modificar los roles de un usuario registrado?',
          '¿Dónde verifico el estado de las políticas RLS?',
          '¿Cómo acceder a los ajustes de impresión y tickets?',
        ],
      );
    }

    if (normalized.contains('report')) {
      return const AssistantModuleContext(
        id: 'reportes',
        title: 'Módulo de Reportes',
        subtitle: 'Métricas analíticas y exportaciones oficiales',
        icon: Symbols.analytics,
        description:
            'Te ayudo a interpretar los filtros de cursos, tasas de retención y opciones de exportación para la dirección institucional de IMMUJER.',
        quickPrompts: [
          '¿Cómo filtrar reportes por cohorte y curso?',
          '¿Cómo exportar el listado completo a PDF?',
        ],
      );
    }

    // Contexto predeterminado según el rol del usuario si no se indicó módulo
    if (role != null) {
      switch (role) {
        case UserRole.alumno:
          return fromKey('alumnos');
        case UserRole.profesor:
          return fromKey('profesores');
        case UserRole.coordinador:
          return fromKey('coordinacion');
        case UserRole.superAdmin:
          return fromKey('superadmin');
      }
    }

    return const AssistantModuleContext(
      id: 'general',
      title: 'Asistencia UMBRAL',
      subtitle: 'Soporte inteligente institucional IMMUJER',
      icon: Symbols.support_agent,
      description:
          'Soy UMLY, tu asistente virtual en la plataforma UMBRAL del Instituto Municipal de la Mujer (IMMUJER). Estoy aquí para responder dudas, guiarte paso a paso en tu perfil y orientarte en cualquier sección del sistema.',
      quickPrompts: [
        '¿Qué puedo hacer en Mi Perfil y dónde está?',
        '¿Cómo cambiar mi foto de perfil y teléfono?',
        '¿Cómo navegar entre las distintas secciones?',
      ],
    );
  }
}
