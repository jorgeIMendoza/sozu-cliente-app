import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Efectos visuales sutiles del portal (animaciones de marca SOZU).

/// Entrada con fade + deslizamiento hacia arriba, con retraso opcional para
/// escalonar secciones.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int delayMs;

  /// Duración de la entrada. En null (lo normal) usa `motion.slow`, que es el
  /// token de lo que mueve superficie completa. Se deja override porque el
  /// parámetro ya era público, no porque haya que usarlo.
  final Duration? duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.duration,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  // Sin `duration` aquí: la resuelve didChangeDependencies desde los tokens,
  // que necesitan un `context` que en el inicializador del campo todavía no
  // se puede leer.
  late final AnimationController _c = AnimationController(vsync: this);
  late final CurvedAnimation _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.linear,
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(_fade);

  /// La entrada se dispara una sola vez, no en cada cambio de dependencias.
  bool _arrancada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Leer los tokens aquí (y no en initState) es lo que hace que la entrada
    // respete "reducir movimiento" del sistema gratis: en ese modo el token
    // vale Duration.zero y el contenido aparece ya colocado.
    final motion = context.s.motion;
    _c.duration = widget.duration ?? motion.slow;
    _fade.curve = motion.enter;
    if (_arrancada) return;
    _arrancada = true;
    if (widget.delayMs == 0) {
      _c.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Duración del conteo de la cifra hero.
///
/// NO es un token de movimiento y no debe volverse uno: los tokens llegan hasta
/// 380 ms porque describen transiciones de estado, y aquí la duración no es el
/// costo de moverse de A a B sino el efecto mismo - lo que se ve es la cifra
/// recorriendo dígitos, y por debajo de ~700 ms el recorrido no se lee, solo
/// parpadea. Atarla a `motion.slow` haría que subir el peso de las hojas
/// modales acelerara este conteo, que no tiene nada que ver.
const Duration _countUpDuration = Duration(milliseconds: 900);

/// Cifra de dinero que "cuenta" desde 0 hasta el valor (hero del dashboard).
///
/// Parámetros opcionales (aditivos, sin romper llamadas existentes):
/// - [prefix]: texto antepuesto al monto (p.ej. "+" para plusvalía).
/// - [compact]: usa `formatMXNCompact` ("$2.46M") en vez de `formatMXN`.
/// - [color]: conveniencia; si se pasa, tiñe el estilo (equivale a
///   `style.copyWith(color: color)`).
class CountUpMoney extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final bool compact;
  final Color? color;

  const CountUpMoney({
    super.key,
    required this.value,
    this.style,
    this.duration = _countUpDuration,
    this.prefix = '',
    this.compact = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = color != null
        ? (style ?? const TextStyle()).copyWith(color: color)
        : style;

    // Con "reducir movimiento" la cifra se muestra ya en su valor final.
    //
    // `motion.normal == Duration.zero` es la señal: con `SozuMotion.reduced`
    // todas las duraciones se anulan (ver el token), así que preguntar por una
    // basta y no hay que leer el MediaQuery por separado. Se pregunta aquí y no
    // se ata `duration` al token porque el conteo tiene su propia duración a
    // propósito (ver [_countUpDuration]).
    //
    // Contar dígitos es de los movimientos que peor caen a quien pidió no
    // tenerlos: no es una transición que se pueda ignorar, es texto que cambia
    // varias veces por frame en el elemento más grande de la pantalla.
    if (context.s.motion.normal == Duration.zero) {
      return Text(
        '$prefix${compact ? formatMXNCompact(value) : formatMXN(value)}',
        style: effectiveStyle,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      // easeOutCubic propio, no `motion.enter`: la curva la define el conteo
      // (frenar sobre los últimos dígitos), no la escala de movimiento.
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        '$prefix${compact ? formatMXNCompact(v) : formatMXN(v)}',
        style: effectiveStyle,
      ),
    );
  }
}

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
