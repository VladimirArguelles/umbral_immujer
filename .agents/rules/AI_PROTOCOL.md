# Protocolo de Desarrollo e Inteligencia Artificial para Umbral_Immujer

> Instrucción para la IA: al abrir este documento, adopta de inmediato el rol de asistente experto en Flutter, Dart y Supabase para el proyecto Umbral_Immujer. Debes razonar con precisión, verificar fuentes de verdad reales y ajustar todo lo que hagas al contexto técnico y funcional de esta aplicación.

---

## 1. Objetivo del proyecto

Umbral_Immujer es una aplicación Flutter orientada a la gestión de formaciones, usuarios, seguimiento académico, coordinación y administración operativa. El sistema combina una capa móvil/web en Flutter con Supabase como backend y base de datos relacional.

El agente debe trabajar siempre bajo estos principios:
- Calidad técnica prioritaria sobre velocidad.
- Verificación de hechos sobre suposiciones.
- Adaptación exacta al proyecto y no a patrones genéricos.
- Mantenimiento de consistencia visual con el sistema de diseño del proyecto.
- Cero credenciales, secretos o datos sensibles en código fuente.

---

## 2. Stack tecnológico y arquitectura real

### 2.1. Stack
- Flutter + Dart
- Material 3
- Supabase (Auth, Base de Datos, Storage, RLS)
- Modelo feature-first con archivos de dominio, datos y presentación
- Web estática publicada en `docs/` para GitHub Pages

### 2.2. Estructura relevante del proyecto
- `lib/main.dart`
- `lib/features/` — módulos funcionales del producto
  - `assistant/`
  - `coordinator/`
  - `student/`
  - `teacher/`
  - `superadmin/`
  - `reports/`
  - `profile/`
  - `printing/`
  - `landing/`
- `lib/src/core/` — utilidades compartidas, tema y configuración
- `lib/src/features/auth/` — autenticación y perfil de usuario
- `supabase/migrations/` — esquema y cambios de base de datos
- `docs/` — salida compilada para web
- `web/` — configuración web
- `pubspec.yaml` — dependencias del proyecto

### 2.3. Fuentes de verdad
Antes de editar cualquier comportamiento, consulta siempre la fuente real de la lógica o esquema:
- Código Flutter en `lib/`
- Configuración del tema en `lib/src/core/theme/app_theme.dart`
- Configuración de Supabase en `lib/src/core/config/supabase_config.dart`
- Modelos y repositorios en cada feature
- Migraciones SQL en `supabase/migrations/`
- Documentos de diseño del proyecto: `DESIGN.md`, `AGENTS.md`

No se debe asumir nombres de columnas, tablas, rutas, modelos o estados sin verificarlos.

---

## 3. Reglas de arquitectura para Umbral_Immujer

### 3.1. Diseño de software
- Mantener una separación clara entre `data`, `domain` y `presentation` dentro de cada feature.
- Preferir abstracciones y repositorios sobre lógica embebida en widgets.
- Reutilizar servicios compartidos y utilidades del núcleo en lugar de duplicar lógica.
- Aplicar tipado fuerte, null safety y manejo explícito de errores.

### 3.2. Base de datos y Supabase
- Usar UUID cuando el esquema lo requiera y respetar los patrones de claves y auditoría del proyecto.
- Incluir campos de control como `created_at` y `updated_at` si aplica al modelo.
- Usar `TIMESTAMPTZ` para fechas, `JSONB` cuando sea necesario y `NUMERIC/DECIMAL` para valores monetarios o cuantitativos.
- Habilitar RLS en tablas de Supabase cuando se creen o modifiquen definiciones.
- Definir políticas explícitas de acceso según el usuario o rol relevante.
- Crear índices para filtros, joins y búsquedas habituales.

### 3.3. Autenticación y usuario
- No hardcodear credenciales, claves ni secretos.
- Para la app cliente, usar la URL y la clave pública de Supabase en tiempo de compilación o ejecución.
- Nunca usar `service_role` ni claves secretas en la aplicación Flutter.
- Mantener un perfil público del usuario y una integración con el flujo de autenticación de Supabase.

### 3.4. Diseño visual y sistema de diseño
- Los componentes deben consumir los tokens semánticos definidos en `lib/src/core/theme/app_theme.dart` y no crear paletas locales arbitrarias.
- El proyecto usa una identidad visual oscura con acentos violeta, verde de éxito y gris profundo.
- Los cambios de UI deben respetar `DESIGN.md` y la semántica de colores del sistema.
- Evitar mockups, datos inventados o textos placeholder en vistas funcionales.

### 3.5. Gestor de actualizaciones In-App y distribución Android
- **Invocación contextual exclusiva en Dashboards principales:**
  - El diálogo modal de "Actualización Disponible" (`AppUpdateDialog`) solo debe invocarse en la pantalla principal de inicio (Dashboard inicial del rol: `/`, `/student`, `/teacher`, `/coordinator`, `/superadmin`).
  - Prohibido disparar comprobaciones intrusivas o desplegar modales de actualización al navegar entre submódulos, pestañas secundarias o pantallas de configuración.
  - Mantener control de sesión para no repetir el aviso en la misma sesión salvo actualización obligatoria o acción explícita del usuario.
- **Normalización estricta de versiones semánticas (Semver):**
  - La lógica de comparación debe extraer y evaluar únicamente la versión canónica mayor, menor y parche (`major.minor.patch`, ej. `0.1.2` vs `0.1.3`), ignorando sufijos de compilación local (`+3`, `+2`), prefijos (`v`) o etiquetas pre-release (`-beta`).
  - Una versión remota solo se considerará válida para actualización si es estrictamente superior numéricamente (`remote > local`). Esto previene bucles infinitos de actualización en dispositivos que ya poseen instalada la última versión.
- **Almacenamiento seguro y políticas de permisos en Android:**
  - Utilizar obligatoriamente `getExternalStorageDirectory()` (mapeado a `context.getExternalFilesDir(null)`) para descargar el paquete de instalación APK.
  - Prohibido solicitar o depender del permiso de amplio espectro `MANAGE_EXTERNAL_STORAGE` (All Files Access) ni guardar en directorios públicos no administrados (`/sdcard/Download`), garantizando pleno cumplimiento con las directivas de seguridad de Android 11+ (Scoped Storage) y evitando bloqueos o rechazos en Google Play Store.
- **Instalación nativa con `open_filex` y exposición de errores:**
  - La invocación del instalador nativo debe ejecutarse mediante `open_filex` indicando el MIME type `application/vnd.android.package-archive`.
  - Ante cualquier eventualidad o rechazo del sistema operativo (falta de permisos para instalar apps desconocidas, paquete corrupto o caída de red), se debe capturar y exponer la causa real del error (código de estado HTTP, detalle de permisos del sistema o excepción exacta) en lugar de emitir mensajes genéricos o ambiguos.

### 3.6. Gestión de dependencias y compatibilidad con Kotlin/Flutter
- **Actualización preventiva en `pubspec.yaml`:** Para evitar problemas de compilación con Kotlin a futuro, mantener actualizadas las dependencias declaradas en `pubspec.yaml` (especialmente los paquetes de Firebase como `firebase_core` y `firebase_auth`, además de `firebase_messaging` y otros plugins nativos Android cuando estén presentes o se integren) a sus versiones más recientes compatibles con la versión activa de Flutter, AGP y Kotlin (`android/settings.gradle.kts`).
- **Validación de compatibilidad:** Antes de integrar o actualizar plugins nativos, verificar versiones con `flutter pub outdated` y confirmar que el análisis estático (`flutter analyze`) y las compilaciones objetivo permanecen estables.

---

## 4. Anti-alucinación y validación de contexto

### 4.1. Regla fundamental
Nunca inventes columnas, rutas, funciones, estados o contratos. Si no lo has verificado en el código o en la migración relevante, no lo describas ni lo implementes como si fuera real.

### 4.2. Lectura enfocada
- Leer primero solo los archivos y rangos necesarios.
- Evitar búsquedas masivas sobre todo el repositorio.
- Enfocar la inspección en el feature o módulo involucrado.
- Si hay dudas sobre nombres exactos, comprobarlos antes de editar o comentar.

### 4.3. Reglas de edición segura
- Verifica imports, dependencias y alcance del widget o función antes de modificarlo.
- Asegúrate de que cualquier cambio de UI quede dentro del árbol correcto del widget y no rompa la composición del widget raíz.
- Si se refactoriza código, limpia imports y variables no usadas.
- No crear scripts temporales para parchear archivos fuente.

---

## 5. Reglas del flujo de trabajo

### 5.1. Un cambio a la vez
- Trabaja sobre un objetivo concreto y aislado.
- Evita mezclar una corrección, un refactor y una nueva funcionalidad en una sola operación.
- Si un cambio afecta varios módulos, dividirlo en pasos verificables.

### 5.2. Cambios pequeños frente a cambios complejos
- Para cambios pequeños y claramente delimitados, edita directamente y valida.
- Para cambios más complejos y con mayor riesgo, documenta primero la causa raíz, los archivos involucrados y la estrategia antes de implementar.

### 5.3. Trabajo en el directorio del proyecto
- Operar estrictamente dentro del repositorio de Umbral_Immujer.
- Evitar movimientos fuera del alcance del proyecto.
- Respetar la estructura de carpetas y no crear archivos basura.

---

## 6. Pipeline obligatorio de validación

### 6.1. Verificación mínima requerida
Antes de cerrar una tarea o dejarla lista para revisión:
1. `flutter pub get`
2. `flutter analyze`
3. Si la tarea toca lógica de negocio o widgets relevantes, ejecutar tests específicos o `flutter test` cuando sea viable.

### 6.2. Compilación web obligatoria
Cuando se modifica la app o se trabaja en UI, se debe actualizar la salida Web en `docs/` usando:

```powershell
flutter build web --release --base-href "/umbral_immujer/" --output docs --dart-define-from-file=.env
```

Esto garantiza que la versión web del proyecto siga sincronizada con el repositorio y con la publicación en GitHub Pages.

### 6.3. Publicación obligatoria en GitHub
Siempre que se realice una modificación en el proyecto, además de compilar la versión web en `docs/`, se debe subir los cambios al repositorio remoto de GitHub para dejar el estado actualizado y disponible.

Reglas obligatorias:
- Ejecutar la compilación web antes de cerrar la tarea.
- Revisar el estado de Git y confirmar que solo se suben los cambios relevantes para la tarea.
- Hacer `git add` solo de las rutas modificadas y no mezclar trabajo ajeno.
- Crear commit con mensaje claro y subir los cambios al repositorio remoto.
- Si el proyecto requiere publicar la versión web, dejar `docs/` sincronizado con la rama activa.

Ejemplo de flujo mínimo requerido:

```powershell
flutter pub get
flutter analyze
flutter build web --release --base-href "/umbral_immujer/" --output docs --dart-define-from-file=.env
git status --short
git add AI_PROTOCOL.md AGENTS.md docs/
git commit -m "chore: sincronizar compilación web y protocolo"
git push origin main
```

Si hay cambios ajenos no relacionados, no se deben mezclar ni sobrescribir; se trabajará solo sobre los archivos de la tarea actual.

### 6.4. Actualización Obligatoria de Archivo de Aplicación, Versión y Notificación OTA
Siempre que se realice cualquier modificación en la aplicación o su interfaz:
1. **Incremento de Versión en `pubspec.yaml`:** Incrementar obligatoriamente la versión canónica y número de compilación (`version: major.minor.patch+build_number`, ej: de `0.1.4+5` a `0.1.5+6`).
2. **Actualización del Archivo de la Aplicación y Assets:**
   - Compilar y actualizar la salida web en `docs/` (`flutter build web --release --base-href "/umbral_immujer/" --output docs --dart-define-from-file=.env`).
   - Garantizar la generación y publicación del nuevo archivo binario de la aplicación (`app-release.apk`) mediante el flujo automatizado de GitHub Actions (`.github/workflows/build_apk.yml`) al hacer push a `main`.
3. **Sincronización en Base de Datos Supabase (`configuracion_general`):**
   - `app_version_latest`: Fijar a la nueva versión canónica (ej: `'0.1.5'`).
   - `app_build_number`: Fijar al nuevo entero de compilación (ej: `6`).
   - `app_apk_url`: Asegurar que apunte a `https://github.com/VladimirArguelles/umbral_immujer/releases/latest/download/app-release.apk`.
   - `app_update_notes`: Redactar las notas resumidas de los cambios de la versión.
4. **Activación de Notificación en Clientes:** La combinación de versión superior y nuevo `build_number` en Supabase garantiza que todos los dispositivos móviles activos detecten la actualización inmediatamente al abrir la app o dashboard y presenten el modal de descarga e instalación.

### 6.5. Control de versión y staging
- Hacer `git add` solo de las rutas modificadas y relevantes para la tarea.
- No hacer stage global ni sobrescribir cambios ajenos.
- Si hay cambios no relacionados en el repositorio, no tocarlos ni mezclarlos.

---

## 7. Reglas de seguridad y credenciales

- Nunca hardcodear claves de Supabase ni secretos.
- No guardar tokens, URLs reales o credenciales confidenciales en archivos de código fuente.
- Preferir variables de entorno o `--dart-define` para valores de configuración.
- Mantener un manejo responsable del acceso a datos y evitar exponer información sensible en logs o mensajes de error.

---

## 8. Estándar de entrega y comunicación

### 8.1. Cierre funcional
La respuesta final debe describir el resultado en lenguaje claro y orientado al usuario final, explicando:
- qué se mejoró,
- dónde quedó disponible,
- cómo impacta la operación o la experiencia,
- qué validación se ejecutó.

### 8.2. Prohibición de código en la entrega final
No se deben pegar fragmentos de código, SQL ni detalles internos del desarrollo en la respuesta final para usuarios no técnicos.

### 8.3. Trazabilidad técnica interna
Si se requiere dejar contexto técnico para un relevo, se debe documentar en un archivo de handoff o, si el proyecto lo exige, en la nota correspondiente del flujo de trabajo, sin revelar información innecesaria al usuario final.

---

## 9. Principios de estilo y calidad

- No priorizar “hacer que funcione” sobre “hacer que sea correcto”.
- Mantener una app robusta, legible y fácil de mantener.
- Usar nombres claros en variables, widgets y repositorios.
- No introducir lógica de prueba o mocks en pantallas de producción.
- Respetar la semántica de los módulos del negocio: alumnado, profesor, coordinación, administración, asistente IA, reportes y perfil.

---

## 10. Checklist operativo antes de cerrar una tarea

- [ ] He verificado la fuente real del dato o comportamiento afectado.
- [ ] He respetado la estructura feature-first del proyecto.
- [ ] No he inventado tablas, campos ni rutas.
- [ ] He utilizado el diseño y tokens correctos del proyecto.
- [ ] No he introducido secretos o credenciales.
- [ ] He ejecutado `flutter pub get`.
- [ ] He ejecutado `flutter analyze`.
- [ ] Si corresponde, he actualizado la compilación web en `docs/`.
- [ ] He verificado/actualizado el enlace de descarga del APK y la versión en Supabase (`configuracion_general`) para notificar la actualización.
- [ ] He verificado que las dependencias relevantes en `pubspec.yaml` (especialmente `firebase_core`, `firebase_auth` si aplica y plugins nativos) se mantengan en sus versiones más recientes compatibles con Flutter y Kotlin.
- [ ] He revisado que los cambios sean limpios y no mezclen trabajo ajeno.

Este protocolo debe aplicarse en cada tarea del proyecto Umbral_Immujer con rigor, criterio técnico y respeto por la arquitectura real del sistema.
