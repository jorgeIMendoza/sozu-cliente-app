import 'package:flutter/material.dart';

/// Escala de radios de borde.
///
/// Los valores son los que ya usa el portal en producción (antes
/// `kPortalRadiusSm/Md/Lg/Card`) y coinciden con el tema móvil, que usaba
/// `circular(16)` = [lg] en inputs y botones.
///
/// Uso: `context.s.radius.card` o `context.s.radius.cardBorder` cuando se
/// necesita el `BorderRadius` ya construido.
@immutable
class SozuRadii {
  /// 6 — items de menú, buscador, chips chicos.
  final double sm;

  /// 8 — icon-buttons, campana de notificaciones.
  final double md;

  /// 16 — botones grandes, inputs, dropdowns.
  final double lg;

  /// 24 — todas las cards y hojas modales.
  final double card;

  /// Círculo completo: avatares, pills.
  final double full;

  const SozuRadii({
    required this.sm,
    required this.md,
    required this.lg,
    required this.card,
    required this.full,
  });

  static const SozuRadii standard = SozuRadii(
    sm: 6,
    md: 8,
    lg: 16,
    card: 24,
    full: 999,
  );

  /// Variante compacta para superficies chicas: las cards en móvil con radio 24
  /// se ven infladas cuando el ancho es de 320 px.
  static const SozuRadii compact = SozuRadii(
    sm: 6,
    md: 8,
    lg: 14,
    card: 18,
    full: 999,
  );

  BorderRadius get smBorder => BorderRadius.circular(sm);
  BorderRadius get mdBorder => BorderRadius.circular(md);
  BorderRadius get lgBorder => BorderRadius.circular(lg);
  BorderRadius get cardBorder => BorderRadius.circular(card);
  BorderRadius get fullBorder => BorderRadius.circular(full);

  static SozuRadii lerp(SozuRadii a, SozuRadii b, double t) => SozuRadii(
    sm: lerpDouble(a.sm, b.sm, t),
    md: lerpDouble(a.md, b.md, t),
    lg: lerpDouble(a.lg, b.lg, t),
    card: lerpDouble(a.card, b.card, t),
    full: lerpDouble(a.full, b.full, t),
  );
}

/// `dart:ui`'s lerpDouble devuelve nullable; aquí siempre hay ambos extremos.
double lerpDouble(double a, double b, double t) => a + (b - a) * t;
