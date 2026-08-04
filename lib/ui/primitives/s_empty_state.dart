import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/primitives/s_card.dart';
import 'package:sozu_cliente_app/ui/theme/breakpoints.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Estado vacío: icono en círculo teñido + título + mensaje.
///
/// Se ancla ARRIBA por defecto ([centered] = false); [SEmptyState.card] lo mete
/// en una [SCard] para cuando el vacío ocupa el lugar de una tarjeta de datos.
class SEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  /// Acción opcional (botón de reintentar, limpiar filtros…).
  final Widget? action;

  /// `true` centra vertical y horizontalmente. Solo tiene sentido en
  /// contenedores de alto acotado.
  final bool centered;

  /// Marca de que se construyó con [SEmptyState.card].
  final bool _inCard;

  const SEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.centered = false,
  }) : _inCard = false;

  /// El mismo estado vacío dentro de una [SCard], para sustituir a una tarjeta de
  /// datos que no tiene qué mostrar.
  ///
  /// Constructor con nombre y no un campo `inCard`: la card cambia el ENVOLTORIO
  /// y con él qué props aplican ([centered] no, lo acota la card), y eso un flag
  /// booleano no lo puede expresar.
  const SEmptyState.card({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  }) : _inCard = true,
       centered = false;

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

    if (_inCard) {
      return SCard(
        // Más aire vertical que el padding estándar de card: el bloque es un
        // aviso, no contenido, y pegado al filo se lee como si faltara algo.
        padding: EdgeInsets.symmetric(
          vertical: t.space.xl,
          horizontal: t.space.md,
        ),
        child: content,
      );
    }

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
