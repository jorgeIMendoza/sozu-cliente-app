import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/breakpoints.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Estado vacío: icono en círculo teñido + título + mensaje.
///
/// Se ancla ARRIBA por defecto ([centered] = false).
class SEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  /// Acción opcional (botón de reintentar, limpiar filtros…).
  final Widget? action;

  /// `true` centra vertical y horizontalmente. Solo tiene sentido en
  /// contenedores de alto acotado.
  final bool centered;

  const SEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: c.primarySoftStrong,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 26, color: c.primaryHover),
        ),
        SizedBox(height: t.space.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: t.text.h3.copyWith(color: c.fg),
        ),
        if (message != null) ...[
          SizedBox(height: t.space.xxs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: t.text.bodySmall.copyWith(color: c.fgMuted),
            ),
          ),
        ],
        if (action != null) ...[SizedBox(height: t.space.md), action!],
      ],
    );

    if (centered) return Center(child: content);

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        // Margen superior acotado: da aire sin depender del alto del contenedor.
        padding: EdgeInsets.only(
          top: context.responsive(mobile: 32.0, desktop: 48.0),
          left: t.space.md,
          right: t.space.md,
          bottom: t.space.md,
        ),
        child: content,
      ),
    );
  }
}
