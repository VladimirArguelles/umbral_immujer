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

### 3.5. Gestión de dependencias y compatibilidad con Kotlin/Flutter
- **Actualización preventiva en `pubspec.yaml`:** Para evitar problemas de compilación con Kotlin a futuro, mantener actualizadas las dependencias declaradas en `pubspec.yaml` (especialmente `supabase_flutter` y plugins nativos requeridos) a sus versiones más recientes compatibles con la versión activa de Flutter, AGP y Kotlin (`android/settings.gradle.kts`).
- **Validación de compatibilidad:** Antes de integrar o actualizar plugins, verificar versiones con `flutter pub outdated` y confirmar que el análisis estático (`flutter analyze`) y las compilaciones objetivo permanecen estables.

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

## 6. Pipeline obligatorio de validación y Despliegue Dual (Web + Android OTA)

### 6.1. Verificación mínima requerida
Antes de cerrar una tarea o dejarla lista para revisión:
1. `flutter pub get`
2. `flutter analyze`
3. Si la tarea toca lógica de negocio o widgets relevantes, ejecutar tests específicos o `flutter test` cuando sea viable.

### 6.2. Regla Obligatoria de Despliegue Dual (Web + Android OTA)
Cada vez que se realicen cambios en archivos `.dart` (widgets, pantallas, estilos o lógica) o en `pubspec.yaml` y se solicite compilar o desplegar la aplicación, es obligatorio ejecutar la siguiente secuencia integral de despliegue dual:

1. **Incrementar versión (Build Number):**
   Aumentar automáticamente en `+1` el *build number* en `pubspec.yaml` (ej. pasar de `0.1.6+7` a `0.1.6+8`) para que los dispositivos móviles Android detecten la existencia de una nueva versión disponible.

2. **Compilar Web (GitHub Pages):**
   Generar la salida Web en `docs/` con las variables de entorno inyectadas:
   ```powershell
   flutter build web --release --base-href "/umbral_immujer/" --output docs --dart-define-from-file=.env
   if ($LASTEXITCODE -ne 0) { throw "Falló la compilación web." }
   ```

3. **Compilar APK Nativo (Android):**
   Compilar el APK de producción con las variables de entorno inyectadas:
   ```powershell
   flutter build apk --release --dart-define-from-file=.env
   if ($LASTEXITCODE -ne 0) { throw "Falló la compilación de Android APK." }
   ```

4. **Publicar Actualización OTA en Supabase:**
   Ejecutar el script de despliegue OTA (leyendo las credenciales administrativas desde `.env.deploy` preferentemente o `.env`):
   ```powershell
   npm --prefix scripts run deploy:ota
   if ($LASTEXITCODE -ne 0) { throw "Falló la publicación OTA a Supabase Storage y configuracion_general." }
   ```
   Este paso automatizado:
   - Sube el nuevo APK a Supabase Storage en el bucket `app-updates/app-release.apk`.
   - Genera y sube `version.json` con el hash criptográfico SHA-256 de integridad y el nuevo *build number*.
   - Sincroniza en caliente `app_version_latest` y `app_build_number` en la tabla `configuracion_general` de Supabase.

5. **Versionado Git y Publicación en `main`:**
   Revisar el estado con `git status --short` y hacer commit y push únicamente de los archivos fuente modificados, `pubspec.yaml` y la carpeta `docs/`.
   - **Regla estricta:** Verificar siempre que `.env`, `.env.deploy` y los binarios `*.apk` (incluyendo `build/`) permanezcan excluidos por `.gitignore` y jamás se incluyan en el commit.
   ```powershell
   git status --short
   git add docs/ pubspec.yaml .agents/ <rutas-fuente-modificadas>
   git commit -m "tipo(scope): descripción clara del cambio y build incrementado"
   git push origin main
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
- [ ] He ejecutado `flutter pub get`.
- [ ] He ejecutado `flutter analyze`.
- [ ] Si se modificó código `.dart` o UI, he incrementado en `+1` el *build number* en `pubspec.yaml`.
- [ ] He compilado la versión Web en `docs/` (`flutter build web --release --base-href "/umbral_immujer/" --output docs --dart-define-from-file=.env`).
- [ ] He compilado el APK de Android (`flutter build apk --release --dart-define-from-file=.env`).
- [ ] He ejecutado `npm --prefix scripts run deploy:ota` para publicar el APK en Supabase Storage, generar `version.json` con SHA-256 y sincronizar `configuracion_general`.
- [ ] He verificado que `.env`, `.env.deploy` y los binarios `*.apk` no se incluyan en el commit.
- [ ] He verificado que las dependencias relevantes en `pubspec.yaml` (especialmente `supabase_flutter` y plugins nativos) se mantengan en sus versiones más recientes compatibles con Flutter y Kotlin.
- [ ] He revisado que los cambios sean limpios y no mezclen trabajo ajeno.

Este protocolo debe aplicarse en cada tarea del proyecto Umbral_Immujer con rigor, criterio técnico y respeto por la arquitectura real del sistema.
