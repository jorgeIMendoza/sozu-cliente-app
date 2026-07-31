import 'package:flutter/material.dart';

/// Escala de radios de borde.
///
/// Uso: `context.s.radius.sheet`, o `context.s.radius.sheetBorder` cuando se
/// necesita el `BorderRadius` ya construido.
@immutable
class SozuRadii {
  /// 6 - items de menú, buscador, chips chicos.
  final double sm;

  /// 8 - icon-buttons, campana de notificaciones.
  final double md;

  /// 16 - botones grandes, inputs, dropdowns.
  final double lg;

  /// 24 - hojas modales y dialogos. Las cards usan [lg] (16): un redondeo de 24
  /// en una card se lee agresivo, y hay 89 en la app.
  final double sheet;

  /// Círculo completo: avatares, pills.
  final double full;

  const SozuRadii({
    required this.sm,
    required this.md,
    required this.lg,
    required this.sheet,
    required this.full,
  });

  static const SozuRadii standard = SozuRadii(
    sm: 6,
    md: 8,
    lg: 16,
    sheet: 24,
    full: 999,
  );

  /// Variante compacta para superficies chicas (cards en móvil).
  static const SozuRadii compact = SozuRadii(
    sm: 6,
    md: 8,
    lg: 14,
    sheet: 18,
    full: 999,
  );

  BorderRadius get smBorder => BorderRadius.circular(sm);
  BorderRadius get mdBorder => BorderRadius.circular(md);
  BorderRadius get lgBorder => BorderRadius.circular(lg);
  BorderRadius get sheetBorder => BorderRadius.circular(sheet);
  BorderRadius get fullBorder => BorderRadius.circular(full);

  static SozuRadii lerp(SozuRadii a, SozuRadii b, double t) => SozuRadii(
    sm: lerpDouble(a.sm, b.sm, t),
    md: lerpDouble(a.md, b.md, t),
    lg: lerpDouble(a.lg, b.lg, t),
    sheet: lerpDouble(a.sheet, b.sheet, t),
    full: lerpDouble(a.full, b.full, t),
  );
}

/// `dart:ui`'s lerpDouble devuelve nullable; aquí siempre hay ambos extremos.
double lerpDouble(double a, double b, double t) => a + (b - a) * t;
