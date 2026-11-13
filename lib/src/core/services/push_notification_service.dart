import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manejador de notificaciones push en segundo plano cuando la app está cerrada o en background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('[PushNotificationService] Mensaje en background recibido: ${message.messageId}');
}

/// Categorías específicas de notificaciones de UMBRAL
enum NotificationCategory {
  scheduleChange,     // Cambio de horario de clases
  paymentApproval,    // Aprobación de aportes
  attendanceReminder, // Recordatorios de toma de asistencia
  general,            // Avisos generales
}

/// Servicio integral para Firebase Cloud Messaging (FCM) y notificaciones locales en barra de estado.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  // Canales Android dedicados
  static const AndroidNotificationChannel channelSchedule = AndroidNotificationChannel(
    'umbral_schedule_channel',
    'Horarios de Clases',
    description: 'Alertas y cambios en la programación de cursos y talleres.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel channelPayments = AndroidNotificationChannel(
    'umbral_payments_channel',
    'Aportes y Pagos',
    description: 'Aprobación y verificación de aportes e insumos.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel channelAttendance = AndroidNotificationChannel(
    'umbral_attendance_channel',
    'Recordatorios de Asistencia',
    description: 'Notificaciones y recordatorios para toma de asistencia docente.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Inicializa Firebase Messaging y el plugin de notificaciones locales para Android y Web.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Inicializar Notificaciones Locales (Barra de estado Android)
    const androidSettings = AndroidInitializationSettings('@drawable/ic_stat_icono_umbral');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[PushNotificationService] Notificación tocada: ${response.payload}');
        },
      );

      // Crear canales de notificación en Android
      final androidPlatform = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.createNotificationChannel(channelSchedule);
        await androidPlatform.createNotificationChannel(channelPayments);
        await androidPlatform.createNotificationChannel(channelAttendance);
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error al inicializar notificaciones locales: $e');
    }

    // 2. Inicializar Firebase Messaging de forma segura (con fallback si no está configurado google-services.json)
    try {
      if (Firebase.apps.isNotEmpty) {
        final messaging = FirebaseMessaging.instance;

        // Solicitar permisos en Android 13+ e iOS
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint('[PushNotificationService] Permiso FCM: ${settings.authorizationStatus}');

        // Obtener Token de dispositivo
        // ignore: deprecated_member_use
        _fcmToken = await messaging.getToken();
        debugPrint('[PushNotificationService] Token FCM: $_fcmToken');

        // Escuchar refresco de token
        // ignore: deprecated_member_use
        messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          debugPrint('[PushNotificationService] Token FCM renovado: $_fcmToken');
        });

        // Registrar handler de segundo plano
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        // Escuchar mensajes en primer plano (Foreground) y proyectarlos a la barra de estado
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('[PushNotificationService] Mensaje en primer plano: ${message.notification?.title}');
          _showNotificationFromRemote(message);
        });
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Firebase Messaging no disponible o pendiente de google-services.json: $e');
    }

    _isInitialized = true;
  }

  /// Proyecta un mensaje push recibido hacia la barra de estado del sistema.
  Future<void> _showNotificationFromRemote(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['tipo']?.toString().toLowerCase() ?? '';
    AndroidNotificationChannel targetChannel = channelSchedule;

    if (type.contains('pago') || type.contains('aporte')) {
      targetChannel = channelPayments;
    } else if (type.contains('asistencia') || type.contains('recordatorio')) {
      targetChannel = channelAttendance;
    }

    await showNotification(
      title: notification.title ?? 'UMBRAL IMMUJER',
      body: notification.body ?? '',
      channel: targetChannel,
      payload: message.data.toString(),
    );
  }

  /// Dispara una notificación directa en la barra de estado del dispositivo.
  Future<void> showNotification({
    required String title,
    required String body,
    AndroidNotificationChannel? channel,
    String? payload,
  }) async {
    final activeChannel = channel ?? channelSchedule;
    final androidDetails = AndroidNotificationDetails(
      activeChannel.id,
      activeChannel.name,
      channelDescription: activeChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_icono_umbral',
      largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_stat_icono_umbral'),
      playSound: true,
      enableVibration: true,
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Error al mostrar notificación: $e');
    }
  }

  /// Dispara una alerta en la barra de estado por Cambio de Horario de Clases
  Future<void> alertClassScheduleChange({
    required String cursoNombre,
    required String nuevoHorario,
  }) async {
    await showNotification(
      title: 'Cambio de Horario: $cursoNombre',
      body: 'El horario ha sido actualizado a: $nuevoHorario. Consulta tu aula en la app.',
      channel: channelSchedule,
    );
  }

  /// Dispara una alerta en la barra de estado por Aprobación de Aporte
  Future<void> alertPaymentApproved({
    required String cursoNombre,
    required double monto,
  }) async {
    await showNotification(
      title: 'Aporte Aprobado - $cursoNombre',
      body: 'Tu aporte de \$${monto.toStringAsFixed(2)} ha sido verificado y aprobado exitosamente.',
      channel: channelPayments,
    );
  }

  /// Dispara una alerta en la barra de estado por Recordatorio de Asistencia
  Future<void> alertAttendanceReminder({
    required String cursoNombre,
  }) async {
    await showNotification(
      title: 'Recordatorio de Asistencia',
      body: 'Recuerda registrar la asistencia de tus alumnas en el curso "$cursoNombre".',
      channel: channelAttendance,
    );
  }

  /// Sincroniza el FCM Token del usuario logueado en su perfil de Supabase
  Future<void> syncUserFcmToken(String userId, SupabaseClient supabase) async {
    if (_fcmToken == null || _fcmToken!.isEmpty) return;

    try {
      await supabase.from('perfiles').update({
        'fcm_token': _fcmToken,
        'fcm_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      debugPrint('[PushNotificationService] FCM Token guardado en Supabase para usuario: $userId');
    } catch (e) {
      // Ignorar de forma segura si la columna fcm_token aún no ha sido creada en perfiles
      debugPrint('[PushNotificationService] Error al guardar FCM token en perfiles: $e');
    }
  }
}
