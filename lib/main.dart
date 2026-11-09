import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/router/app_router.dart';
import 'core/services/error_console_service.dart';
import 'features/teacher/data/attendance_offline_service.dart';
import 'src/core/config/supabase_config.dart';
import 'src/core/services/online_user_presence_service.dart';
import 'src/core/services/push_notification_service.dart';
import 'src/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Hive y el servicio de persistencia y sincronización offline de asistencias.
  await Hive.initFlutter();
  await AttendanceOfflineService.instance.initialize();

  // Inicializa Firebase y el servicio de notificaciones push (FCM y barra de estado)
  try {
    if (!kIsWeb) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[main] Firebase inicializado en modo fallback local: $e');
  }
  await PushNotificationService.instance.initialize();

  // Inicializa Supabase con valores de compilación recibidos mediante --dart-define.
  await SupabaseConfig.initialize();
  await OnlineUserPresenceService.instance.initialize(SupabaseConfig.client);

  // Inicializa y recupera la preferencia de tema guardada (claro/oscuro).
  await ThemeController.initialize();

  // Configura observadores globales para registrar errores en la consola de diagnóstico en memoria.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorConsoleService.instance.registrarError(
      origen: 'Framework Flutter UI',
      error: details.exceptionAsString(),
      causa: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorConsoleService.instance.registrarError(
      origen: 'Motor Dart Asíncrono',
      error: error,
      causa: stack,
    );
    return true;
  };

  runApp(const UmbralApp());
}

class UmbralApp extends StatelessWidget {
  const UmbralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        return MaterialApp.router(
          title: 'UMBRAL - IMMUJER',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
