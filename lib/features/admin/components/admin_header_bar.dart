import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Encabezado del área de super admin: título, subtítulo y acciones a la
/// derecha. Sustituye al `AppBar`, que ocupa el ancho de la ventana mientras el
/// contenido va centrado y por eso no comparte eje con él.
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
            // WARN: El `Align` no es decorativo: esta Column va con
            // `crossAxisAlignment.start`, asi que sin el el `Wrap` se encoge al
            // ancho de su contenido y `WrapAlignment.end` no empuja nada.
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

/// Alto de todos los controles del encabezado, para que sus hovers midan igual
/// (el selector de tema es un cuadrado de 36 px).
const double kAdminHeaderControlHeight = 36;

/// Acción de texto del encabezado.
class AdminHeaderAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  /// `false` lo pinta en gris secundario.
  final bool isPrimary;

  /// Acción destructiva: se pinta en rojo.
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
    // `tapTargetSize.shrinkWrap` quita el relleno invisible de Material, que
    // hacia que el area pintada del hover no coincidiera con la visible.
    var style = TextButton.styleFrom(
      minimumSize: const Size(0, kAdminHeaderControlHeight),
      padding: EdgeInsets.symmetric(horizontal: t.space.sm),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: t.radius.mdBorder),
    );
    if (isDanger) {
      // Sin esto el overlay sale gris (default de Material) y el hover no se
      // lee como destructivo.
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
