# Sistema de Diseño UMBRAL - IMMUJER

Documento constitucional de diseño y guía de estilos semánticos para la aplicación móvil y web UMBRAL de IMMUJER.

---

## 1. Paleta de Colores Oficial

Esta es la paleta cromática mandatoria a utilizar en todas las interfaces, vistas y componentes del sistema:

| Nombre del Color | Hex / Token Flutter | Rol y Uso Exclusivo en la Interfaz |
| :--- | :--- | :--- |
| **Fondo profundo** | `#0F172A` (`AppTheme.background` / `AppTheme.anthraciteDark`)<br>`#0B0E15` (`AppTheme.surfaceContainerLowest`) | **Superficies**: Fondo general de páginas y contenedores internos, list tiles y chips. |
| **Paneles y tarjetas** | `#1E293B` (`AppTheme.surfaceContainerLow`)<br>`#1D1F27` (`AppTheme.surfaceContainer`)<br>`#272A32` (`AppTheme.surfaceContainerHigh`) | **Profundidad**: Tarjetas, paneles, contenedores y elementos interactivos elevados. |
| **Verde de éxito** | `#0BD984` (`AppTheme.mintNeon` / `AppTheme.tertiary`)<br>`#10B981` (`AppTheme.tertiaryContainer`)<br>`#00A572` (`AppTheme.successGreenVariant`) | **Métricas y Éxito**: Indicadores positivos, gráficos, porcentajes, confirmaciones y progreso. |
| **Violeta** | `#8B5CF6` (`AppTheme.primary` / `AppTheme.violet`) | **Acciones**: Botones primarios, estados activos, selecciones y acentos complementarios. |
| **Blanco Puro** | `#FFFFFF` (`AppTheme.pureWhite` / `AppTheme.onSurface`) | **Tipografía Principal**: Títulos principales, valores numéricos de métricas destacadas y encabezados de secciones. |
| **Gris Claro / Atenuado** | `#A1A1AA` (`AppTheme.mutedGray` / `AppTheme.onSurfaceVariant`) | **Tipografía Secundaria**: Textos secundarios, descripciones de módulos, fechas, etiquetas auxiliares y subtítulos. |
| **Texto auxiliar** | `#B0B8CD` (`AppTheme.onSecondaryContainer`)<br>`#BFC6DC` (`AppTheme.secondary`) | **Apoyo**: Texto auxiliar y elementos secundarios. |
| **Bordes** | `#2B2D38` (`AppTheme.outlineVariant`)<br>`#334155` (`AppTheme.activeOutline`)<br>`#3F424E` (`AppTheme.outline`) | **Contornos**: Separadores sutiles y contornos activos/enfocados. |
| **Estados** | `#F59E0B` (`AppTheme.warningOrange`)<br>`#DC2626` (`AppTheme.errorRed`)<br>`#93000A` (`AppTheme.errorContainer`) | **Avisos y errores**: Alertas moderadas, errores y superficies de error. |

---

## 2. Definición en Código Dart (`AppTheme`)

Todos los componentes deben consumir directamente los tokens de [`lib/src/core/theme/app_theme.dart`](file:///c:/DESARROLLO%20APLICACIONES/umbral_immujer/lib/src/core/theme/app_theme.dart):

```dart
// Tokens Semánticos Canónicos:
AppTheme.background       // Fondo principal (#0F172A)
AppTheme.surfaceContainerLow // Tarjetas y paneles (#1E293B)
AppTheme.surfaceContainerLowest // Contenedores internos y chips (#0B0E15)
AppTheme.primary          // CTA principal (#8B5CF6)
AppTheme.primaryContainer // Estados y superficies de acento (#8B5CF6)
AppTheme.successGreen     // Indicadores positivos y progreso (#0BD984)
AppTheme.pureWhite        // Títulos y valores destacados (#FFFFFF)
AppTheme.mutedGray        // Descripciones y subtítulos (#A1A1AA)

// Mapeo en Theme y ColorScheme de Material 3:
Theme.of(context).colorScheme.surfaceContainer // Superficie de paneles (#1D1F27)
Theme.of(context).colorScheme.tertiary         // Éxito y progreso (#0BD984)
Theme.of(context).colorScheme.primary          // Violeta (#8B5CF6)
Theme.of(context).colorScheme.onSurface        // Blanco Puro
Theme.of(context).colorScheme.onSurfaceVariant // Gris Claro / Atenuado
```

---

## 3. Jerarquía y Reglas de Aplicación

1. **Contenedores y Paneles**:
   - Fondo general oscuro: `AppTheme.background` (`#0F172A`).
   - Tarjetas: `AppTheme.surfaceContainerLow` (`#1E293B`) o `AppTheme.surfaceContainer` (`#1D1F27`).
   - Contenedores internos: `AppTheme.surfaceContainerLowest` (`#0B0E15`).
   - Paneles elevados: `AppTheme.surfaceContainerHigh` (`#272A32`).
   - Bordes: `AppTheme.outlineVariant` (`#2B2D38`); enfocados: `AppTheme.activeOutline` (`#334155`) o `AppTheme.outline` (`#3F424E`).

2. **Tipografía y Legibilidad**:
   - Títulos, números grandes e indicadores clave: **Blanco Puro** (`#FFFFFF`), `FontWeight.w700` a `FontWeight.w900`.
   - Subtítulos, labels y metadatos: **Gris Claro / Atenuado** (`#A1A1AA`), `FontWeight.w400` a `FontWeight.w600`.

3. **Acciones y Notificaciones (CTA)**:
   - Botón primario de envío o confirmación: Fondo **Violeta** (`#8B5CF6`) y texto negro para conservar el contraste.
   - Estados activos, hover, puntos de notificación y selecciones: `AppTheme.primary` (`#8B5CF6`).

4. **Progreso y Estadísticas Positivas**:
   - Barras de asistencia, porcentajes alcanzados, métrica "Presente" y gráficos ascendentes: `AppTheme.successGreen` (`#0BD984`), con variantes `#10B981` y `#00A572`.
   - Advertencias: `AppTheme.warningOrange` (`#F59E0B`); errores: `AppTheme.errorRed` (`#DC2626`) y `AppTheme.errorContainer` (`#93000A`).

5. **Consistencia entre pantallas**:
   - Las páginas deben consumir los tokens de `AppTheme`; no se deben definir paletas locales.
   - El modo claro conserva sus superficies claras, pero comparte los acentos, estados y tokens semánticos del sistema.
   - Los skeleton loaders conservan sus tonos propios de shimmer para diferenciar el estado de carga.
