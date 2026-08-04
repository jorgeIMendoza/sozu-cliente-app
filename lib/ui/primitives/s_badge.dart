import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';

/// Tono de la insignia, por el SIGNIFICADO del estatus que anuncia.
///
/// El nombre describe qué dice el estatus, no de qué color se pinta.
enum SBadgeTone {
  /// Pagado, completado, entregado, al día.
  positive,

  /// Pendiente, en curso, por vencer.
  pending,

  /// Vencido, cancelado, en mora, rechazado.
  negative,

  /// Sin carga semántica: tipo, categoría, conteo.
  neutral,
}

/// Tamaño de la insignia. Cambia el aire y un paso de la escala tipográfica.
enum SBadgeSize {
  /// Densa: dentro de una fila de tabla o de una card ya cargada de texto.
  sm,

  /// Por defecto: estatus de un renglón o de un encabezado.
  md,
}

/// Insignia de estatus del design system: pill de fondo teñido con el texto en
/// el color del mismo tono.
///
/// Toda la apariencia se resuelve en [_SBadgeStyle.resolve]; agregar un tono es
/// agregar un `case` ahí, sin tocar el árbol de widgets.
///
/// ```dart
/// SBadge(label: 'Pagado', tone: SBadgeTone.positive)
/// SBadge(label: 'Vencido', tone: SBadgeTone.negative,
///        icon: Icons.error_outline, size: SBadgeSize.sm)
/// ```
class SBadge extends StatelessWidget {
  /// Texto del estatus. Ya viene formateado: la insignia no traduce ni capitaliza.
  final String label;

  final SBadgeTone tone;
  final SBadgeSize size;

  /// Icono a la izquierda del texto.
  final IconData? icon;

  const SBadge({
    super.key,
    required this.label,
    this.tone = SBadgeTone.neutral,
    this.size = SBadgeSize.md,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final style = _SBadgeStyle.resolve(
      tone: tone,
      size: size,
      colors: t.color,
      theme: t,
    );

    return Container(
      padding: style.padding,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: style.radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: style.iconSize, color: style.foreground),
            SizedBox(width: style.gap),
          ],
          Text(label, style: style.textStyle.copyWith(color: style.foreground)),
        ],
      ),
    );
  }
}

/// Apariencia ya resuelta de una insignia: **el único lugar del archivo que sabe
/// de tonos**. Todos los campos son requeridos, así que un tono nuevo no puede
/// olvidarse de uno.
@immutable
class _SBadgeStyle {
  final Color background;

  /// Texto e icono.
  final Color foreground;

  final EdgeInsets padding;
  final TextStyle textStyle;
  final BorderRadius radius;
  final double iconSize;

  /// Separación entre icono y texto.
  final double gap;

  const _SBadgeStyle({
    required this.background,
    required this.foreground,
    required this.padding,
    required this.textStyle,
    required this.radius,
    required this.iconSize,
    required this.gap,
  });

  /// Traduce (tono × tamaño × roles de color) a apariencia concreta.
  ///
  /// [colors] llega aparte de [theme] para poder resolver contra un set fijo
  /// ([SozuColorRoles.light]) sin `BuildContext`.
  factory _SBadgeStyle.resolve({
    required SBadgeTone tone,
    required SBadgeSize size,
    required SozuColorRoles colors,
    required SozuTheme theme,
  }) {
    final m = _SBadgeMetrics.forSize(size, theme);
    final c = colors;

    // Cada tono usa el par (fondo teñido, color de TEXTO del semáforo): los
    // roles `*Fg` existen porque el relleno no alcanza contraste AA en 11-12 px.
    final (Color background, Color foreground) = switch (tone) {
      SBadgeTone.positive => (c.primarySoftStrong, c.primaryHover),
      SBadgeTone.pending => (c.warningSoft, c.warningFg),
      SBadgeTone.negative => (c.dangerSoft, c.danger),
      SBadgeTone.neutral => (c.surfaceAlt, c.fgMuted),
    };

    return _SBadgeStyle(
      background: background,
      foreground: foreground,
      padding: m.padding,
      textStyle: m.textStyle,
      radius: theme.radius.fullBorder,
      iconSize: m.iconSize,
      gap: m.gap,
    );
  }
}

/// Icono de la insignia. Fuera de la escala de espaciado a propósito: es un
/// tamaño de glifo, y el mismo valor sirve en los dos tamaños.
const double _iconSize = 12;

/// Medidas por tamaño.
@immutable
class _SBadgeMetrics {
  final EdgeInsets padding;
  final TextStyle textStyle;
  final double iconSize;
  final double gap;

  const _SBadgeMetrics({
    required this.padding,
    required this.textStyle,
    required this.iconSize,
    required this.gap,
  });

  factory _SBadgeMetrics.forSize(SBadgeSize size, SozuTheme t) {
    switch (size) {
      case SBadgeSize.sm:
        return _SBadgeMetrics(
          padding: EdgeInsets.symmetric(
            horizontal: t.space.xs,
            vertical: t.space.xxs,
          ),
          // `overline` ya viene en w600: es el token de chips.
          textStyle: t.text.overline,
          iconSize: _iconSize,
          gap: t.space.xxs,
        );
      case SBadgeSize.md:
        return _SBadgeMetrics(
          padding: EdgeInsets.symmetric(
            horizontal: t.space.sm,
            vertical: t.space.xxs,
          ),
          textStyle: t.text.caption.copyWith(fontWeight: FontWeight.w600),
          iconSize: _iconSize,
          gap: t.space.xxs,
        );
    }
  }
}
