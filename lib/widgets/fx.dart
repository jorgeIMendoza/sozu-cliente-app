import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Efectos visuales sutiles del portal (animaciones de marca SOZU).

/// Feedback táctil: la tarjeta se encoge ligeramente al presionar.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const PressableScale({super.key, required this.child, this.onTap});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final m = context.s.motion;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      // `motion.pressScale` y no el 0.97 que traía cocido: con dos valores
      // distintos, un `SButton` y una card envuelta aquí se hundían diferente en
      // la misma pantalla, y esa incoherencia es justo lo que se lee como
      // interfaz armada por manos distintas. De paso el hundido desaparece solo
      // con movimiento reducido, donde el token vale 1.0.
      //
      // La curva es `emphasized` por lo mismo que en el press de `SPressable`:
      // la escala recorre distancia, y es el mismo gesto en las dos primitivas.
      child: AnimatedScale(
        scale: _pressed ? m.pressScale : 1,
        duration: m.fast,
        curve: m.emphasized,
        child: widget.child,
      ),
    );
  }
}

/// Breakpoint de escritorio.
bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 1024;

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
