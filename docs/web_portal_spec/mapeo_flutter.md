# Mapeo a Flutter — "modo portal" web

> Cómo traducir los specs (`tokens.md`, `shell.md`, `estado_cuenta.md`) al app Flutter
> (`apps/sozu-cliente-app`) sin romper la experiencia móvil existente.

## 1. Fuente

**El portal NO usa Inter ni Google Fonts.** Usa el system font stack
(`system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial` — index.css:644,
tailwind.config.ts:20; no hay `<link>` de fuentes en index.html).

Opciones, en orden de fidelidad:
1. **Recomendada**: NO fijar `fontFamily`; fijar solo `fontFamilyFallback:
   ['-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial']`
   en el `TextTheme` del modo portal. En Flutter web con renderer HTML/canvaskit esto acaba
   en Segoe UI (Windows) / SF (macOS), igual que el portal real.
2. Si se prefiere consistencia entre SOs: `google_fonts` con **Inter** (la métrica más
   cercana a SF/Segoe). Aceptable, pero es una desviación consciente del portal.

En cualquier caso replicar los `letter-spacing`: título −0.025em (`tracking-tight` ≈
`letterSpacing: -0.55` en 22px), labels uppercase +0.05em (≈ `0.55` en 11px), subtítulo del
sidebar +0.18em (≈ `1.8` en 10px).

## 2. Modelado de tokens (integración con lib/core/theme.dart)

`SozuTone` actual (lib/core/theme.dart) usa la paleta **móvil** (emerald500 #10B981,
slate50 #F8FAFC...). El portal web usa **otro verde y otros grises**
(#239F6D, #F9FAFB, #E5E7EB, #6B7280). **No modificar SozuTone/SozuColors** — el móvil debe
quedar intacto. Crear un archivo nuevo `lib/core/portal_theme.dart` con:

```dart
/// Tokens del Portal del Cliente web (espejo de .inmob-portal en sozu-admin).
class PortalColors {
  static const primary        = Color(0xFF239F6D); // hsl(156 64% 38%)
  static const primaryHover   = Color(0xFF1C7D56); // hsl(156 64% 30%)
  static const background     = Color(0xFFF9FAFB); // fondo contenido
  static const surface        = Color(0xFFFFFFFF); // cards, sidebar, topbar
  static const foreground     = Color(0xFF14161A); // texto principal
  static const mutedForeground= Color(0xFF6B7280); // texto secundario
  static const muted          = Color(0xFFF3F4F6); // hovers, pista progress
  static const border         = Color(0xFFE5E7EB);
  static const borderSoft     = Color(0xFFE9EEF4);
  static const warning        = Color(0xFFF59E0B);
  static const destructive    = Color(0xFFEF4444);
  // Derivados (base con alpha — usar withValues para hover/soft):
  static const primarySoft6   = Color(0xFFF2F9F6); // item activo sidebar (primary 6%)
  static const primarySoft10  = Color(0xFFE9F5F0); // chip Pagado / badge N pagos
  static const primarySoft15  = Color(0xFFDEF1E9); // chips de estado
  static const warningSoft10  = Color(0xFFFEF5E7); // chip Pendiente/Parcial
  static const warningSoft15  = Color(0xFFFEF1DA);
}
```

Exponerlo como `ThemeExtension<PortalTone>` (misma forma que `SozuTone`: primary, surface,
border, textPrimary/Secondary/Muted, warning, destructive...) y registrarlo en
`sozuLightTheme()` vía `extensions: [...]`, o simplemente `PortalTone.of(context)` estático
como hace `SozuTone.of`. El modo portal es **solo claro** (el portal web fija tokens light y
nunca aplica `.dark` dentro de `.inmob-portal`); en dark mode del dispositivo se puede seguir
mostrando el portal claro, como la web.

Radios: portal usa 6 / 8 / 16 / **24** px (cards = 24). Constantes sugeridas:
`kPortalRadiusSm=6, kPortalRadiusMd=8, kPortalRadiusLg=16, kPortalRadiusCard=24`.
Sombras: cards sin sombra (solo borde 1px); botón primario
`BoxShadow(color: Color(0x0D000000), offset: Offset(0,1), blurRadius: 2)`.

## 3. Breakpoints ("modo portal")

Espejo de Tailwind:

| Constante | px | Uso |
|---|---|---|
| `kPortalBreakpoint` | **1024** (lg) | ≥1024: shell con sidebar fija 256px + topbar 64px. <1024: layout móvil actual (drawer/bottom nav) |
| `kTwoColBreakpoint` | 768 (md) | Estado de cuenta pasa a 2 columnas `1fr + 300px` |
| `kXlBreakpoint` | 1280 (xl) | max-width de contenido 1280px centrado |

Decidir con `MediaQuery.sizeOf(context).width >= kPortalBreakpoint` en un widget raíz
(`PortalShell` decide sidebar vs experiencia móvil). Cumple el requisito de memoria:
probar Chrome ancho/angosto + iPhone Safari — el modo <1024 conserva la UI móvil ya probada.

## 4. Componentes Flutter a crear (lib/widgets/portal/)

| Widget | Replica | Notas clave |
|---|---|---|
| `PortalShell` | PortalClienteLayout | Row: sidebar 256px fija + Column(topbar 64, contenido scrollable centrado max 1280, fondo #F9FAFB, padding H 32) |
| `PortalSidebar` | Sidebar.tsx | Fondo blanco, borde der. #E5E7EB; brand (logo 24px alto + "PORTAL DEL CLIENTE" 10px ls1.8), nav, footer (avatar iniciales, Cerrar sesión rojo, versión mono 10px) |
| `PortalNavItem` | item de nav | 36px alto, radio 6, activo: fondo #F2F9F6 + texto #239F6D + barrita izq. 2px; hover #F8F9FA (MouseRegion/InkWell) |
| `PortalTopBar` | TopBar.tsx | 64px, blanco, borde inf. #E9EEF4; buscador 260×32 + campana + avatar. SIN "Ver como" (solo admin) |
| `PortalSearchField` | PortalSearchInput | Fondo muted/60, radio 6, texto 13px, overlay de resultados (OverlayPortal) radio 16 + shadow-lg |
| `PortalCard` | cards rounded-2xl | Container blanco, radio 24, borde 1px #E5E7EB, sin sombra; padding configurable (16/20) |
| `PortalCardHeader` | header px-5 py-3 | Fondo tenue opcional (#FCFDFD o #F4FAF8), borde inferior |
| `PortalPill` | pills de filtro | 11px w500, padding 10/4, radio full; activo verde sólido/blanco; inactivo borde #E5E7EB, hover borde #BDE2D3 |
| `PortalStatusChip` | chip estatus tabla | icono 12 + texto 11 w600, padding 10/4, verde soft (Pagado) / ámbar soft (Pendiente, Parcial) |
| `PortalTable` | tabla Movimientos | `Table`/`DataTable` custom: thead 11px uppercase ls0.55 #6B7280, filas hover #FCFDFD, bordes #E5E7EB; soporta fila expandible (pagos aplicados) |
| `PortalIconButton` | IconBtn | 16px icon, padding 6, radio 8, muted→primary hover, disabled 25% |
| `PortalBadgeCount` | "N pagos" / notif | radio full; verde soft 10px (pagos) o rojo sólido (notifs) |
| `PortalProgressBar` | barra Progreso | h 8, pista #F3F4F6, fill #239F6D, radio full |
| `PortalSectionLabel` | "PERÍODO"/"ESTATUS" | 11px w600 uppercase ls +0.05em #6B7280 |
| `PortalPrimaryButton` | "Descargar PDF" | 12px w600 blanco sobre #239F6D, radio 16, padding 14/10, icono 14, estados hover/pressed/disabled/loading |
| `PortalKeyValueRow` | filas resumen/STP | label muted 11-12px ↔ valor semibold (variantes mono, verde) |

Reutilizar la lógica de datos existente en `lib/providers` / `lib/data`; estos widgets son
solo presentación. Iconos: `lucide_icons` (pub) para paridad 1:1 con lucide-react
(Home, Wallet, FileText, Bell, CreditCard, BarChart2, CheckCircle2, Clock, Layers, Eye,
Receipt, Copy, Shield, Download, Search, LogOut, ChevronDown/Up/Right).

## 5. Orden de implementación sugerido

1. `portal_theme.dart` (tokens) → 2. `PortalCard`/`PortalPill`/`PortalStatusChip` (átomos) →
3. `PortalShell` + `PortalSidebar` + `PortalTopBar` → 4. Pantalla Estado de cuenta
(2 columnas + tabla) → 5. Resto de pantallas reutilizando los mismos átomos.
