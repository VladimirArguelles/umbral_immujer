import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

/// Modelo de mensaje dentro de la sesión de chat con Umby.
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestions;
  final String? ticketId;
  final bool isDiagnostic;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestions = const [],
    this.ticketId,
    this.isDiagnostic = false,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<String>? suggestions,
    String? ticketId,
    bool? isDiagnostic,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      suggestions: suggestions ?? this.suggestions,
      ticketId: ticketId ?? this.ticketId,
      isDiagnostic: isDiagnostic ?? this.isDiagnostic,
    );
  }
}

/// Telemetría y contexto dinámico del dispositivo y la aplicación para soporte técnico inteligente.
class AppTelemetryContext {
  final String currentModule;
  final String networkStatus;
  final String bluetoothStatus;
  final String? lastError;
  final String platform;
  final String? userRole;
  final String? userId;
  final String? userName;

  const AppTelemetryContext({
    required this.currentModule,
    required this.networkStatus,
    required this.bluetoothStatus,
    this.lastError,
    required this.platform,
    this.userRole,
    this.userId,
    this.userName,
  });

  Map<String, dynamic> toJson() {
    return {
      'currentModule': currentModule,
      'networkStatus': networkStatus,
      'bluetoothStatus': bluetoothStatus,
      'lastError': lastError,
      'platform': platform,
      'userRole': userRole,
      'userId': userId,
      'userName': userName,
    };
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
          '¿Cómo consultar mi historial de asistencias y cursos?',
          '¿Cómo consultar y registrar comprobantes de aporte práctico?',
          '¿Cómo completar encuestas de satisfacción institucional?',
          '¿Cómo actualizar fotografía y número telefónico en Mi Perfil?',
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
        subtitle: 'Aprobaciones, reportes y supervisión operativa',
        icon: Symbols.military_tech,
        description:
            'Te oriento en la programación de cursos formativos, la revisión y aprobación de solicitudes docentes, la calibración de la impresora térmica y la emisión de reportes.',
        quickPrompts: [
          '¿Cómo registrar y programar un nuevo curso?',
          '¿Cómo revisar y aprobar solicitudes de temarios docentes?',
          '¿Cómo filtrar y exportar reportes consolidados en PDF?',
          '¿Cómo configurar y calibrar la impresora térmica Bluetooth ESC/POS?',
        ],
      );
    }

    if (normalized.contains('superadmin') || normalized.contains('admin')) {
      return const AssistantModuleContext(
        id: 'superadmin',
        title: 'Panel Super Admin',
        subtitle: 'Telemetría global, sincronización BCV y auditoría RLS',
        icon: Symbols.admin_panel_settings,
        description:
            'Asistencia técnica para telemetría en vivo, gestión global de usuarios y roles, tasa cambiaria oficial BCV, auditoría de políticas RLS y parámetros de la plataforma UMBRAL.',
        quickPrompts: [
          '¿Cómo modificar roles de usuarios y auditar permisos?',
          '¿Cómo verificar y forzar la sincronización de la tasa oficial BCV?',
          '¿Cómo auditar y verificar el estado de las políticas RLS?',
          '¿Cómo configurar y calibrar la impresora térmica Bluetooth ESC/POS?',
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
          '¿Cómo filtrar y exportar reportes consolidados en PDF?',
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
      title: 'Umby (Soporte Técnico)',
      subtitle: 'Soporte inteligente y diagnóstico UMBRAL IMMUJER',
      icon: Symbols.support_agent,
      description:
          'Soy Umby, tu asistente de soporte técnico y guía inteligente en la plataforma UMBRAL del Instituto Municipal de la Mujer (IMMUJER). Puedo diagnosticar fallos, orientarte paso a paso y resolver dudas.',
      quickPrompts: [
        '¿Cómo actualizar fotografía y número telefónico en Mi Perfil?',
        '¿Cómo configurar y calibrar la impresora térmica Bluetooth ESC/POS?',
      ],
    );
  }
}
