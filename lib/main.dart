import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'src/core/config/supabase_config.dart';
import 'src/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase con valores de compilación recibidos mediante --dart-define.
  await SupabaseConfig.initialize();

  runApp(const UmbralApp());
}

class UmbralApp extends StatelessWidget {
  const UmbralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'UMBRAL - IMMUJER',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
