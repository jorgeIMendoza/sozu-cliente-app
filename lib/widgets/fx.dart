import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Efectos visuales sutiles del portal (animaciones de marca SOZU).

/// Contenedor responsive para pantallas secundarias: limita el ancho de
/// lectura en desktop; en móvil no altera nada.
///
/// El tope es [kSozuContentMaxWidth] (`max-w-7xl` de Tailwind, 1280): el MISMO
/// que usan el shell del portal y `AdminLayout`. Antes eran 900 aquí, 1100 en
/// `ContentFrame` y 1280 en el shell, así que la columna de contenido cambiaba
/// de ancho al navegar entre pantallas de la misma app.
class WebFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const WebFrame({
    super.key,
    required this.child,
    this.maxWidth = kSozuContentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w <= maxWidth) return child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Centra el contenido de un tab con max-width de lectura en desktop.
/// Mismo tope que [WebFrame]: [kSozuContentMaxWidth].
class ContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentFrame({
    super.key,
    required this.child,
    this.maxWidth = kSozuContentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Grid fluido: 1 columna en móvil, 2-3 columnas en pantallas anchas.
class ResponsiveCardGrid extends StatelessWidget {
  final List<Widget> children;
  final double minCardWidth;
  final double gap;

  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.minCardWidth = 330,
    this.gap = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / (minCardWidth + gap)).floor().clamp(1, 3);
        if (cols <= 1) {
          return Column(
            children: [
              for (final w in children)
                Padding(
                  padding: EdgeInsets.only(bottom: gap),
                  child: w,
                ),
            ],
          );
        }
        final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final w in children) SizedBox(width: itemW, child: w),
          ],
        );
      },
    );
  }
}
