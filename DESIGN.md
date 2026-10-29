# Sistema de Diseño UMBRAL - IMMUJER

Documento constitucional de diseño y guía de estilos semánticos para la aplicación móvil y web UMBRAL de IMMUJER.

---

## 1. Paleta de Colores Oficial

Esta es la paleta cromática mandatoria a utilizar en todas las interfaces, vistas y componentes del sistema:

| Nombre del Color | Hex / Token Flutter | Rol y Uso Exclusivo en la Interfaz |
| :--- | :--- | :--- |
| **Gris Oscuro / Antracita** | `#1D1F27` (`AppTheme.anthracite`)<br>`#191B23` (`AppTheme.surfaceContainerLow`)<br>`#10131A` (`AppTheme.background`) | **Superficies**: Contenedores, tarjetas de métricas, módulos principales, diálogos y paneles flotantes. |
| **Verde Menta / Neón** | `#4EDEA3` (`AppTheme.mintNeon` / `AppTheme.tertiary`) | **Métricas y Éxito**: Indicadores de estado positivo, gráficos de líneas, porcentajes de éxito, confirmaciones y barras de progreso. |
| **Rosa Coral / Fucsia** | `#FF516A` (`AppTheme.coralFuchsia` / `AppTheme.primaryContainer`)<br>`#FFB2B7` (`AppTheme.primary`) | **Llamada a la Acción (CTA)**: Botones primarios, estados activos, insignias de alerta, notificaciones y elementos de alta prioridad. |
| **Blanco Puro** | `#FFFFFF` (`AppTheme.pureWhite` / `AppTheme.onSurface`) | **Tipografía Principal**: Títulos principales, valores numéricos de métricas destacadas y encabezados de secciones. |
| **Gris Claro / Atenuado** | `#A1A1AA` (`AppTheme.mutedGray` / `AppTheme.onSurfaceVariant`) | **Tipografía Secundaria**: Textos secundarios, descripciones de módulos, fechas, etiquetas auxiliares y subtítulos. |

---

## 2. Definición en Código Dart (`AppTheme`)

Todos los componentes deben consumir directamente los tokens de [`lib/src/core/theme/app_theme.dart`](file:///c:/DESARROLLO%20APLICACIONES/umbral_immujer/lib/src/core/theme/app_theme.dart):

```dart
// Tokens Semánticos Canónicos:
AppTheme.anthracite       // Color de contenedores, tarjetas y módulos (#1D1F27)
AppTheme.mintNeon         // Indicadores de estado positivo, gráficos y progreso (#4EDEA3)
AppTheme.coralFuchsia     // CTA principal, botones y alertas (#FF516A)
AppTheme.pureWhite        // Títulos y valores destacados (#FFFFFF)
AppTheme.mutedGray        // Descripciones y subtítulos (#A1A1AA)

// Mapeo en Theme y ColorScheme de Material 3:
Theme.of(context).colorScheme.surfaceContainer // Gris Oscuro / Antracita
Theme.of(context).colorScheme.tertiary         // Verde Menta / Neón
Theme.of(context).colorScheme.primaryContainer // Rosa Coral / Fucsia (CTA)
Theme.of(context).colorScheme.onSurface        // Blanco Puro
Theme.of(context).colorScheme.onSurfaceVariant // Gris Claro / Atenuado
```

---

## 3. Jerarquía y Reglas de Aplicación

1. **Contenedores y Paneles**:
   - Fondo general oscuro: `AppTheme.background` (`#10131A`).
   - Módulos y tarjetas de métricas: `AppTheme.surfaceContainerLow` (`#191B23`) o `AppTheme.surfaceContainer` (`#1D1F27`).
   - Bordes sutiles: `AppTheme.outlineVariant` (`#2B2D38`).

2. **Tipografía y Legibilidad**:
   - Títulos, números grandes e indicadores clave: **Blanco Puro** (`#FFFFFF`), `FontWeight.w700` a `FontWeight.w900`.
   - Subtítulos, labels y metadatos: **Gris Claro / Atenuado** (`#A1A1AA`), `FontWeight.w400` a `FontWeight.w600`.

3. **Acciones y Notificaciones (CTA)**:
   - Botón primario de envío o confirmación: Fondo **Rosa Coral / Fucsia** (`#FF516A`), texto con contraste adecuado.
   - Puntos de notificación y badges de advertencia: **Rosa Coral / Fucsia**.

4. **Progreso y Estadísticas Positivas**:
   - Barras de asistencia, porcentajes alcanzados, métrica "Presente" y gráficos ascendentes: **Verde Menta / Neón** (`#4EDEA3`).
