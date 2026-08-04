import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Jerarquía del encabezado de sección.
///
/// Son el mismo componente y no dos: misma fila (icono · texto · trailing) y
/// mismo papel en la página; lo único que cambia es cuánto peso pide.
enum SSectionLabelVariant {
  /// Etiqueta de grupo dentro de una lista: 11 px en MAYÚSCULAS, texto sutil.
  label,

  /// Título de bloque de una pantalla: 16 px w700 en su caja original.
  heading,

  /// Misma tipografía que [label] pero SIN padding propio y ajustada al texto:
  /// para cabeceras de columna de una tabla, donde la celda ya decide el aire y
  /// la alineación. Con [label] el `Expanded` interno se comía la celda y un
  /// `Align` alrededor no alineaba nada.
  inline,
}

/// Encabezado de sección: icono opcional, texto y contenido a la derecha.
///
/// Dos variantes en un componente porque son la misma fila con distinto peso; la
/// [SSectionLabelVariant.label] separa grupos de una lista y la
/// [SSectionLabelVariant.heading] titula un bloque de la pantalla.
///
/// ```dart
/// SSectionLabel(text: 'Todos los clientes')
/// SSectionLabel.heading(text: 'Pagos', icon: Icons.payments)
/// ```
class SSectionLabel extends StatelessWidget {
  final String text;
  final IconData? icon;

  /// Contenido a la derecha (contador, acción).
  final Widget? trailing;

  final SSectionLabelVariant variant;

  const SSectionLabel({
    super.key,
    required this.text,
    this.icon,
    this.trailing,
    this.variant = SSectionLabelVariant.label,
  });

  /// Atajo legible de [SSectionLabelVariant.heading].
  const SSectionLabel.heading({
    super.key,
    required this.text,
    this.icon,
    this.trailing,
  }) : variant = SSectionLabelVariant.heading;

  /// Atajo legible de [SSectionLabelVariant.inline]. Sin `trailing`: quien
  /// compone la celda decide qué va al lado.
  const SSectionLabel.inline({super.key, required this.text, this.icon})
    : trailing = null,
      variant = SSectionLabelVariant.inline;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final style = _SSectionLabelStyle.resolve(variant: variant, theme: t);

    final label = Text(
      style.uppercase ? text.toUpperCase() : text,
      style: style.textStyle,
    );

    return Padding(
      padding: style.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // El flex se aplica solo si tiene sentido. Dos motivos distintos:
          //
          // 1. Con ancho NO acotado, cualquier flex revienta el layout
          //    ("non-zero flex but incoming width constraints are unbounded").
          //    `Flexible` no salva: su flex tambien es 1.
          // 2. La variante `inline` NUNCA expande, ni con ancho acotado: en una
          //    cabecera de tabla el `Expanded` se come la celda y el `Align` de
          //    alrededor deja de alinear.
          final expand =
              variant != SSectionLabelVariant.inline &&
              constraints.hasBoundedWidth;

          return Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: style.iconSize, color: style.iconColor),
                SizedBox(width: style.gap),
              ],
              if (expand) Expanded(child: label) else label,
              if (trailing != null) trailing!,
            ],
          );
        },
      ),
    );
  }
}

/// Apariencia ya resuelta: el único lugar del archivo que sabe de variantes.
@immutable
class _SSectionLabelStyle {
  final EdgeInsets padding;
  final double iconSize;
  final Color iconColor;
  final double gap;
  final TextStyle textStyle;
  final bool uppercase;

  const _SSectionLabelStyle({
    required this.padding,
    required this.iconSize,
    required this.iconColor,
    required this.gap,
    required this.textStyle,
    required this.uppercase,
  });

  factory _SSectionLabelStyle.resolve({
    required SSectionLabelVariant variant,
    required SozuTheme theme,
  }) {
    final c = theme.color;
    switch (variant) {
      case SSectionLabelVariant.label:
        return _SSectionLabelStyle(
          padding: EdgeInsets.only(
            top: theme.space.xxs,
            bottom: theme.space.xs,
          ),
          iconSize: 14,
          iconColor: c.fgSubtle,
          gap: theme.space.xxs + 2,
          textStyle: theme.text.overline.copyWith(color: c.fgSubtle),
          uppercase: true,
        );

      case SSectionLabelVariant.inline:
        return _SSectionLabelStyle(
          padding: EdgeInsets.zero,
          iconSize: 14,
          iconColor: c.fgSubtle,
          gap: theme.space.xxs + 2,
          textStyle: theme.text.overline.copyWith(color: c.fgSubtle),
          uppercase: true,
        );

      case SSectionLabelVariant.heading:
        return _SSectionLabelStyle(
          // Más aire arriba que abajo: el título pertenece a lo que sigue, no a
          // lo que quedó encima.
          padding: EdgeInsets.only(top: theme.space.lg, bottom: theme.space.xs),
          iconSize: 16,
          // `primary` y no `positive`: el icono es acento de marca, no un
          // indicador de éxito.
          iconColor: c.primary,
          gap: theme.space.xs,
          textStyle: theme.text.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: c.fg,
          ),
          uppercase: false,
        );
    }
  }
}
