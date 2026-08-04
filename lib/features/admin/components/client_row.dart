import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Diámetro del avatar de la fila. Público porque el skeleton de la lista lo
/// replica: si divergen, la lista brinca al terminar de cargar.
const double kClientRowAvatarSize = 36;

/// Fila de cliente del selector de super admin: nombre, correo y estado.
///
/// Componente **tonto**: recibe el dato, si está isSelected y qué hacer al
/// tocar. No lee providers ni navega - eso lo decide la pantalla. Así se puede
/// montar en un test o en otra vista sin arrastrar Riverpod.
class ClientRow extends StatelessWidget {
  final AdminCliente client;

  /// El cliente que el admin está viendo ahora mismo (impersonado).
  final bool isSelected;

  final VoidCallback onTap;

  const ClientRow({
    super.key,
    required this.client,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;

    return Material(
      color: isSelected ? c.primarySoft : c.surface,
      borderRadius: t.radius.mdBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: t.radius.mdBorder,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: t.radius.mdBorder,
            border: Border.all(color: isSelected ? c.primaryBorder : c.border),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: t.space.sm,
            vertical: t.space.sm,
          ),
          child: Row(
            children: [
              _Avatar(name: client.nombre),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      client.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.text.label.copyWith(color: c.fg),
                    ),
                    if (client.email != null) ...[
                      SizedBox(height: t.space.xxs),
                      Text(
                        client.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.caption.copyWith(color: c.fgMuted),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: t.space.xs),
              if (isSelected)
                _ViewingBadge(label: 'Viendo')
              else
                Icon(Icons.chevron_right, size: 20, color: c.fgSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Iniciales sobre círculo teñido. Da anclaje visual a la lista sin pedir una
/// foto que el backend no manda en este endpoint.
class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      width: kClientRowAvatarSize,
      height: kClientRowAvatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.color.primarySoftStrong,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: t.text.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: t.color.primaryHover,
        ),
      ),
    );
  }
}

class _ViewingBadge extends StatelessWidget {
  final String label;

  const _ViewingBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.xs,
        vertical: t.space.xxs,
      ),
      decoration: BoxDecoration(
        color: t.color.primarySoftStrong,
        borderRadius: t.radius.fullBorder,
      ),
      child: Text(
        label,
        style: t.text.overline.copyWith(color: t.color.primaryHover),
      ),
    );
  }
}
