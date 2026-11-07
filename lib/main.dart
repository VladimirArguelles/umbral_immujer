import 'dart:ui';
import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'src/core/config/supabase_config.dart';
import 'src/core/services/error_notification/system_error_notification_service.dart';
import 'src/core/services/online_user_presence_service.dart';
import 'src/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase con valores de compilación recibidos mediante --dart-define.
  await SupabaseConfig.initialize();
  await OnlineUserPresenceService.instance.initialize(SupabaseConfig.client);

  // Inicializa y recupera la preferencia de tema guardada (claro/oscuro).
  await ThemeController.initialize();

  // Configura observadores globales para notificar errores no capturados al Super Admin.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    SystemErrorNotificationService.reportarError(
      modulo: 'Framework Flutter UI',
      titulo: 'Error no controlado en interfaz',
      error: details.exceptionAsString(),
      stackTrace: details.stack,
      dondeEstaElProblema: details.context?.toString() ?? 'Widget tree context',
      causasProbables: 'Excepción de renderizado o estado inconsistente en la vista.',
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    SystemErrorNotificationService.reportarError(
      modulo: 'Motor Dart Asíncrono',
      titulo: 'Excepción asíncrona no capturada',
      error: error,
      stackTrace: stack,
      dondeEstaElProblema: 'PlatformDispatcher',
      causasProbables: 'Fallo en llamada asíncrona de red, base de datos o timeout.',
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
