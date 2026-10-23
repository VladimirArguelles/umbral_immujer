# umbral_immujer

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## Configuración de Supabase

La aplicación recibe la URL de Supabase y la clave publicable al compilar; no carga
credenciales desde `.env`. En PowerShell, define las variables en la sesión actual:

```powershell
$env:SUPABASE_URL = "https://tu-proyecto.supabase.co"
$env:SUPABASE_PUBLISHABLE_KEY = "tu-clave-publicable"
```

Después, pásalas a Flutter con `--dart-define` al ejecutar o compilar, por ejemplo:

```powershell
flutter build web `
  --base-href /umbral_immujer/ `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY
```

La clave publicable se incluye en la aplicación web y no es un secreto. Nunca uses
una clave `service_role` en una aplicación cliente.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
