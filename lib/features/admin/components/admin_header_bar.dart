import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Encabezado del área de super admin: título, subtítulo y acciones.
///
/// Sustituye al `AppBar` en esta pantalla. Motivo: el `AppBar` ocupa el ancho
/// completo de la ventana mientras el content va centrado con `max-width`, así
/// que en escritorio el título quedaba pegado al borde izquierdo y las acciones
/// al derecho, sin relación con la columna de content. Al vivir dentro del
/// mismo contenedor, todo comparte el mismo eje.
///
/// En teléfono las acciones bajan a una segunda línea con `Wrap` en vez de
/// competir por el ancho del título.
class AdminHeaderBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const AdminHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final isStacked = context.bp.isMobile;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: t.text.h2.copyWith(color: c.fg)),
        if (subtitle != null) ...[
          SizedBox(height: t.space.xxs),
          Text(subtitle!, style: t.text.bodySmall.copyWith(color: c.fgMuted)),
        ],
      ],
    );

    if (isStacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          if (actions.isNotEmpty) ...[
            SizedBox(height: t.space.sm),
            // Alineadas a la DERECHA, igual que en escritorio: ahi las
            // acciones viven al final de la fila del titulo, y en telefono
            // colgarlas a la izquierda las hacia parecer parte del subtitulo.
            //
            // `Wrap` y no `Row` con scroll: si algun dia no caben, bajan a otra
            // linea -tambien a la derecha- en vez de esconderse fuera de vista.
            // El `Align` NO es decorativo: esta Column va con
            // `crossAxisAlignment.start`, asi que sin el, el `Wrap` se encoge
            // al ancho de su contenido y `WrapAlignment.end` no tiene contra
            // que empujar -las acciones quedaban a la izquierda igual.
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: t.space.xs,
                runSpacing: t.space.xxs,
                children: actions,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleBlock),
        SizedBox(width: t.space.md),
        ...actions,
      ],
    );
  }
}

/// Alto de todos los controles del encabezado. El selector de tema es un
/// cuadrado de 36 px, así que los botones de texto se fijan al mismo alto: con el
/// alto por defecto de `TextButton` el hover quedaba visiblemente más bajo que el
/// del icono, al lado.
const double kAdminHeaderControlHeight = 36;

/// Acción de texto del encabezado. Existe para que la pantalla no repita el
/// mismo `TextButton` con su estilo de texto y su color a mano cuatro veces.
class AdminHeaderAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  /// `false` lo pinta en gris secundario (acciones que no deben competir con la
  /// principal).
  final bool isPrimary;

  /// Acción destructiva: se pinta en rojo. Para "Cerrar sesión", donde el gris
  /// no distinguía salir de la sesión de una acción secundaria cualquiera.
  final bool isDanger;

  const AdminHeaderAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final color = isDanger
        ? t.color.danger
        : (isPrimary ? t.color.primaryHover : t.color.fgMuted);
    final textStyle = t.text.label.copyWith(color: color);
    // El hover cubre exactamente el control: `minimumSize` fija el alto y
    // `tapTargetSize.shrinkWrap` quita el relleno invisible que Material añade
    // alrededor y que hacía que el area pintada no coincidiera con la visible.
    var style = TextButton.styleFrom(
      minimumSize: const Size(0, kAdminHeaderControlHeight),
      padding: EdgeInsets.symmetric(horizontal: t.space.sm),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: t.radius.mdBorder),
    );
    if (isDanger) {
      // Sin esto el overlay de una acción destructiva sale gris (el default de
      // Material) y el hover no se lee como destructivo.
      style = style.copyWith(
        overlayColor: WidgetStateProperty<Color?>.fromMap({
          WidgetState.pressed: t.color.dangerSoftStrong,
          WidgetState.hovered: t.color.dangerSoft,
          WidgetState.focused: t.color.dangerSoft,
        }),
      );
    }

    return SizedBox(
      height: kAdminHeaderControlHeight,
      child: icon == null
          ? TextButton(
              onPressed: onPressed,
              style: style,
              child: Text(label, style: textStyle),
            )
          : TextButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 18, color: color),
              label: Text(label, style: textStyle),
            ),
    );
  }
}
