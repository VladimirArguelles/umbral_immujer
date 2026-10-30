# UMBRAL IMMUJER - Reglas de Arquitectura y Estándares de Proyecto

## 1. Clean Architecture + Feature-First
Cada módulo o característica del proyecto debe estructurarse obligatoriamente bajo el patrón Feature-First respetando las tres capas principales de Clean Architecture:

- **`data/`**: Modelos de datos (DTOs), mappers, fuentes de datos (Supabase Client, API local) e implementaciones de repositorios.
- **`domain/`**: Entidades puras de Dart/TypeScript, interfaces abstractas de repositorios y casos de uso (*UseCases*).
- **`presentation/`**: Gestores de estado (BLoCs/Cubit/Providers/Controllers), páginas/pantallas (`pages/`) y componentes visuales atómicos (`widgets/`).

---

## 2. Nomenclatura e Idioma
- Todo el código fuente (clases, funciones, variables, carpetas y archivos) debe escribirse estrictamente en **inglés**.
- Los nombres de las carpetas bajo `lib/features/` deben usar nomenclatura modular en inglés: `student`, `teacher`, `coordinator`, `auth`, `landing`.

---

## 3. Modulares Independientes y Acoplamiento
- Prohibido el acoplamiento cruzado directo entre módulos de la carpeta `features/`.
- La comunicación entre diferentes módulos debe realizarse a través de contratos en la capa `domain/` compartida o servicios centrales alojados en `lib/core/`.

---

## 4. UI/UX System (Glassmorphism & Dark Mode)
- **Fondo Principal:** `#0D0714` (Dark Violet/Black).
- **Contenedores Glassmorphic:** Superficies translúcidas con desenfoque (`BackdropFilter` con `ImageFilter.blur(sigmaX: 10, sigmaY: 10)`).
- **Acentos Neón:** Fucsia/Magenta (`#E0115F` / `#FF007F`) y Violeta neón para bordes y botones de acción principal.
- **Navbar:** Navegador flotante inferior en forma de cápsula con efecto de cristal y sombras neón.

---

## 5. Control de Calidad y Refactorización
- Archivos que superen las 250 líneas de código deben ser modularizados y divididos en sub-widgets o utilidades.
- Todo `TextEditingController` o controlador de estado debe incluir su método `dispose()` explícito para evitar fugas de memoria.
- No se permiten advertencias en `flutter analyze` ni bloques de manejo de errores vacíos.

---

## 6. REGLA OBLIGATORIA DE COMPILACIÓN Y DESPLIEGUE WEB (GitHub Pages / Docs)

1. **Ruta Objetivo de Build:** 
   Cada vez que se soliciten cambios, compilaciones o actualizaciones para la versión web del proyecto `umbral_immujer`, la salida de la compilación estática de Flutter Web (`flutter build web`) DEBE ubicarse y actualizarse dentro de la carpeta `/docs/` en la raíz del proyecto de la rama `main`.

2. **Comando de Compilación Estándar:**
   Para garantizar que la aplicación lea correctamente las rutas relativas desde la carpeta `docs` en GitHub Pages, la compilación siempre debe ejecutarse con la base href correspondiente:
   ```bash
   flutter build web --output=docs --base-href="/umbral_immujer/"