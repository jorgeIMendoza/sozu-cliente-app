import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Tokens del "modo portal" web — espejo exacto del Portal del Cliente de
/// sozu-admin (bloque `.inmob-portal` de src/index.css). Fuente de verdad:
/// docs/web_portal_spec/tokens.md.
///
/// NO usa (ni modifica) SozuTone/SozuColors: la paleta móvil (emerald/slate)
/// es otra. Estos tokens aplican SOLO cuando [isPortalMode] es true.
/// El portal es siempre claro: no hay variante dark de estos colores.
class PortalColors {
  PortalColors._();

  // Base (hex resueltos de las CSS vars de .inmob-portal)
  static const Color primary = Color(0xFF239F6D); // hsl(156 64% 38%)
  static const Color primaryHover = Color(0xFF1C7D56); // hsl(156 64% 30%)
  static const Color background = Color(0xFFF9FAFB); // fondo del contenido
  static const Color surface = Color(0xFFFFFFFF); // cards, sidebar, topbar
  static const Color foreground = Color(0xFF14161A); // texto principal
  static const Color mutedForeground = Color(0xFF6B7280); // texto secundario
  static const Color muted = Color(0xFFF3F4F6); // hovers, pista de progress
  static const Color border = Color(0xFFE5E7EB); // bordes de cards/tabla
  static const Color borderSoft = Color(
    0xFFE9EEF4,
  ); // topbar, secciones sidebar
  static const Color warning = Color(0xFFF59E0B);
  static const Color destructive = Color(0xFFEF4444);
  static const Color textMuted = Color(0xFF9BA1AB); // --inmob-text-muted

  // Derivados por opacidad ya "aplanados" sobre #FFFFFF (tokens.md §1.1)
  static const Color primarySoft6 = Color(0xFFF2F9F6); // item activo sidebar
  static const Color primarySoft5 = Color(0xFFF4FAF8); // header instrucciones
  static const Color primarySoft10 = Color(0xFFE9F5F0); // chip Pagado, badges
  static const Color primarySoft15 = Color(0xFFDEF1E9); // chips de estado
  static const Color primaryBorder30 = Color(0xFFBDE2D3); // borde hover pills
  static const Color warningSoft10 = Color(0xFFFEF5E7); // chip Pendiente
  static const Color warningSoft15 = Color(0xFFFEF1DA); // chip Pago Pendiente
  static const Color destructiveSoft10 = Color(
    0xFFFDECEC,
  ); // hover Cerrar sesión
  static const Color mutedHover = Color(0xFFF8F9FA); // bg-muted/60 (hover menú)
  static const Color mutedSoft30 = Color(0xFFFBFCFC); // bg-muted/30
  static const Color mutedSoft20 = Color(0xFFFCFDFD); // bg-muted/20
}

// ---------------------------------------------------------------------------
// Medidas de layout (tokens.md §6)
// ---------------------------------------------------------------------------

/// Ancho de la sidebar fija del portal (`w-64`).
const double kPortalSidebarWidth = 256;

/// Alto de la topbar del portal (`h-16`).
const double kPortalTopBarHeight = 64;

/// Max-width del área de contenido (`xl:max-w-7xl`), centrado.
const double kPortalContentMaxWidth = 1280;

/// Padding horizontal del contenido en escritorio (`lg:px-8`).
const double kPortalContentGutter = 32;

/// Breakpoint del modo portal (Tailwind `lg`): con web ancho ≥1024 se pinta
/// el shell del portal; por debajo se conserva el layout móvil actual.
const double kPortalBreakpoint = 1024;

/// Breakpoint md (768): estado de cuenta a 2 columnas `1fr + 300px`.
const double kTwoColBreakpoint = 768;

// ---------------------------------------------------------------------------
// Radios de borde (tokens.md §3)
// ---------------------------------------------------------------------------

const double kPortalRadiusSm = 6; // rounded-md: items de menú, buscador
const double kPortalRadiusMd = 8; // rounded-lg: icon-buttons, campana
const double kPortalRadiusLg = 16; // rounded-xl: botones grandes, dropdowns
const double kPortalRadiusCard = 24; // rounded-2xl: todas las cards

// ---------------------------------------------------------------------------
// Tipografía (tokens.md §2)
// ---------------------------------------------------------------------------

/// System font stack del portal (no usa Google Fonts): no se fija fontFamily,
/// solo el fallback — en Windows acaba en Segoe UI y en macOS en SF, igual
/// que la web real.
const List<String> kPortalFontFallback = [
  '-apple-system',
  'BlinkMacSystemFont',
  'Segoe UI',
  'Roboto',
  'Helvetica Neue',
  'Arial',
  'sans-serif',
];

// ---------------------------------------------------------------------------
// Helper de modo
// ---------------------------------------------------------------------------

/// true cuando la app corre en WEB con ancho ≥ [kPortalBreakpoint]: la UI
/// debe verse exactamente como el Portal del Cliente (sidebar 256 + topbar 64).
/// En móvil/angosto (o apps nativas) siempre false: no cambia nada.
bool isPortalMode(BuildContext context) =>
    kIsWeb && MediaQuery.sizeOf(context).width >= kPortalBreakpoint;
