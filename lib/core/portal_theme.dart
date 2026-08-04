/// SHIM DE COMPATIBILIDAD - `PortalColors` está deprecado.
///
/// Era la mitad "web" de la paleta bifurcada. Sus 749 referencias siguen
/// funcionando, pero cada constante ahora apunta a la rampa unificada de
/// `lib/ui/tokens/palette.dart`.
///
/// Se mantienen como `const` (no como campos de rol) porque hay 20 usos dentro
/// de expresiones `const` que dejarían de compilar si esto fuera una lectura de
/// instancia.
///
/// **Migración de cada constante a su rol:**
///
/// | `PortalColors.…`   | usos | → `context.s.color.…`   |
/// |--------------------|------|-------------------------|
/// | `mutedForeground`  | 230  | `fgMuted`               |
/// | `primary`          | 149  | `primary`               |
/// | `border`           |  76  | `border`                |
/// | `surface`          |  33  | `surface`               |
/// | `warning`          |  32  | `warning` / `warningFg` |
/// | `foreground`       |  31  | `fg`                    |
/// | `primarySoft10`    |  25  | `primarySoftStrong`     |
/// | `muted`            |  23  | `muted`                 |
/// | `borderSoft`       |  21  | `borderSoft`            |
/// | `destructive`      |  18  | `danger`                |
/// | `primaryBorder30`  |  16  | `primaryBorder`         |
/// | `mutedHover`       |  14  | `surfaceAlt`            |
/// | `warningSoft10`    |  12  | `warningSoft`           |
/// | `primarySoft15`    |  12  | `primarySoftStrong`     |
/// | `mutedSoft20/30`   |  16  | `surface`               |
/// | `destructiveSoft10`|   9  | `dangerSoft`            |
/// | `warningSoft15`    |   7  | `warningSoftStrong`     |
/// | `primarySoft5/6`   |  10  | `primarySoft`           |
/// | `textMuted`        |   4  | `fgSubtle`              |
/// | `primaryHover`     |   6  | `primaryHover`          |
/// | `background`       |   3  | `background`            |
/// | `destructiveSoft15`|   1  | `dangerSoftStrong`      |
///
/// La escalera de tintes se colapsó: `soft5`+`soft6` → `primarySoft`,
/// `soft10`+`soft15` → `primarySoftStrong`. Cuatro niveles con 3% de diferencia
/// entre sí no son distinguibles y solo generaban decisiones arbitrarias
/// (ADR §6.3). Igual `mutedSoft20/30` (#FCFDFD/#FBFCFC), indistinguibles de
/// `surface`.
///
/// Código nuevo: `import 'package:sozu_cliente_app/ui/ui.dart';` y `context.s.color.…`.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Tokens del "modo portal" web.
///
/// Ya NO es una paleta aparte: cada constante reenvía a la rampa unificada. El
/// portal sigue siendo light-only, así que todas apuntan a los valores claros.
@Deprecated('Usar context.s.color.<rol>. Ver la tabla de arriba.')
class PortalColors {
  PortalColors._();

  // Base
  static const Color primary = SozuBrand.green;
  static const Color primaryHover = SozuBrand.green600;
  static const Color background = SozuNeutral.n50;
  static const Color surface = SozuNeutral.n0;
  static const Color foreground = SozuNeutral.n900;
  static const Color mutedForeground = SozuNeutral.n500;
  static const Color muted = SozuNeutral.n100;
  static const Color border = SozuNeutral.n200;
  static const Color borderSoft = SozuNeutral.n150;
  static const Color warning = SozuAmber.base;
  static const Color destructive = SozuRed.base;
  static const Color textMuted = SozuNeutral.n400;

  // Tintes de marca. `soft5`/`soft6` colapsan en uno; `soft10`/`soft15` en otro.
  static const Color primarySoft6 = SozuBrand.soft06;
  static const Color primarySoft5 = SozuBrand.soft06;
  static const Color primarySoft10 = SozuBrand.soft10;
  static const Color primarySoft15 = SozuBrand.soft10;
  static const Color primaryBorder30 = SozuBrand.border30;

  // Semáforo
  static const Color warningSoft10 = SozuAmber.soft;
  static const Color warningSoft15 = SozuAmber.softStrong;
  static const Color destructiveSoft10 = SozuRed.soft;
  static const Color destructiveSoft15 = SozuRed.softStrong;

  // Superficies sutiles. Las tres colapsan: eran #F8F9FA / #FBFCFC / #FCFDFD.
  static const Color mutedHover = SozuNeutral.n75;
  static const Color mutedSoft30 = SozuNeutral.n25;
  static const Color mutedSoft20 = SozuNeutral.n25;
}

// ---------------------------------------------------------------------------
// Medidas de layout - reenvían a ui/theme/breakpoints.dart
// ---------------------------------------------------------------------------

/// Ancho de la sidebar fija del portal (`w-64`).
const double kPortalSidebarWidth = kSozuSidebarWidth;

/// Alto de la topbar del portal (`h-16`).
const double kPortalTopBarHeight = kSozuTopBarHeight;

/// Max-width del área de contenido (`xl:max-w-7xl`), centrado.
const double kPortalContentMaxWidth = kSozuContentMaxWidth;

/// Padding horizontal del contenido en escritorio (`lg:px-8`).
const double kPortalContentGutter = 32;

/// Breakpoint del modo portal (Tailwind `lg`).
const double kPortalBreakpoint = kSozuDesktopMin;

/// Breakpoint md (768): estado de cuenta a 2 columnas `1fr + 300px`.
const double kTwoColBreakpoint = kSozuTabletMin;

// ---------------------------------------------------------------------------
// Radios - reenvían a SozuRadii.standard
// ---------------------------------------------------------------------------

const double kPortalRadiusSm = 6; // rounded-md
const double kPortalRadiusMd = 8; // rounded-lg
const double kPortalRadiusLg = 16; // rounded-xl
const double kPortalRadiusCard = 24; // rounded-2xl

// ---------------------------------------------------------------------------
// Tipografía
// ---------------------------------------------------------------------------

/// DEPRECADO y sin efecto: lista vacía.
///
/// Pedía fuentes del sistema (`-apple-system`, `Segoe UI`) como fallback, pero
/// ninguno de sus 19 usos fija `fontFamily`, así que todos heredaban `Inter` del
/// `ThemeData` y el fallback nunca se consultaba. Además en web CanvasKit
/// rasteriza el texto él mismo y solo reconoce las familias declaradas en
/// `pubspec.yaml`: pedir `Segoe UI` ahí es código muerto por diseño.
///
/// Se deja como lista vacía en vez de borrarse para no tocar 19 archivos en el
/// mismo commit que los tokens. Efecto visual: ninguno.
@Deprecated('Sin efecto. Borrar el parámetro fontFamilyFallback en la llamada.')
const List<String> kPortalFontFallback = <String>[];

// ---------------------------------------------------------------------------
// Helper de modo
// ---------------------------------------------------------------------------

/// true cuando la app corre en WEB con ancho ≥ [kPortalBreakpoint].
///
/// **Deprecado en favor de `context.bp.hasSidebar` / `context.responsive(…)`.**
/// Se conserva con el comportamiento EXACTO de antes (incluido el `kIsWeb`, que
/// es su defecto: una tablet Android ancha no recibe el layout ancho) para que
/// las 25 pantallas que lo usan no cambien al introducir los tokens. La
/// corrección va en la fase del shell adaptativo, no aquí.
@Deprecated('Usar context.bp.hasSidebar o context.responsive(...).')
bool isPortalMode(BuildContext context) =>
    kIsWeb && MediaQuery.sizeOf(context).width >= kPortalBreakpoint;
