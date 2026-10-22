import 'package:flutter/material.dart';

import 'src/core/config/supabase_config.dart';
import 'src/core/theme/app_theme.dart';
import 'features/landing/presentation/pages/landing_page.dart';
import 'src/features/auth/presentation/login_screen.dart';
import 'src/features/auth/presentation/register_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Supabase cargando las credenciales seguras desde .env
  await SupabaseConfig.initialize();

  runApp(const UmbralApp());
}

class UmbralApp extends StatelessWidget {
  const UmbralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UMBRAL - IMMUJER',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LandingPage(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
      },
    );
  }
}
