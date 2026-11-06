import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/features/assistant/domain/assistant_models.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/utils/app_logger.dart';
import 'package:umbral_immujer/src/features/auth/data/auth_repository.dart';
import 'package:umbral_immujer/src/features/auth/domain/user_profile.dart';

class AssistantRepository {
  final SupabaseClient _supabase;
  late final AuthRepository _authRepository;

  AssistantRepository([SupabaseClient? client])
      : _supabase = client ?? SupabaseConfig.client {
    _authRepository = AuthRepository(_supabase);
  }

  /// Extrae el primer nombre de forma segura y amigable sin solicitar cédula
  static String extractFirstName(String fullName) {
    final clean = fullName.trim();
    if (clean.isEmpty) return 'Usuario';
    final parts = clean.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'Usuario';
    return parts.first;
  }

  /// Obtiene o resuelve el saludo dinámico personalizado en tiempo real
  Future<String> getPersonalizedGreeting({UserProfile? currentProfile}) async {
    UserProfile? profile = currentProfile;
    if (profile == null) {
      try {
        profile = await _authRepository.getCurrentProfile();
      } catch (_) {}
    }

    final name = profile != null ? extractFirstName(profile.fullName) : 'Usuario';
    return '¡Hola, $name!';
  }

  /// Construye el mensaje inicial contextual de bienvenida de Umby
  ChatMessage buildWelcomeMessage({
    required AssistantModuleContext moduleContext,
    UserProfile? profile,
  }) {
    final name = profile != null ? extractFirstName(profile.fullName) : 'Usuario';
    final greeting = '¡Hola, $name! 👋';

    final text = '$greeting Soy Umby, tu asistente de soporte técnico y navegación en UMBRAL IMMUJER.\n\n'
        'Actualmente te encuentras en el **${moduleContext.title}**.\n'
        '${moduleContext.description}\n\n'
        'Cuento con diagnóstico inteligente, base de conocimiento y telemetría en tiempo real. Puedes preguntarme cualquier duda o seleccionar un tema rápido a continuación:';

    return ChatMessage(
      id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      suggestions: moduleContext.quickPrompts,
    );
  }

  /// Recopila telemetría y metadatos ocultos en tiempo real
  Future<AppTelemetryContext> collectTelemetry({
    required AssistantModuleContext moduleContext,
    UserProfile? profile,
  }) async {
    UserProfile? activeProfile = profile;
    if (activeProfile == null) {
      try {
        activeProfile = await _authRepository.getCurrentProfile();
      } catch (_) {}
    }

    String bluetoothStatus = 'Desconocido';
    if (kIsWeb) {
      bluetoothStatus = 'Web (Bluetooth Classic no disponible en navegador)';
    } else {
      try {
        final state = await FlutterBluePlus.adapterState
            .first
            .timeout(const Duration(milliseconds: 300));
        bluetoothStatus = state.toString().split('.').last;
      } catch (_) {
        bluetoothStatus = 'No disponible';
      }
    }

    String networkStatus = 'Conectado';
    try {
      final session = _supabase.auth.currentSession;
      networkStatus = session != null ? 'Online (Sesión activa)' : 'Online (Sin sesión)';
    } catch (_) {
      networkStatus = 'Intermitente';
    }

    final normalizedRole = (activeProfile?.rol == UserRole.superAdmin)
        ? 'super_admin'
        : (activeProfile?.rol.toDbString() ?? 'alumno');

    return AppTelemetryContext(
      currentModule: moduleContext.id,
      networkStatus: networkStatus,
      bluetoothStatus: bluetoothStatus,
      lastError: AppLogger.lastError,
      platform: kIsWeb ? 'Web' : defaultTargetPlatform.name,
      userRole: normalizedRole,
      userId: activeProfile?.id,
      userName: activeProfile != null ? extractFirstName(activeProfile.fullName) : null,
    );
  }

  /// Genera una respuesta precisa y contextualizada al módulo actual
  Future<ChatMessage> answerQuery({
    required String query,
    required AssistantModuleContext moduleContext,
    UserProfile? profile,
  }) async {
    final telemetry = await collectTelemetry(
      moduleContext: moduleContext,
      profile: profile,
    );

    // 1. Invocar la Edge Function remota de soporte inteligente Umby
    try {
      final response = await _supabase.functions.invoke(
        'umby-assistant',
        body: {
          'query': query,
          'telemetry': telemetry.toJson(),
          'autoTicketOnCritical': true,
        },
      ).timeout(const Duration(seconds: 8));

      final data = response.data;
      if (response.status == 200 && data is Map && data['success'] == true) {
        final replyText = data['response'] as String?;
        if (replyText != null && replyText.trim().isNotEmpty) {
          final ticketId = (data['diagnostics'] is Map)
              ? data['diagnostics']['ticketGenerado'] as String?
              : null;

          return ChatMessage(
            id: 'res-${DateTime.now().millisecondsSinceEpoch}',
            text: replyText,
            isUser: false,
            timestamp: DateTime.now(),
            suggestions: moduleContext.quickPrompts,
            ticketId: ticketId,
            isDiagnostic: ticketId != null ||
                (data['diagnostics'] is Map && data['diagnostics']['systemAudit'] != null),
          );
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Invocación de umby-assistant no disponible, activando motor de diagnóstico local',
        error: e,
        tag: 'UMBY',
      );
    }

    // 2. Motor de respaldo local si no hay conexión a la Edge Function
    return _buildLocalFallbackResponse(
      query: query,
      moduleContext: moduleContext,
      profile: profile,
      telemetry: telemetry,
    );
  }

  ChatMessage _buildLocalFallbackResponse({
    required String query,
    required AssistantModuleContext moduleContext,
    UserProfile? profile,
    required AppTelemetryContext telemetry,
  }) {
    final q = query.toLowerCase().trim();
    final userFirstName =
        profile != null ? extractFirstName(profile.fullName) : 'Estimada/o';

    String responseText = '';
    List<String> nextSuggestions = [];

    // =========================================================================
    // CONOCIMIENTO INTEGRAL DEL PERFIL DE USUARIO ("Mi Perfil") Y UBICACIÓN UI
    // =========================================================================
    final isProfileQuery = q.contains('perfil') ||
        q.contains('mi perfil') ||
        q.contains('foto') ||
        q.contains('avatar') ||
        q.contains('telefono') ||
        q.contains('teléfono') ||
        q.contains('celular') ||
        q.contains('contacto') ||
        q.contains('cerrar sesión') ||
        q.contains('cerrar sesion') ||
        q.contains('salir') ||
        q.contains('logout') ||
        q.contains('desconectar') ||
        q.contains('modo oscuro') ||
        q.contains('modo claro') ||
        q.contains('modo nocturno') ||
        q.contains('tema visual') ||
        q.contains('mi cuenta') ||
        q.contains('mis datos') ||
        (q.contains('donde') && q.contains('datos'));

    if (isProfileQuery) {
      if (q.contains('foto') ||
          q.contains('avatar') ||
          q.contains('imagen') ||
          q.contains('camara') ||
          q.contains('cámara') ||
          q.contains('galeria') ||
          q.contains('galería')) {
        responseText =
            '$userFirstName, para cambiar tu fotografía de perfil o avatar en UMBRAL:\n\n'
            '1. 📍 **Ubicación:** En la **esquina superior derecha** de la pantalla, pulsa el avatar circular con borde verde menta neón (`UserProfileAvatarButton`). Se abrirá la ventana **"Mi Perfil"**.\n'
            '2. 📷 **Botón de Cámara:** En el centro superior del modal verás tu foto circular actual con un pequeño botón violeta de **cámara** en su esquina inferior derecha.\n'
            '3. 📂 **Selección:** Tócalo para desplegar las opciones:\n'
            '   • **Tomar Foto con Cámara:** Para capturar una foto al instante.\n'
            '   • **Seleccionar de la Galería:** Para elegir una foto desde tu galería.\n'
            '4. ✂️ **Optimización:** La app recorta y optimiza la imagen automáticamente.\n'
            '5. 💾 **Guardar:** Baja al final del modal y pulsa el botón violeta **"Guardar Cambios"**. Tu nueva foto se subirá a Supabase Storage y se actualizará de inmediato en toda la plataforma.';
        nextSuggestions = [
          '¿Cómo cambiar mi número de teléfono?',
          '¿Cómo alternar tema claro/oscuro?',
          '¿Cómo cerrar sesión?',
        ];
      } else if (q.contains('telefono') ||
          q.contains('teléfono') ||
          q.contains('celular') ||
          q.contains('contacto')) {
        responseText =
            '$userFirstName, para actualizar tu número de teléfono de contacto:\n\n'
            '1. 📍 **Ubicación:** Pulsa sobre tu avatar en la **esquina superior derecha** de la barra superior para abrir **"Mi Perfil"**.\n'
            '2. ✍️ **Campo de Teléfono:** Ubica el tercer campo de texto etiquetado como **"Número de Teléfono"** (identificado con el ícono de teléfono).\n'
            '3. 🔢 **Formato:** Escribe tu número activo (ejemplo: `04141234567` o `04241234567`).\n'
            '4. 💾 **Guardar:** Desplázate al botón violeta inferior **"Guardar Cambios"** y presiónalo. El sistema sincronizará tu nuevo número con Supabase en tiempo real.';
        nextSuggestions = [
          '¿Cómo cambiar mi foto de perfil?',
          '¿Dónde veo mi rol institucional?',
          '¿Cómo cerrar sesión?',
        ];
      } else if (q.contains('modo') ||
          q.contains('tema') ||
          q.contains('oscuro') ||
          q.contains('nocturno') ||
          q.contains('claro')) {
        responseText =
            '$userFirstName, en UMBRAL puedes alternar entre Modo Claro y Modo Nocturno de dos formas muy sencillas:\n\n'
            '1. ⚡ **Acceso Rápido en Cabecera:** En la esquina superior derecha, justo a la izquierda de tu foto de perfil, verás el botón de sol/luna (`ThemeModeToggleButton`). Tócalo una vez para cambiar instantáneamente de modo.\n'
            '2. 📱 **Desde Mi Perfil:** Abre **"Mi Perfil"** tocando tu avatar; baja hasta la tarjeta **"Tema Visual"** y activa o desactiva el interruptor (Switch).\n\n'
            'Tu preferencia se guarda en tu dispositivo y se mantiene activa en tus próximas visitas.';
        nextSuggestions = [
          '¿Qué más puedo hacer en Mi Perfil?',
          '¿Cómo actualizar mi teléfono?',
          '¿Cómo cambiar mi foto?',
        ];
      } else if (q.contains('cerrar') ||
          q.contains('salir') ||
          q.contains('logout') ||
          q.contains('desconectar')) {
        responseText =
            '$userFirstName, para cerrar tu sesión de forma segura:\n\n'
            '1. 📍 **Ubicación:** Pulsa tu avatar circular en la **esquina superior derecha** para abrir **"Mi Perfil"**.\n'
            '2. 🚪 **Botón de Cierre:** Baja hasta el final del formulario.\n'
            '3. 🛑 **Confirmación:** Pulsa el botón rojo **"Cerrar Sesión"** (con ícono de salida). Aparecerá un diálogo preguntando *¿Estás seguro de que deseas salir de tu cuenta?*.\n'
            '4. ✅ Pulsa **"Cerrar Sesión"** en el diálogo para desconectar tu usuario de Supabase y volver al login.';
        nextSuggestions = [
          '¿Cómo guardar cambios antes de salir?',
          '¿Cómo cambiar mi foto de perfil?',
        ];
      } else if (q.contains('rol') ||
          q.contains('permiso') ||
          q.contains('cédula') ||
          q.contains('cedula') ||
          q.contains('nombre')) {
        responseText =
            '$userFirstName, la información de tu cuenta se visualiza en **"Mi Perfil"** (esquina superior derecha):\n\n'
            '• 🏷️ **Rol Institucional:** Insignia destacada debajo de tu avatar (`ALUMNO`, `PROFESOR`, `COORDINADOR` o `SUPER ADMIN`). Determina tus permisos de acceso en UMBRAL.\n'
            '• 👤 **Nombre Completo:** Primer campo de texto del formulario; puedes editar cómo figura tu nombre en el sistema.\n'
            '• ✉️ **Correo Electrónico:** Segundo campo de texto con tu email verificado.\n'
            '• 🪪 **Cédula de Identidad:** Cuarto campo identificador institucional.\n\n'
            'Recuerda presionar **"Guardar Cambios"** si modificas cualquier dato.';
        nextSuggestions = [
          '¿Cómo actualizar mi teléfono?',
          '¿Cómo cambiar mi foto de perfil?',
          '¿Cómo alternar tema claro/oscuro?',
        ];
      } else {
        responseText =
            '$userFirstName, en UMBRAL tienes control total sobre tu cuenta a través de **"Mi Perfil"**:\n\n'
            '📍 **¿Dónde se encuentra?**\n'
            'En la **esquina superior derecha** de la pantalla mediante el botón circular de avatar con borde verde menta neón (muestra tu foto o iniciales). También puedes abrir el menú desplegable (tres puntos/flecha) y seleccionar **"Mi Perfil"**.\n\n'
            '🛠️ **Todo lo que puedes realizar en Mi Perfil:**\n'
            '1. 📸 **Actualizar Foto / Avatar:** Toca el botón violeta de cámara sobre tu foto para cargar una imagen desde tu galería o cámara.\n'
            '2. 🏷️ **Verificar tu Rol:** Debajo de tu foto verás tu credencial oficial (ALUMNO, PROFESOR, COORDINADOR o SUPER ADMIN).\n'
            '3. 👤 **Modificar Nombre:** Primer campo para editar tu nombre completo.\n'
            '4. ✉️ **Correo Electrónico:** Segundo campo con tu email registrado.\n'
            '5. 📞 **Actualizar Teléfono:** Tercer campo para ingresar tu número celular de contacto.\n'
            '6. 🪪 **Cédula de Identidad:** Cuarto campo con tu documento.\n'
            '7. 🌓 **Cambiar Tema Visual:** Interruptor para alternar entre Modo Claro y Modo Nocturno.\n'
            '8. 💾 **Guardar Cambios:** Botón violeta para guardar y sincronizar con Supabase en tiempo real.\n'
            '9. 🚪 **Cerrar Sesión:** Botón rojo inferior para salir de forma protegida.';
        nextSuggestions = [
          '¿Cómo cambiar mi foto de perfil?',
          '¿Cómo actualizar mi número de teléfono?',
          '¿Cómo alternar tema claro/oscuro?',
        ];
      }

      return ChatMessage(
        id: 'res-${DateTime.now().millisecondsSinceEpoch}',
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
        suggestions: nextSuggestions,
      );
    }

    // Lógica contextual por módulo
    switch (moduleContext.id) {
      case 'alumnos':
        if (q.contains('asistencia') || q.contains('práctica') || q.contains('practica') || q.contains('asistir')) {
          responseText =
              '$userFirstName, para confirmar tu asistencia a una clase práctica:\n\n'
              '1. Dirígete a la pestaña **"Mis Cursos"** o **"Asistencias"**.\n'
              '2. Selecciona la clase práctica programada.\n'
              '3. Pulsa el botón **"Confirmar Asistencia"**.\n'
              '4. Si la clase requiere aporte de insumos, verás el monto por participante y la opción de adjuntar tu comprobante de pago móvil.\n\n'
              'Tu confirmación permite al profesor y a coordinación planificar adecuadamente los materiales del taller.';
          nextSuggestions = [
            '¿Dónde veo el costo de insumos?',
            '¿Cómo ver mis asistencias anteriores?',
          ];
        } else if (q.contains('encuesta') || q.contains('satisfacción') || q.contains('satisfaccion')) {
          responseText =
              'Las encuestas de satisfacción institucional te permiten calificar la experiencia del curso y el desempeño docente:\n\n'
              '1. Entra a la pestaña **"Encuestas"** en tu panel de Alumno.\n'
              '2. Selecciona la encuesta activa que corresponde a tu curso.\n'
              '3. Responde a las preguntas de evaluación y envía tus respuestas.\n\n'
              'Tus comentarios son fundamentales para la mejora continua de los programas de IMMUJER.';
          nextSuggestions = [
            '¿Son anónimas las encuestas?',
            '¿Cómo actualizar mis datos de perfil?',
          ];
        } else if (q.contains('perfil') || q.contains('datos') || q.contains('foto') || q.contains('actualizar')) {
          responseText =
              'Para actualizar tus datos personales o foto de perfil:\n\n'
              '1. En la esquina superior derecha de la pantalla, pulsa sobre el avatar con tus iniciales o foto.\n'
              '2. Se abrirá la ventana **"Mi Perfil"**.\n'
              '3. Allí puedes actualizar tu número de teléfono, cambiar tu fotografía y verificar tu correo registrado.\n'
              '4. Recuerda presionar **"Guardar Cambios"** al finalizar.';
          nextSuggestions = [
            '¿Cómo ver el temario del curso?',
            '¿Cómo confirmar mi asistencia?',
          ];
        } else {
          responseText =
              '$userFirstName, en el **Módulo de Alumnos** puedes supervisar tus formaciones activas en IMMUJER, verificar tu asistencia y gestionar tus clases.\n\n'
              'Si tienes alguna duda sobre horarios, aportes de insumos o constancias, indícamelo y con gusto te proporciono el paso a paso.';
          nextSuggestions = moduleContext.quickPrompts;
        }
        break;

      case 'profesores':
        if (q.contains('asistencia') || q.contains('registrar') || q.contains('toma')) {
          responseText =
              'Profesor(a) $userFirstName, para registrar la asistencia de tus alumnas:\n\n'
              '1. Ve a la pestaña **"Asistencia"** en tu panel docente.\n'
              '2. Selecciona el curso y la fecha de la sesión.\n'
              '3. Marca la casilla de presencia de cada estudiante inscrita.\n'
              '4. El sistema sincroniza automáticamente los totales de alumnos presentes y ausentes en tiempo real con Supabase.';
          nextSuggestions = [
            '¿Cómo crear una encuesta para mis alumnos?',
            '¿Cómo calcular el costo de insumos?',
          ];
        } else if (q.contains('tema') || q.contains('solicitud') || q.contains('temario') || q.contains('propuesta')) {
          responseText =
              'Para solicitar la adición o modificación de un tema en el pensum:\n\n'
              '1. En la sección de **"Mis Cursos"**, ubica la tarjeta del curso.\n'
              '2. Pulsa en **"Proponer nuevo tema"**.\n'
              '3. Escribe el título y contenido del tema propuesto.\n'
              '4. La solicitud será enviada de inmediato a Coordinación para su revisión y aprobación institucional.';
          nextSuggestions = [
            '¿Cómo saber si mi tema fue aprobado?',
            '¿Cómo registrar la asistencia?',
          ];
        } else if (q.contains('encuesta') || q.contains('evaluacion') || q.contains('evaluación')) {
          responseText =
              'Profesor(a) $userFirstName, para crear y activar una encuesta para tus alumnas:\n\n'
              '1. Dirígete a la pestaña **"Encuestas"** en tu panel docente.\n'
              '2. Pulsa el botón **"Crear Encuesta"** o el icono **"+"** en la cabecera.\n'
              '3. Asigna un título descriptivo (ej. "Evaluación de Clase Práctica"), selecciona el curso y define los criterios de calificación de 1 a 5 estrellas.\n'
              '4. Pulsa **"Activar Encuesta"** para que esté disponible de inmediato para las alumnas inscritas.';
          nextSuggestions = [
            '¿Cómo registrar la asistencia de una clase?',
            '¿Cómo solicitar la aprobación de un nuevo tema?',
          ];
        } else if (q.contains('insumos') || q.contains('costo') || q.contains('pago móvil') || q.contains('banco')) {
          responseText =
              'Para configurar el costo de insumos de una clase práctica:\n\n'
              '1. Accede al detalle de la clase práctica planificada.\n'
              '2. Ingresa el monto total estimado de materiales y selecciona los datos de Pago Móvil institucional.\n'
              '3. El sistema dividirá el costo entre las participantes confirmadas y mostrará a cada alumna el monto individual a aportar.';
          nextSuggestions = [
            '¿Dónde veo los comprobantes subidos?',
            '¿Cómo registrar la asistencia?',
          ];
        } else {
          responseText =
              'Profesor(a) $userFirstName, como docente en UMBRAL puedes gestionar el pase de lista de tus cursos, crear encuestas estudiantiles, proyectar costos de insumos para talleres prácticos y proponer actualizaciones de temarios a Coordinación.';
          nextSuggestions = moduleContext.quickPrompts;
        }
        break;

      case 'coordinacion':
        if (q.contains('navegar') ||
            q.contains('interfaz') ||
            q.contains('secciones') ||
            q.contains('pestana') ||
            q.contains('pestaña') ||
            q.contains('menu') ||
            q.contains('menú') ||
            q.contains('cursos') ||
            q.contains('insumos')) {
          responseText =
              'Coordinador(a) $userFirstName, tu interfaz de Coordinación está organizada en 4 secciones accesibles desde el menú lateral o desplegable:\n\n'
              '1. 📚 **Cursos:** Supervisión y control de ofertas formativas, cupos y estado general.\n'
              '2. 📡 **En Vivo:** Telemetría de sesiones activas, porcentaje de asistencia en tiempo real y flujo de clases.\n'
              '3. 👩‍🏫 **Profesores:** Directorio docente, cursos asignados y estatus de vinculación.\n'
              '4. 💰 **Insumos:** Revisión de costos de insumos de clases prácticas y comprobantes de aporte.\n\n'
              'Además, en la barra superior dispones del botón **"Ver Registros"** para ir directamente al Centro de Reportes y el menú de navegación rápida.';
          nextSuggestions = [
            '¿Dónde reviso y apruebo las solicitudes de temarios?',
            '¿Cómo consultar reportes consolidados y registros?',
            '¿Cómo supervisar las clases en vivo y asistencias?',
          ];
        } else if (q.contains('solicitud') || q.contains('aprob') || q.contains('temario') || q.contains('tema')) {
          responseText =
              'Para gestionar las solicitudes de temarios pendientes de profesores:\n\n'
              '1. En la vista principal de Coordinación, revisa el panel de **"Solicitudes de Aprobación"**.\n'
              '2. Podrás verificar el docente solicitante, el curso asociado y los detalles del nuevo tema propuesto.\n'
              '3. Presiona **"Aprobar"** para integrarlo formalmente al curso o **"Rechazar"** si requiere ajustes.';
          nextSuggestions = [
            '¿Cómo navegar entre Cursos, En Vivo, Profesores e Insumos?',
            '¿Cómo consultar reportes consolidados y registros?',
          ];
        } else if (q.contains('reporte') || q.contains('excel') || q.contains('pdf') || q.contains('registros')) {
          responseText =
              'Para consultar y descargar reportes oficiales:\n\n'
              '1. Haz clic en el botón superior **"Ver Registros"** o navega a la sección de Reportes.\n'
              '2. Filtra por cohorte, curso o docente.\n'
              '3. Utiliza los botones de exportación a **PDF** o planilla digital para la gestión administrativa de IMMUJER.';
          nextSuggestions = [
            '¿Cómo navegar entre Cursos, En Vivo, Profesores e Insumos?',
            '¿Cómo supervisar las clases en vivo y asistencias?',
          ];
        } else if (q.contains('vivo') || q.contains('asistencia') || q.contains('supervisar')) {
          responseText =
              'Para supervisar la asistencia y clases en desarrollo:\n\n'
              '1. Haz clic en la pestaña **"En Vivo"** en el panel de navegación.\n'
              '2. Visualizarás los cursos activos hoy con su tasa de asistencia en tiempo real y total de alumnas presentes.\n'
              '3. Esto te permite garantizar el cumplimiento pedagógico de cada formación.';
          nextSuggestions = [
            '¿Cómo navegar entre Cursos, En Vivo, Profesores e Insumos?',
            '¿Dónde reviso y apruebo las solicitudes de temarios?',
          ];
        } else {
          responseText =
              'Coordinador(a) $userFirstName, en esta interfaz puedes navegar entre la gestión de cursos, monitoreo en vivo de clases, supervisión docente, revisión de costos de insumos y generación de reportes oficiales de IMMUJER.';
          nextSuggestions = moduleContext.quickPrompts;
        }
        break;

      case 'superadmin':
        if (q.contains('bcv') || q.contains('tasa') || q.contains('dólar') || q.contains('dolar') || q.contains('cambio')) {
          responseText =
              'La tasa cambiaria oficial del BCV se sincroniza de forma automatizada mediante una función programada en PostgreSQL/Supabase cada día laboral.\n\n'
              'Además, en el panel Super Admin dispones de la opción de forzar una sincronización manual en vivo o establecer una tasa de contingencia en la sección de **Configuración General**.';
          nextSuggestions = [
            '¿Cómo modificar roles de usuario?',
            '¿Cómo auditar las políticas RLS?',
          ];
        } else if (q.contains('rol') || q.contains('usuario') || q.contains('permiso')) {
          responseText =
              'Para gestionar usuarios y roles del sistema:\n\n'
              '1. Entra a los submódulos de **Gestión de Alumnos** o **Gestión de Profesores**.\n'
              '2. Localiza al usuario requerido mediante el buscador.\n'
              '3. Puedes actualizar su estado, revocar o elevar privilegios de acceso directamente sobre la tabla `perfiles`.';
          nextSuggestions = [
            '¿Cómo funciona la sincronización BCV?',
            '¿Dónde veo la telemetría en vivo?',
          ];
        } else if (q.contains('rls') || q.contains('seguridad') || q.contains('base de datos')) {
          responseText =
              'Todas las tablas principales (`perfiles`, `cursos`, `asistencias`, `encuestas`, `solicitudes_aprobacion`) operan bajo **Row Level Security (RLS)** estricto con políticas por rol.\n\n'
              'El rol Super Admin cuenta con directivas `SECURITY DEFINER` e inspección privilegiada para mantener la integridad de la base de datos institucional.';
          nextSuggestions = [
            '¿Cómo acceder a los ajustes de impresión?',
            '¿Cómo cambiar parámetros generales?',
          ];
        } else {
          responseText =
              'Super Administrador(a) $userFirstName, en este centro de mando puedes monitorear la telemetría en tiempo real, configurar parámetros generales de UMBRAL, auditar eventos y gestionar la infraestructura técnica de IMMUJER.';
          nextSuggestions = moduleContext.quickPrompts;
        }
        break;

      default:
        responseText =
            '$userFirstName, estoy para ayudarte en todo lo relacionado con la plataforma UMBRAL del Instituto Municipal de la Mujer (IMMUJER).\n\n'
            'Puedes consultar sobre cursos formativos, pase de lista de asistencia, encuestas de satisfacción, comprobantes prácticos y configuraciones.';
        nextSuggestions = [
          '¿Cómo confirmo asistencia a un taller?',
          '¿Dónde veo mis cursos activos?',
          '¿Cómo cambiar a modo oscuro?',
        ];
    }

    return ChatMessage(
      id: 'res-${DateTime.now().millisecondsSinceEpoch}',
      text: responseText,
      isUser: false,
      timestamp: DateTime.now(),
      suggestions: nextSuggestions,
    );
  }
}
