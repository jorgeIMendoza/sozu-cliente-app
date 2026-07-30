import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/tokens/radii.dart' show lerpDouble;

/// Escala de espaciado (base 4).
///
/// Migración: NO se hace un barrido dedicado; cada archivo que se toque por
/// otra razón cambia sus literales por tokens. En código nuevo, si el número
/// que ibas a poner no está en esta escala, casi siempre querías el de al lado.
@immutable
class SozuSpacing {
  /// 4 - separación entre un icono y su etiqueta.
  final double xxs;

  /// 8 - separación entre elementos de una misma línea.
  final double xs;

  /// 12 - padding interno de chips y campos compactos.
  final double sm;

  /// 16 - padding estándar de card, separación entre items de lista.
  final double md;

  /// 24 - separación entre secciones, padding de card holgada.
  final double lg;

  /// 32 - gutter horizontal del contenido en escritorio.
  final double xl;

  /// 48 - separación entre bloques mayores de una página.
  final double xxl;

  const SozuSpacing({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  static const SozuSpacing standard = SozuSpacing(
    xxs: 4,
    xs: 8,
    sm: 12,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
  );

  /// En móvil el gutter y las separaciones grandes se aprietan.
  static const SozuSpacing compact = SozuSpacing(
    xxs: 4,
    xs: 8,
    sm: 12,
    md: 16,
    lg: 20,
    xl: 24,
    xxl: 32,
  );

  // Atajos para los casos más frecuentes.
  EdgeInsets get allMd => EdgeInsets.all(md);
  EdgeInsets get allLg => EdgeInsets.all(lg);
  EdgeInsets get hMd => EdgeInsets.symmetric(horizontal: md);
  EdgeInsets get hLg => EdgeInsets.symmetric(horizontal: lg);
  EdgeInsets get vMd => EdgeInsets.symmetric(vertical: md);

  /// Espacio vertical. `context.s.space.gapMd` en vez de `SizedBox(height: 16)`.
  Widget get gapXs => SizedBox(height: xs);
  Widget get gapSm => SizedBox(height: sm);
  Widget get gapMd => SizedBox(height: md);
  Widget get gapLg => SizedBox(height: lg);
  Widget get gapXl => SizedBox(height: xl);

  static SozuSpacing lerp(SozuSpacing a, SozuSpacing b, double t) =>
      SozuSpacing(
        xxs: lerpDouble(a.xxs, b.xxs, t),
        xs: lerpDouble(a.xs, b.xs, t),
        sm: lerpDouble(a.sm, b.sm, t),
        md: lerpDouble(a.md, b.md, t),
        lg: lerpDouble(a.lg, b.lg, t),
        xl: lerpDouble(a.xl, b.xl, t),
        xxl: lerpDouble(a.xxl, b.xxl, t),
      );
}
