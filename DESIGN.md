# Sistema de Diseño UMBRAL - IMMUJER

Documento constitucional de diseño y guía de estilos semánticos para la aplicación móvil y web UMBRAL de IMMUJER.

---

## 1. Paleta Oficial Modo Claro (Predeterminada - `AppColors`)

Esta es la paleta cromática oficial configurada como predeterminada (`ThemeMode.light`):

### 1.1 Estructura y Superficies
| Token | Hex | Rol y Uso |
| :--- | :--- | :--- |
| `AppColors.primaryBlueStart` | `#2A3A93` | Color primario, inicio de gradientes y botones destacados. |
| `AppColors.primaryBlueEnd` | `#3E4BA6` | Fin de gradientes y contenedores primarios. |
| `AppColors.background` | `#F4F6FB` | Fondo general de vistas y Scaffold. |
| `AppColors.surfaceWhite` | `#FFFFFF` | Tarjetas, paneles elevados y contenedores modulares. |

### 1.2 Iconos y Acentos de Acceso Rápido
| Token | Hex | Rol y Uso |
| :--- | :--- | :--- |
| `AppColors.blueViolet` | `#5B4BD7` | Acento violeta y elementos interactivos secundarios. |
| `AppColors.warmOrange` | `#FFFF7A1A` | Acento cálido y llamadas secundarias. |
| `AppColors.lightBlue` | `#2B82FB` | Acento azul claro e indicadores de enlaces. |
| `AppColors.emeraldGreen` | `#10B981` | Indicadores de estado positivo, confirmación y éxito. |
| `AppColors.pinkMagenta` | `#FFFF4B72` | Notificaciones, insignias y alertas vibrantes. |
| `AppColors.goldenYellow` | `#F59E0B` | Advertencias y métricas en observación. |

### 1.3 Fondos Pasteles para Tarjetas
| Token | Hex | Rol y Uso |
| :--- | :--- | :--- |
| `AppColors.softPurple` | `#ECE9FF` | Fondo pastel de métricas y tarjetas de acceso rápido. |
| `AppColors.softOrange` | `#FFF0E5` | Fondo pastel cálido para avisos y cursos. |
| `AppColors.softBlue` | `#EBF3FF` | Fondo pastel para módulos interactivos y chips. |
| `AppColors.softMint` | `#E6F7F0` | Fondo pastel para estados completados o aprobados. |
| `AppColors.softPink` | `#FFEBF0` | Fondo pastel para avisos de atención o eventos. |
| `AppColors.softCreamYellow` | `#FEF8E7` | Fondo pastel para balances o pendientes. |

### 1.4 Tipografía y Textos
| Token | Hex | Rol y Uso |
| :--- | :--- | :--- |
| `AppColors.textDark` | `#111827` | Texto principal, títulos destacados y encabezados. |
| `AppColors.textGray` | `#6B7280` | Texto secundario, subtítulos, etiquetas y metadatos. |
| `AppColors.textPrimary` | `#4F46E5` | Enlaces interactivos y texto acentuado. |

---

## 2. Paleta Oficial Modo Oscuro (`AppTheme`)

Se mantiene intacta la paleta de alto contraste para el modo oscuro (`ThemeMode.dark`):

| Nombre del Color | Hex / Token Flutter | Rol y Uso |
| :--- | :--- | :--- |
| **Fondo profundo** | `#0F172A` (`AppTheme.anthraciteDark`) | Fondo general del Scaffold. |
| **Paneles y tarjetas** | `#1E293B` (`AppTheme.anthraciteCard`)<br>`#1D1F27` (`AppTheme.anthracite`) | Tarjetas y contenedores elevados. |
| **Verde Neón** | `#0BD984` (`AppTheme.mintNeon`) | Éxito, confirmaciones y progreso. |
| **Rosa Coral / Fucsia** | `#FF1493` (`AppTheme.coralFuchsia`) | Llamadas a la acción (CTA) y botones principales. |
| **Blanco Puro** | `#FFFFFF` (`AppTheme.pureWhite`) | Títulos principales y métricas. |
| **Gris Atenuado** | `#A1A1AA` (`AppTheme.mutedGray`) | Textos secundarios y leyendas. |

---

## 3. Consumo Dinámico Reactivo (`AppTheme`)

Las pantallas acceden a la paleta mediante los selectores dinámicos en [`lib/src/core/theme/app_theme.dart`](file:///c:/DESARROLLO%20APLICACIONES/umbral_immujer/lib/src/core/theme/app_theme.dart), garantizando adaptación automática al cambiar de tema:

```dart
// Fondos y Superficies
AppTheme.dynamicBackground          // #F4F6FB (Claro) | #0F172A (Oscuro)
AppTheme.dynamicCard                // #FFFFFF (Claro) | #1E293B (Oscuro)
AppTheme.dynamicSurfaceContainer    // #EBF3FF (Claro) | #1D1F27 (Oscuro)
AppTheme.dynamicSurfaceHigh         // #ECE9FF (Claro) | #272A32 (Oscuro)

// Tipografías
AppTheme.dynamicText                // #111827 (Claro) | #FFFFFF (Oscuro)
AppTheme.dynamicTextMuted           // #6B7280 (Claro) | #A1A1AA (Oscuro)
AppTheme.dynamicTextPrimary         // #4F46E5 (Claro) | #FF1493 (Oscuro)

// Acentos y Acciones
AppTheme.dynamicPrimary             // #2A3A93 (Claro) | #FF1493 (Oscuro)
AppTheme.dynamicSecondary           // #5B4BD7 (Claro) | #BFC6DC (Oscuro)
AppTheme.dynamicSuccess             // #10B981 (Claro) | #0BD984 (Oscuro)
AppTheme.dynamicWarning             // #F59E0B (Claro) | #F59E0B (Oscuro)
```
