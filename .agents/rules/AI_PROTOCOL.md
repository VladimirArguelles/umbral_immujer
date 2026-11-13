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

### 3.7. Arquitectura de Configuración Remota y Lógica Desacoplada ("Over-The-Air" / Zero-Rebuild)
Para permitir la modificación de reglas de negocio, visibilidad de módulos, textos y parámetros visuales en tiempo real sin recompilar el cliente Flutter ni generar nuevos binarios para ajustes operativos menores, el proyecto implementa una arquitectura desacoplada "Zero-Rebuild":

- **1. Capa de Datos Remota (`supabase/migrations/`):**
  - **Tabla `app_remote_config`:** Almacena parámetros operativos y visuales bajo esquema clave-valor JSONB (`key VARCHAR PRIMARY KEY`, `value JSONB NOT NULL`, `category VARCHAR` (`'ui'`, `'business_rule'`, `'copy'`, `'general'`), `description TEXT`, `updated_at TIMESTAMPTZ` con trigger).
    - *Valores estándar:* Paleta institucional dinámica (`primary_color`, `background_color`, `card_background`, `accent_color`), métricas de glassmorphism (`glassmorphism_blur`, `glassmorphism_opacity`), textos y alertas (`welcome_title`, `welcome_subtitle`, `landing_headline`, `maintenance_banner`) y límites operativos (`max_students_per_course`, `require_dni_verification`, `default_practical_contribution_usd`).
  - **Tabla `feature_flags`:** Controla la activación o desactivación de módulos al vuelo (`flag_key VARCHAR PRIMARY KEY`, `is_enabled BOOLEAN DEFAULT true`, `target_roles TEXT[] DEFAULT ARRAY['todos']`, `description TEXT`, `updated_at TIMESTAMPTZ`).
    - *Flags canónicos:* `enable_pdf_importer`, `enable_bcv_sync_banner`, `enable_surveys`, `enable_asistencia_bluetooth`, `enable_export_excel`, `enable_umby_floating_assistant`, `enable_auto_enrollment_verification`.
  - **Políticas RLS:** Políticas `SELECT` abiertas al rol `public` (permitiendo precargar el tema visual y textos en la landing antes de autenticar), y políticas de mutación (`INSERT`, `UPDATE`, `DELETE`) estrictamente restringidas a administradores (`super_admin`).
  - **Lógica de Negocio Encapsulada en PostgreSQL (RPCs):** Las validaciones críticas de negocio (cupos de admisión, duplicidad de cédula, períodos lectivos) deben ejecutarse en funciones SQL (ej. `validar_inscripcion_alumna`) para poder ajustar políticas operativas directamente en base de datos sin tocar el código fuente del cliente.
  - **Suscripción Realtime:** Ambas tablas deben estar suscritas a la publicación `supabase_realtime` para emitir eventos `INSERT`, `UPDATE` y `DELETE` instantáneos a los clientes.

- **2. Servicio Reactivo en Flutter (`lib/core/config/remote_config_service.dart`):**
  - Implementado como `ChangeNotifier` Singleton accesible mediante `RemoteConfigService.instance`.
  - **Caché y Resiliencia Offline:** Al iniciar, precarga inmediatamente los valores persistidos en `SharedPreferences` para garantizar un arranque instantáneo a 120 FPS sin pantallas blancas ni parpadeos.
  - **Sincronización en Tiempo Real:** Escucha eventos de `supabase_realtime` en el canal `umbral_remote_config_channel`. Al recibir un cambio, actualiza la memoria, persiste en disco y emite `notifyListeners()`.
  - **Helpers Tipados:** Métodos de acceso seguros con fallback obligatorio: `isFeatureEnabled(flagKey, {userRole})`, `getRemoteColor(key, fallback)`, `getConfigValue<T>(key, fallback)`, `getRemoteString`, `getRemoteInt`, `getRemoteDouble`, `getRemoteBool`.

- **3. Desacoplamiento Visual y Componentes Reactivos:**
  - **Tema Dinámico Glassmorphic:** `MaterialApp.router` en `main.dart` se vincula reactivamente a `RemoteConfigService.instance` y `ThemeController.themeMode` usando `Listenable.merge`.
  - **Tokens Reactivos:** `AppTheme` y `AppColors` deben consumir getters dinámicos (`dynamicPrimary`, `dynamicAccent`, `glassmorphicBlur`, `glassmorphicOpacity`) que consultan el servicio remoto.
  - **Widget Wrapper `<FeatureGate>` (`lib/src/core/widgets/feature_gate.dart`):** Todo botón, banner o sección condicional debe envolverse con `<FeatureGate>` para permitir encenderlo u ocultarlo al vuelo desde la base de datos sin tocar el código.

- **4. Estrategia Web Anti-Caché ("Zero-Stale Web"):**
  - En `web/index.html`, la carga de `flutter_bootstrap.js` debe utilizar cache-busting dinámico con marca temporal (`script.src = 'flutter_bootstrap.js?t=' + Date.now()`) para garantizar que al desplegar versiones mayores en `/docs/`, los navegadores web y PWAs descarguen siempre los nuevos assets sin quedarse atrapados en caché antigua.

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

### 6.4. Política Estricta de Versión Binaria vs Arquitectura Remota Zero-Rebuild (REGLA DE OBLIGATORIO CUMPLIMIENTO)
Queda establecida como **regla inquebrantable de obligatorio cumplimiento** la estricta separación entre modificaciones de interfaz/diseño y liberaciones de binarios nativos:

1. **PROHIBICIÓN ESTRICTA DE BUMP DE VERSIÓN PARA DISEÑO Y UI:**
   - Para cambios de interfaz de usuario, diseño de widgets, tamaños de texto, ajustes de contenedores, desbordamientos, colores, estilos visuales, copys o parámetros de negocio: **QUEDA ESTRICTAMENTE PROHIBIDO incrementar la versión o número de compilación en `pubspec.yaml` y en la tabla Supabase `configuracion_general` (`app_version_latest` / `app_build_number`).**
   - Dichas modificaciones deben gestionarse de forma 100% remota ("Zero-Rebuild") a través de `RemoteConfigService`, `<FeatureGate>`, funciones RPC en PostgreSQL y la actualización continua de la versión Web en `docs/`.
   - **NUNCA** forzar al usuario a descargar e instalar paquetes APK de 68 MB por ajustes visuales o de diseño, previniendo diálogos intrusivos y bucles de actualización en dispositivos móviles.

2. **ÚNICAS EXCEPCIONES PARA INCREMENTO DE VERSIÓN BINARIA:**
   - El incremento de versión en `pubspec.yaml` y actualización en `configuracion_general` (`app_version_latest`, `app_build_number`, `app_apk_url`, `app_update_notes`) se reserva **exclusivamente** para:
     a) Modificaciones nativas en el código de plataforma Android/iOS (ej. Gradle, Kotlin, AndroidManifest, Info.plist).
     b) Incorporación de plugins nativos de Flutter que requieran recompilación binaria obligatoria.
     c) Cuando el usuario humano lo solicite explícitamente por escrito.

3. **Control y Persistencia de Sesión del Modal de Actualización:**
   - Si una versión binaria legítima está disponible pero no es mandatoria (`app_update_mandatory = false`), el modal debe ofrecer siempre la opción de "Recordarme más tarde" y respetar el descarte de sesión sin interrumpir la experiencia de navegación del usuario.

### 6.5. Control de versión y staging
- Hacer `git add` solo de las rutas modificadas y relevantes para la tarea.
- No hacer stage global ni sobrescribir cambios ajenos.
- Si hay cambios no relacionados en el repositorio, no tocarlos ni mezclarlos.

### 6.6. Protocolo y Secuencia de Pasos para Implementaciones y Ajustes Remotos (Zero-Rebuild)
Siempre que se trabaje en la implementación, integración o ajuste de parámetros remotos, feature flags o lógica desacoplada, la IA debe seguir obligatoriamente esta secuencia de 7 pasos:

1. **Paso 1: Auditoría de Fuentes de Verdad y Estado del Proyecto:**
   - Inspeccionar `pubspec.yaml`, `lib/main.dart`, `lib/src/core/theme/app_theme.dart`, `lib/src/core/theme/app_colors.dart`, `web/index.html` y las últimas migraciones en `supabase/migrations/`.
   - Confirmar si las tablas `app_remote_config` y `feature_flags` ya existen antes de recrearlas y validar las dependencias instaladas (`shared_preferences`, `supabase_flutter`).
2. **Paso 2: Generación y Aplicación de Migración SQL Versionada:**
   - Crear el archivo de migración en `supabase/migrations/` con timestamp secuencial (`YYYYMMDDHHMMSS_*.sql`).
   - Implementar `app_remote_config` y `feature_flags` con claves primarias, columnas auditables (`updated_at` con trigger) y restricciones de categoría.
   - Definir políticas RLS rigurosas: `SELECT` pública/autenticada y mutaciones (`INSERT`, `UPDATE`, `DELETE`) restringidas a `super_admin`.
   - Encapsular validaciones críticas de negocio en funciones RPC de PostgreSQL (`validar_inscripcion_alumna`, `obtener_bundle_configuracion_remota`) para poder alterar límites o reglas sin modificar código Dart.
   - Suscribir las tablas a la publicación `supabase_realtime` (`ALTER PUBLICATION supabase_realtime ADD TABLE ...`).
3. **Paso 3: Servicio de Sincronización Reactiva (`RemoteConfigService`):**
   - Centralizar la lógica en `lib/core/config/remote_config_service.dart` como `ChangeNotifier` Singleton.
   - Cargar primero desde `SharedPreferences` para arranque instantáneo a 120 FPS sin parpadeos, y luego sincronizar con Supabase en segundo plano.
   - Suscribirse a cambios en tiempo real vía `supabase_realtime` en el canal `umbral_remote_config_channel` y emitir `notifyListeners()`.
   - Implementar helpers tipados y seguros con fallback: `isFeatureEnabled`, `getRemoteColor`, `getConfigValue<T>`, `getRemoteString`, `getRemoteInt`, `getRemoteDouble`, `getRemoteBool`.
4. **Paso 4: Desacoplamiento de Widgets y Tema Dinámico:**
   - Conectar `main.dart` mediante `Listenable.merge([ThemeController.themeMode, RemoteConfigService.instance])`.
   - Conectar `AppTheme` y `AppColors` a los getters reactivos (`dynamicPrimary`, `dynamicAccent`, `glassmorphicBlur`, `glassmorphicOpacity`).
   - Envolver componentes condicionales con el widget reutilizable `FeatureGate(flagKey: '...', child: ..., fallback: ...)` (ej. asistente flotante Umby, banners de tasa cambiaria, importadores).
   - Vincular copys de interfaz y banners de mantenimiento a claves de configuración (`maintenance_banner`, `welcome_title`).
5. **Paso 5: Estrategia Web Anti-Caché ("Zero-Stale Web"):**
   - Configurar en `web/index.html` el loader dinámico con marca temporal (`script.src = 'flutter_bootstrap.js?t=' + Date.now()`) para garantizar que al desplegar versiones mayores en `/docs/`, los navegadores web y PWAs descarguen los nuevos assets sin quedarse atrapados en caché antigua.
6. **Paso 6: Verificación de Calidad Estricta (QA Pipeline):**
   - Ejecutar `flutter analyze` y asegurar cero errores y cero advertencias antes de proceder.
   - Probar la resiliencia offline del servicio y la evaluación correcta de los fallbacks tipados.
7. **Paso 7: Documentación y Guía Operativa de Administración en Vivo (SQL):**
   - Proporcionar las sentencias SQL limpias para que los administradores alteren en vivo la aplicación desde el SQL Editor de Supabase:
     ```sql
     -- Cambiar color primario al vuelo
     UPDATE public.app_remote_config SET value = '"#E0115F"'::jsonb WHERE key = 'primary_color';
     -- Activar/desactivar un módulo al vuelo
     UPDATE public.feature_flags SET is_enabled = false WHERE flag_key = 'enable_umby_floating_assistant';
     -- Mostrar banner de mantenimiento global
     UPDATE public.app_remote_config SET value = '"⚠️ Plataforma en mantenimiento."'::jsonb WHERE key = 'maintenance_banner';
     -- Modificar regla de negocio (ej. cupos máximos por curso)
     UPDATE public.app_remote_config SET value = '40'::jsonb WHERE key = 'max_students_per_course';
     ```

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
- [ ] Si la tarea involucra parámetros de UI, flags o reglas de negocio, he aplicado la arquitectura remota desacoplada (`app_remote_config`, `feature_flags`, `FeatureGate` o RPCs) con fallbacks tipados y resiliencia offline.
- [ ] He ejecutado `flutter pub get`.
- [ ] He ejecutado `flutter analyze`.
- [ ] Si corresponde, he actualizado la compilación web en `docs/` con la estrategia anti-caché.
- [ ] He verificado/actualizado el enlace de descarga del APK y la versión en Supabase (`configuracion_general`) para notificar la actualización.
- [ ] He verificado que las dependencias relevantes en `pubspec.yaml` (especialmente `firebase_core`, `firebase_auth` si aplica y plugins nativos) se mantengan en sus versiones más recientes compatibles con Flutter y Kotlin.
- [ ] He revisado que los cambios sean limpios y no mezclen trabajo ajeno.

Este protocolo debe aplicarse en cada tarea del proyecto Umbral_Immujer con rigor, criterio técnico y respeto por la arquitectura real del sistema.
