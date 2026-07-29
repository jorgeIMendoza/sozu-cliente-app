import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/tokens/palette.dart';

/// Roles semánticos de color: la ÚNICA superficie de color que debe tocar una
/// pantalla.
///
/// Un rol describe *para qué sirve* el color, no *qué color es*. Eso es lo que
/// permite tener claro/oscuro, y lo que evita que la paleta se bifurque: antes
/// existían `SozuTone` (móvil, rampa slate) y `PortalColors` (web, rampa gray)
/// modelando exactamente los mismos roles con hex distintos.
///
/// Uso: `context.s.color.fgMuted` - ver `ui/theme/sozu_theme.dart`.
///
/// Reglas al agregar un rol:
/// 1. Debe tener valor en claro Y oscuro. Si solo aplica a uno, no es un rol.
/// 2. Debe tener un nombre de *función* (`border`, `fgMuted`), no de apariencia
///    (`gris200`, `verdeClaro`).
/// 3. Los valores salen de [SozuNeutral] / [SozuBrand] / etc. Nunca un `Color(0x…)`
///    literal aquí.
@immutable
class SozuColorRoles {
  // --- Superficies ---------------------------------------------------------

  /// Fondo de la página (detrás de las cards).
  final Color background;

  /// Fondo de cards, sidebar, topbar, hojas modales.
  final Color surface;

  /// Superficie de un nivel más: hover de menú, filas alternas, campos de texto.
  final Color surfaceAlt;

  /// Relleno inerte: pista de barras de progreso, chips neutros, placeholders.
  final Color muted;

  /// Scrim detrás de diálogos y hojas modales.
  final Color overlay;

  // --- Bordes --------------------------------------------------------------

  /// Borde estándar: cards, tablas, inputs.
  final Color border;

  /// Borde de menor peso: separadores de topbar y secciones de sidebar.
  final Color borderSoft;

  // --- Texto e iconos ------------------------------------------------------

  /// Texto principal, títulos, cifras.
  final Color fg;

  /// Texto secundario, etiquetas, descripciones. El rol más usado de la app.
  final Color fgMuted;

  /// Texto terciario: metadatos, placeholders, estados deshabilitados.
  final Color fgSubtle;

  /// Contenido sobre un fondo [primary] (texto de botón primario).
  final Color onPrimary;

  // --- Marca ---------------------------------------------------------------

  /// Color de marca: acción principal, elementos activos, énfasis.
  final Color primary;

  /// [primary] en hover (web) o en estado presionado suave.
  final Color primaryHover;

  /// [primary] al presionar / mantener.
  final Color primaryPressed;

  /// Tinte de marca de bajo contraste: fondo de item activo, headers de sección.
  final Color primarySoft;

  /// Tinte de marca de contraste medio: chips de estado, badges.
  final Color primarySoftStrong;

  /// Borde teñido de marca: contorno de pills en hover, cards seleccionadas.
  final Color primaryBorder;

  // --- Semáforo ------------------------------------------------------------

  /// Éxito, completado, pagado. Distinto de [primary] a propósito: "pagado" y
  /// "acción de marca" son semánticas separadas (ADR §6.4).
  final Color positive;

  /// Pendiente, por vencer, requiere atención. Para RELLENOS (barras, puntos).
  final Color warning;

  /// [warning] para TEXTO e iconos. [warning] sobre fondo claro da 2.1:1 de
  /// contraste, por debajo de AA; este da 4.6:1. Es un rol aparte y no un
  /// capricho: es el que hace legible "Pago pendiente".
  final Color warningFg;

  /// Fondo de chip [warning].
  final Color warningSoft;

  /// Fondo de chip [warning] de mayor énfasis.
  final Color warningSoftStrong;

  /// Error, vencido, acción destructiva.
  final Color danger;

  /// Fondo de chip [danger] / hover de "Cerrar sesión".
  final Color dangerSoft;

  /// Fondo de chip [danger] de mayor énfasis.
  final Color dangerSoftStrong;

  /// Informativo: cintillos, notas, estados que no son error ni advertencia.
  final Color info;

  /// [info] para TEXTO e iconos sobre [infoSoft].
  final Color infoFg;

  /// Fondo informativo (cintillo de entorno de pruebas, notas).
  final Color infoSoft;

  /// Borde / realce del bloque informativo.
  final Color infoSoftStrong;

  // --- Carga ---------------------------------------------------------------

  /// Base del shimmer de skeleton.
  final Color skeletonBase;

  /// Banda brillante que recorre el shimmer.
  final Color skeletonHighlight;

  const SozuColorRoles({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.muted,
    required this.overlay,
    required this.border,
    required this.borderSoft,
    required this.fg,
    required this.fgMuted,
    required this.fgSubtle,
    required this.onPrimary,
    required this.primary,
    required this.primaryHover,
    required this.primaryPressed,
    required this.primarySoft,
    required this.primarySoftStrong,
    required this.primaryBorder,
    required this.positive,
    required this.warning,
    required this.warningFg,
    required this.warningSoft,
    required this.warningSoftStrong,
    required this.danger,
    required this.dangerSoft,
    required this.dangerSoftStrong,
    required this.info,
    required this.infoFg,
    required this.infoSoft,
    required this.infoSoftStrong,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  /// Tema claro. Valores tomados del Portal del Cliente en producción.
  static const SozuColorRoles light = SozuColorRoles(
    background: SozuNeutral.n50,
    surface: SozuNeutral.n0,
    surfaceAlt: SozuNeutral.n75,
    muted: SozuNeutral.n100,
    overlay: SozuAlpha.black45,
    border: SozuNeutral.n200,
    borderSoft: SozuNeutral.n150,
    fg: SozuNeutral.n900,
    fgMuted: SozuNeutral.n500,
    fgSubtle: SozuNeutral.n400,
    onPrimary: SozuNeutral.n0,
    primary: SozuBrand.green,
    primaryHover: SozuBrand.green600,
    primaryPressed: SozuBrand.green700,
    primarySoft: SozuBrand.soft06,
    primarySoftStrong: SozuBrand.soft10,
    primaryBorder: SozuBrand.border30,
    positive: SozuBrand.green600,
    warning: SozuAmber.base,
    warningFg: SozuAmber.strong,
    warningSoft: SozuAmber.soft,
    warningSoftStrong: SozuAmber.softStrong,
    danger: SozuRed.base,
    dangerSoft: SozuRed.soft,
    dangerSoftStrong: SozuRed.softStrong,
    info: SozuBlue.base,
    infoFg: SozuBlue.strong,
    infoSoft: SozuBlue.soft,
    infoSoftStrong: SozuBlue.softStrong,
    skeletonBase: SozuNeutral.n100,
    skeletonHighlight: SozuNeutral.n0,
  );

  /// Tema oscuro. Los neutros son propuesta pendiente de diseño (ADR §10.3);
  /// los de marca y semáforo sí están medidos (rampa existente + realces).
  static const SozuColorRoles dark = SozuColorRoles(
    background: SozuNeutralDark.n50,
    surface: SozuNeutralDark.n0,
    surfaceAlt: SozuNeutralDark.n75,
    muted: SozuNeutralDark.n100,
    overlay: SozuAlpha.black60,
    border: SozuNeutralDark.n200,
    borderSoft: SozuNeutralDark.n150,
    fg: SozuNeutralDark.n900,
    fgMuted: SozuNeutralDark.n500,
    fgSubtle: SozuNeutralDark.n400,
    onPrimary: SozuNeutral.n0,
    primary: SozuBrand.green,
    // En oscuro el hover ACLARA en vez de oscurecer: sobre #1A1D21 un verde más
    // oscuro se pierde contra el fondo.
    primaryHover: SozuBrand.green400,
    primaryPressed: SozuBrand.green600,
    primarySoft: SozuBrand.softDark,
    primarySoftStrong: SozuBrand.softDarkStrong,
    primaryBorder: SozuBrand.borderDark,
    positive: SozuBrand.green400,
    warning: SozuAmber.onDark,
    // En oscuro el problema se invierte: el ámbar oscuro desaparece contra el
    // fondo, así que el texto usa el realce claro.
    warningFg: SozuAmber.onDark,
    warningSoft: SozuAmber.softDark,
    warningSoftStrong: SozuAmber.softDarkStrong,
    danger: SozuRed.onDark,
    dangerSoft: SozuRed.softDark,
    dangerSoftStrong: SozuRed.softDarkStrong,
    info: SozuBlue.onDark,
    infoFg: SozuBlue.onDark,
    infoSoft: SozuBlue.softDark,
    infoSoftStrong: SozuBlue.softDarkStrong,
    skeletonBase: SozuNeutralDark.n100,
    skeletonHighlight: SozuNeutralDark.n300,
  );

  static SozuColorRoles forBrightness(Brightness b) =>
      b == Brightness.dark ? dark : light;

  /// Interpolación rol por rol, para que el cambio claro↔oscuro anime en vez de
  /// saltar. Lo consume `SozuTheme.lerp`.
  static SozuColorRoles lerp(SozuColorRoles a, SozuColorRoles b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return SozuColorRoles(
      background: c(a.background, b.background),
      surface: c(a.surface, b.surface),
      surfaceAlt: c(a.surfaceAlt, b.surfaceAlt),
      muted: c(a.muted, b.muted),
      overlay: c(a.overlay, b.overlay),
      border: c(a.border, b.border),
      borderSoft: c(a.borderSoft, b.borderSoft),
      fg: c(a.fg, b.fg),
      fgMuted: c(a.fgMuted, b.fgMuted),
      fgSubtle: c(a.fgSubtle, b.fgSubtle),
      onPrimary: c(a.onPrimary, b.onPrimary),
      primary: c(a.primary, b.primary),
      primaryHover: c(a.primaryHover, b.primaryHover),
      primaryPressed: c(a.primaryPressed, b.primaryPressed),
      primarySoft: c(a.primarySoft, b.primarySoft),
      primarySoftStrong: c(a.primarySoftStrong, b.primarySoftStrong),
      primaryBorder: c(a.primaryBorder, b.primaryBorder),
      positive: c(a.positive, b.positive),
      warning: c(a.warning, b.warning),
      warningFg: c(a.warningFg, b.warningFg),
      warningSoft: c(a.warningSoft, b.warningSoft),
      warningSoftStrong: c(a.warningSoftStrong, b.warningSoftStrong),
      danger: c(a.danger, b.danger),
      dangerSoft: c(a.dangerSoft, b.dangerSoft),
      dangerSoftStrong: c(a.dangerSoftStrong, b.dangerSoftStrong),
      info: c(a.info, b.info),
      infoFg: c(a.infoFg, b.infoFg),
      infoSoft: c(a.infoSoft, b.infoSoft),
      infoSoftStrong: c(a.infoSoftStrong, b.infoSoftStrong),
      skeletonBase: c(a.skeletonBase, b.skeletonBase),
      skeletonHighlight: c(a.skeletonHighlight, b.skeletonHighlight),
    );
  }
}
