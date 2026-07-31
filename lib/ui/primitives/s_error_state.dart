import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/primitives/s_button.dart';
import 'package:sozu_cliente_app/ui/primitives/s_card.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Estado de error con reintento, en tarjeta: icono + título + botón.
///
/// Es el reverso de `SEmptyState`: vacío es un resultado válido, error es un
/// fallo del que se puede volver, así que [onRetry] no es opcional.
///
/// ```dart
/// SErrorState(
///   title: 'No pudimos cargar tus pagos',
///   message: 'Revisa tu conexión e intenta de nuevo.',
///   onRetry: () => ref.invalidate(pagosProvider),
/// )
/// ```
class SErrorState extends StatelessWidget {
  /// Qué falló, en una línea y en lenguaje del usuario.
  final String title;

  /// Detalle o siguiente paso. `null` deja solo el título.
  final String? message;

  final VoidCallback onRetry;

  const SErrorState({
    super.key,
    required this.title,
    required this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;

    return SCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: _iconSize, color: c.fgSubtle),
          SizedBox(height: t.space.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: t.text.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: c.fg,
            ),
          ),
          if (message != null) ...[
            SizedBox(height: t.space.xxs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _messageMaxWidth),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: t.text.bodySmall.copyWith(color: c.fgMuted),
              ),
            ),
          ],
          SizedBox(height: t.space.md),
          SButton(label: 'Reintentar', onPressed: onRetry, fullWidth: false),
        ],
      ),
    );
  }
}

/// Icono de "sin conexión". Es el ancla visual del bloque, así que va por encima
/// de la escala de iconos de texto.
const double _iconSize = 40;

/// Ancho máximo del mensaje: misma medida de línea legible que `SEmptyState`.
const double _messageMaxWidth = 420;
