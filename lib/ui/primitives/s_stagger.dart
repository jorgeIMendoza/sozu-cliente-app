import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Retardo entre un elemento y el siguiente.
///
/// 40 ms son ~2.4 frames a 60 Hz. Es el mínimo que el ojo lee como SECUENCIA:
/// por debajo de ~25 ms (1.5 frames) dos elementos se perciben simultáneos y el
/// escalonado se pierde, así que solo gasta frames sin comunicar nada. Por
/// encima de ~80 ms cada elemento se lee como un evento aparte y la lista se
/// siente montada de a poco en vez de entrar de una pieza.
const Duration _defaultStep = Duration(milliseconds: 40);

/// Techo del retardo acumulado.
///
/// **No es un detalle opcional.** Con [_defaultStep] y una lista de 50 filas, el
/// último elemento entraría 2000 ms después del primero: el usuario alcanza a
/// hacer scroll antes de que la lista termine de aparecer y ve huecos vacíos
/// llenándose bajo el dedo. Eso no se lee como elegancia, se lee como que la app
/// está trabada.
///
/// 320 ms son 8 pasos: a partir del noveno elemento el ojo ya no sigue llegadas
/// individuales, solo percibe "una ola de arriba hacia abajo", y esa ola se
/// comunica igual saturando el retardo. Sumado a la duración de cada elemento
/// (240 ms, `SozuMotion.normal`) el total es 560 ms, por debajo de los ~600 ms
/// donde una carga deja de sentirse inmediata.
const Duration _defaultMaxDelay = Duration(milliseconds: 320);

/// Distancia vertical que recorre un elemento al entrar.
///
/// 12 px coinciden con `space.sm`, pero no se leen del token de espaciado a
/// propósito: esto es recorrido de movimiento, no aire entre cosas, y si mañana
/// el espaciado compacto baja a 10 px la animación no tiene por qué acortarse.
/// El valor es deliberadamente corto: a partir de ~24 px el desplazamiento se
/// nota como que el contenido "salta", y en una lista de varias filas moverse
/// mucho en paralelo marea.
const double _defaultOffset = 12.0;

/// Un elemento que entra desvaneciéndose y subiendo unos píxeles.
///
/// ## Por qué existe
///
/// Hoy las pantallas pasan del skeleton al contenido con un corte seco: los
/// datos aparecen de golpe, todos en el mismo frame. Es parte de por qué la app
/// se siente como un sistema viejo. Un elemento que entra con opacidad y unos
/// píxeles de recorrido comunica que ACABA de llegar, y con eso la carga se lee
/// como algo que sucede en lugar de un parpadeo.
///
/// El movimiento va hacia ARRIBA (el elemento nace 12 px abajo y sube a su
/// lugar) porque acompaña la dirección en la que el contenido se acomoda al
/// llenarse una lista. Bajar leería como que algo se desprendió.
///
/// ## La animación corre UNA sola vez
///
/// El disparo vive en `didChangeDependencies` detrás de una bandera, no en
/// `build`. Un `build` puede ejecutarse muchas veces por razones que no tienen
/// nada que ver con la entrada del elemento: cambio de tema, resize de la
/// ventana, un `setState` del padre, un provider que emite. Si la entrada se
/// reiniciara en cada uno de esos, la pantalla parpadearía en momentos
/// aleatorios, que es peor que no animar.
///
/// Por lo mismo, cambiar [delay] u [offset] en caliente no re-dispara nada: son
/// parámetros de un evento que ya ocurrió.
///
/// ## Reduced motion
///
/// Cuando el sistema pide reducir movimiento, `context.s.motion.normal` llega en
/// `Duration.zero` y este widget devuelve al hijo **tal cual**: sin
/// `FadeTransition`, sin `Transform`, sin capas intermedias. No se deja el
/// andamio puesto con la animación en 1, porque un `Opacity` que nunca cambia
/// sigue costando una capa de composición en cada frame por nada.
///
/// ```dart
/// SFadeInUp(child: ResumenCard(...))
/// SFadeInUp(delay: SStaggered.delayForIndex(i), child: ClientTile(...))
/// ```
class SFadeInUp extends StatefulWidget {
  final Widget child;

  /// Cuánto espera antes de empezar. Se usa para escalonar: ver
  /// [SStaggered.delayForIndex].
  final Duration delay;

  /// Píxeles que sube al entrar.
  final double offset;

  const SFadeInUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = _defaultOffset,
  });

  @override
  State<SFadeInUp> createState() => _SFadeInUpState();
}

class _SFadeInUpState extends State<SFadeInUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// Progreso ya pasado por la curva de entrada. Se guarda en un campo en vez de
  /// crearse en `build` para que el `FadeTransition` no tenga que resuscribirse
  /// a un objeto nuevo en cada reconstrucción.
  late Animation<double> _entry;

  /// La entrada ya se disparó (o se resolvió como "sin animación"). Es lo que
  /// impide que un rebuild vuelva a arrancarla.
  bool _started = false;

  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final motion = context.s.motion;
    _controller.duration = motion.normal;
    _entry = _controller.drive(CurveTween(curve: motion.enter));

    if (_started) return;
    _started = true;

    // Reduced motion: el elemento nace en su estado final. Se marca como
    // iniciada igual, así que si el usuario apaga el ajuste con la app abierta
    // el contenido que ya está en pantalla no se anima de golpe.
    if (motion.normal == Duration.zero) {
      _controller.value = 1;
      return;
    }

    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }

    _timer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sin capas intermedias cuando no hay movimiento que aplicar.
    if (context.s.motion.normal == Duration.zero) return widget.child;

    return FadeTransition(
      opacity: _entry,
      // El `child` va por fuera del builder: así el subárbol se construye una
      // vez y cada frame solo recalcula el `Transform`, que es una matriz.
      child: AnimatedBuilder(
        animation: _entry,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - _entry.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Aplica retardo incremental a una lista de hijos.
///
/// ## Por qué no es un `ListView`
///
/// Un widget que impone su propio scroll no sirve dentro de otro scroll, y el
/// caso dominante es justamente ese: un bloque de tarjetas dentro de la columna
/// scrolleable de una pantalla. Así que aquí solo se ENVUELVEN los hijos; quién
/// los apila lo decide el sitio de uso.
///
/// Un widget de Flutter no puede devolver una lista, así que el contenedor se
/// pasa por [builder]. Sin [builder] se usa una [Column], que es el caso
/// dominante para bloques apilados.
///
/// ```dart
/// // Bloques de una pantalla:
/// SStaggered(children: [ResumenCard(...), PagosCard(...), DocsCard(...)])
///
/// // Otro contenedor:
/// SStaggered(
///   children: chips,
///   builder: (context, kids) => Wrap(spacing: 8, children: kids),
/// )
/// ```
///
/// Para un `ListView.builder` no hay lista de hijos sino un índice: ahí se usa
/// [delayForIndex] directamente.
///
/// ```dart
/// itemBuilder: (context, i) => SFadeInUp(
///   delay: SStaggered.delayForIndex(i),
///   child: ClientTile(...),
/// )
/// ```
class SStaggered extends StatelessWidget {
  final List<Widget> children;

  /// Retardo que se suma por cada posición. Ver [_defaultStep].
  final Duration step;

  /// Techo del retardo acumulado. Ver [_defaultMaxDelay]: sin él una lista larga
  /// tarda segundos en terminar de aparecer.
  final Duration maxDelay;

  /// Píxeles que sube cada hijo al entrar.
  final double offset;

  /// Contenedor de los hijos ya envueltos. `null` = [Column].
  final Widget Function(BuildContext context, List<Widget> children)? builder;

  const SStaggered({
    super.key,
    required this.children,
    this.step = _defaultStep,
    this.maxDelay = _defaultMaxDelay,
    this.offset = _defaultOffset,
    this.builder,
  });

  /// Retardo que le toca al elemento [index], saturado en [maxDelay].
  ///
  /// El índice 0 no espera: el primer elemento es el que confirma que la carga
  /// terminó, y retrasarlo agrega latencia percibida a la pantalla completa.
  ///
  /// Estático para que un `itemBuilder` pueda usarlo sin tener una instancia de
  /// [SStaggered] a mano.
  static Duration delayForIndex(
    int index, {
    Duration step = _defaultStep,
    Duration maxDelay = _defaultMaxDelay,
  }) {
    if (index <= 0) return Duration.zero;
    final delay = step * index;
    return delay > maxDelay ? maxDelay : delay;
  }

  @override
  Widget build(BuildContext context) {
    final wrapped = <Widget>[
      for (var i = 0; i < children.length; i++)
        SFadeInUp(
          delay: delayForIndex(i, step: step, maxDelay: maxDelay),
          offset: offset,
          child: children[i],
        ),
    ];

    final container = builder;
    if (container != null) return container(context, wrapped);

    return Column(
      mainAxisSize: MainAxisSize.min,
      // stretch y no el center por defecto de Column: estos hijos son bloques de
      // una página (cards, filas), y una card centrada con su ancho intrínseco
      // deja márgenes desiguales respecto al resto de la pantalla.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: wrapped,
    );
  }
}
