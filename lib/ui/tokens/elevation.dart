import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/tokens/palette.dart';

/// Escala de sombras (equivalente a `shadow-sm/md/lg` de Tailwind).
///
/// En tema oscuro las sombras negras no se ven: la variante [dark] las reduce y
/// confía en el contraste de superficie + borde.
@immutable
class SozuElevation {
  /// Sin sombra. Cards dentro de un contenedor que ya tiene borde.
  final List<BoxShadow> flat;

  /// Elevación mínima: botones, chips presionables.
  final List<BoxShadow> sm;

  /// Cards y paneles.
  final List<BoxShadow> md;

  /// Dropdowns, popovers, hojas modales.
  final List<BoxShadow> lg;

  /// Diálogos centrados.
  final List<BoxShadow> xl;

  const SozuElevation({
    required this.flat,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  static const SozuElevation light = SozuElevation(
    flat: [],
    sm: [
      BoxShadow(color: SozuAlpha.black05, offset: Offset(0, 1), blurRadius: 2),
    ],
    md: [
      BoxShadow(color: SozuAlpha.black08, offset: Offset(0, 4), blurRadius: 12),
    ],
    lg: [
      BoxShadow(color: SozuAlpha.black10, offset: Offset(0, 8), blurRadius: 24),
    ],
    xl: [
      BoxShadow(
        color: SozuAlpha.black12,
        offset: Offset(0, 16),
        blurRadius: 48,
      ),
    ],
  );

  static const SozuElevation dark = SozuElevation(
    flat: [],
    sm: [],
    md: [
      BoxShadow(color: SozuAlpha.black45, offset: Offset(0, 4), blurRadius: 12),
    ],
    lg: [
      BoxShadow(color: SozuAlpha.black60, offset: Offset(0, 8), blurRadius: 24),
    ],
    xl: [
      BoxShadow(
        color: SozuAlpha.black60,
        offset: Offset(0, 16),
        blurRadius: 48,
      ),
    ],
  );

  static SozuElevation forBrightness(Brightness b) =>
      b == Brightness.dark ? dark : light;

  static SozuElevation lerp(SozuElevation a, SozuElevation b, double t) =>
      SozuElevation(
        flat: BoxShadow.lerpList(a.flat, b.flat, t) ?? const [],
        sm: BoxShadow.lerpList(a.sm, b.sm, t) ?? const [],
        md: BoxShadow.lerpList(a.md, b.md, t) ?? const [],
        lg: BoxShadow.lerpList(a.lg, b.lg, t) ?? const [],
        xl: BoxShadow.lerpList(a.xl, b.xl, t) ?? const [],
      );
}
