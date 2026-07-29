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
          const SizedBox(height: 2),
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
            Wrap(
              spacing: t.space.xs,
              runSpacing: t.space.xxs,
              children: actions,
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

/// Acción de texto del encabezado. Existe para que la pantalla no repita el
/// mismo `TextButton` con `TextStyle(fontWeight: w600, color: …)` cuatro veces.
class AdminHeaderAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  /// `false` lo pinta en gris secundario (acciones de salida como "Cerrar
  /// sesión", que no deben competir con la acción principal).
  final bool isPrimary;

  const AdminHeaderAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final color = isPrimary ? t.color.primaryHover : t.color.fgMuted;
    final estilo = t.text.label.copyWith(color: color);

    if (icon == null) {
      return TextButton(
        onPressed: onPressed,
        child: Text(label, style: estilo),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: estilo),
    );
  }
}
