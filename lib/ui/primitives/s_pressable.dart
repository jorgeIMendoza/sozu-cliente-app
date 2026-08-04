import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Firma del constructor puente [SPressable.detector].
typedef SPressStateBuilder =
    Widget Function(BuildContext context, bool hovered, bool pressed);

/// Superficie interactiva GLOBAL: hover, press y foco de teclado sobre
/// cualquier hijo.
///
/// Es la capa de *interacción*, no de *apariencia*: no dibuja bordes, no pone
/// padding y no decide el color en reposo. La excepción es el fondo de hover,
/// que **se pinta DETRÁS del hijo**: si el hijo pinta su propia superficie
/// opaca lo tapa, así que el hijo debe quedarse transparente o pasar el color
/// por [hoverColor] sin pintar nada.
///
/// Con `SozuMotion.reduced` no hace falta ninguna rama `if (reduceMotion)`: las
/// duraciones quedan en cero y `pressScale` en `1.0`, así que se pierde la
/// transición y el hundido pero el color de hover sobrevive (es información).
///
/// ```dart
/// SPressable(
///   onTap: () => abrirDetalle(id),
///   borderRadius: context.s.radius.sheetBorder,
///   hoverLift: true,
///   semanticLabel: 'Departamento 402',
///   child: _contenidoDeLaCard(),
/// )
/// ```
class SPressable extends StatefulWidget {
  /// Contenido de la superficie. Se pinta tal cual: esta primitiva no le agrega
  /// padding ni borde.
  final Widget child;

  /// `null` deshabilita la superficie por completo: sin hover, sin cursor de
  /// mano y sin foco. Es la única forma de deshabilitarla (no hay flag
  /// `disabled`).
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  /// Radio del fondo de hover, del recorte del ripple y del anillo de foco;
  /// `null` usa `radius.mdBorder`. Debe coincidir con el radio del hijo o el
  /// fondo de hover asoma por las esquinas.
  final BorderRadius? borderRadius;

  /// Fondo con el puntero encima o con foco de teclado; `null` usa
  /// `color.surfaceAlt`.
  final Color? hoverColor;

  /// Hundido al presionar (`motion.pressScale`). Se apaga en superficies que ya
  /// se mueven por otro motivo (una fila dentro de un carrusel que arrastra).
  final bool pressScale;

  /// La sombra sube de `shadow.sm` a `shadow.md` en hover. SOLO para cards: en
  /// una fila de lista se lee como que la fila se despega del listado.
  final bool hoverLift;

  final String? tooltip;

  /// Etiqueta para el lector de pantalla.
  ///
  /// Si es `null` **no se agrega ningún nodo de semántica** y la aportan los
  /// hijos; un `Semantics(label: '')` taparía el contenido al fusionarse. Se
  /// pasa etiqueta cuando el contenido visual no se lee bien en voz alta, y en
  /// ese caso los hijos se excluyen para no anunciar todo dos veces.
  final String? semanticLabel;

  /// `true` cuando la superficie lleva a otra pantalla o abre una URL: cambia
  /// SOLO la semántica (`link` en vez de `button`) para que el destino aparezca
  /// en la lista de enlaces del lector. Solo aplica si hay [semanticLabel].
  final bool isNavigation;

  /// Para que la pantalla controle el orden de tabulación o dispare el foco.
  final FocusNode? focusNode;

  /// Modo puente: ver [SPressable.detector]. `null` en el uso normal.
  final SPressStateBuilder? stateBuilder;

  const SPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.hoverColor,
    this.pressScale = true,
    this.hoverLift = false,
    this.tooltip,
    this.semanticLabel,
    this.isNavigation = false,
    this.focusNode,
  }) : stateBuilder = null;

  /// Detecta hover y press y se los pasa al hijo, SIN agregar capa de gesto.
  ///
  /// **No usar en código nuevo:** sin capa de gesto no hay foco de teclado ni
  /// semántica, y el hijo queda inalcanzable con Tab. Existe para los builders
  /// legacy del portal y para [SHoverBuilder] suelto; el constructor normal ya
  /// expone el hover a los hijos vía [SHoverBuilder].
  const SPressable.detector({super.key, required SPressStateBuilder builder})
    : stateBuilder = builder,
      // El hijo real lo produce el builder; este nunca se pinta.
      child = const SizedBox.shrink(),
      onTap = null,
      onLongPress = null,
      borderRadius = null,
      hoverColor = null,
      pressScale = false,
      hoverLift = false,
      tooltip = null,
      semanticLabel = null,
      isNavigation = false,
      focusNode = null;

  @override
  State<SPressable> createState() => _SPressableState();
}

/// Anillo de foco: 2 px de grosor separados 2 px de la caja, mismos valores que
/// [SButton]. Va por fuera y sin ocupar espacio, así que no mueve el layout.
const double _focusRingWidth = 2.0;
const double _focusRingGap = 2.0;

class _SPressableState extends State<SPressable> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _disabled => widget.onTap == null;

  @override
  Widget build(BuildContext context) {
    final builder = widget.stateBuilder;
    if (builder != null) return _buildDetector(builder);

    final t = context.s;
    final m = t.motion;
    final c = t.color;
    final radius = widget.borderRadius ?? t.radius.mdBorder;
    final disabled = _disabled;

    // hover del mouse y foco de teclado pintan igual: los dos significan "este
    // es el elemento apuntado".
    final highlighted = (_hovered || _focused) && !disabled;
    final showRing = _focused && !disabled;

    // Sin etiqueta propia que lo sustituya, excluir al hijo dejaría la
    // superficie muda.
    final content = widget.semanticLabel == null
        ? widget.child
        : ExcludeSemantics(child: widget.child);

    final box = AnimatedContainer(
      // Con movimiento reducido `instant` es cero y el color salta.
      duration: m.instant,
      curve: m.standard,
      decoration: BoxDecoration(
        color: highlighted
            ? (widget.hoverColor ?? c.surfaceAlt)
            : Colors.transparent,
        borderRadius: radius,
        // `null` y no `[]` sin lift: una lista vacía pisaría la sombra propia
        // del hijo.
        boxShadow: widget.hoverLift
            ? (highlighted ? t.shadow.md : t.shadow.sm)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          focusNode: widget.focusNode,
          borderRadius: radius,
          mouseCursor: WidgetStateMouseCursor.clickable,
          // Hover y foco los pinta el AnimatedContainer de arriba; los overlays
          // del InkWell se sumarían de golpe al color ya resuelto.
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          // El velo de press sí se deja: en táctil no hay hover y con
          // movimiento reducido tampoco hundido, así que sería el único feedback.
          highlightColor: c.muted,
          splashColor: c.primarySoftStrong,
          onHover: (v) => setState(() => _hovered = v),
          onFocusChange: (v) => setState(() => _focused = v),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          // Fuente única del hover para los hijos (ver [SHoverBuilder]).
          child: _SPressableScope(
            hovered: highlighted,
            pressed: _pressed && !disabled,
            child: content,
          ),
        ),
      ),
    );

    final interactive = AnimatedScale(
      // Con `SozuMotion.reduced` este factor es 1.0: el hundido desaparece solo.
      scale: _pressed && widget.pressScale && !disabled ? m.pressScale : 1,
      duration: m.fast,
      curve: m.emphasized,
      // El anillo se PINTA por fuera: un borde real movería el layout al enfocar.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: showRing ? 1 : 0),
        duration: m.fast,
        curve: m.standard,
        builder: (context, progress, child) => CustomPaint(
          painter: _RingPainter(
            color: c.primaryBorder,
            radius: radius,
            progress: progress,
          ),
          child: child,
        ),
        child: box,
      ),
    );

    final tooltip = widget.tooltip;
    final withTooltip = tooltip == null
        ? interactive
        : Tooltip(message: tooltip, child: interactive);

    final label = widget.semanticLabel;
    if (label == null) {
      // Sin etiqueta NO se envuelve en Semantics: un label vacío se fusiona con
      // los hijos y el lector anuncia un control sin nombre.
      return withTooltip;
    }

    // MergeSemantics ENVUELVE al Semantics y no al revés: al revés quedan dos
    // nodos hermanos y el lector anuncia dos controles.
    return MergeSemantics(
      child: Semantics(
        button: !widget.isNavigation,
        link: widget.isNavigation,
        enabled: !disabled,
        label: label,
        child: withTooltip,
      ),
    );
  }

  /// Modo puente de [SPressable.detector]: solo detección.
  ///
  /// `MouseRegion` + `Listener` y no `InkWell` porque el gesto lo trae el hijo,
  /// así que nadie reportaría `onHighlightChanged`.
  Widget _buildDetector(SPressStateBuilder builder) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      // El press se cancela al salir: si el puntero se va apretado nadie manda
      // el `up` y el hijo se queda hundido.
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: builder(context, _hovered, _pressed),
      ),
    );
  }
}

/// Expone el hover al hijo que necesita pintarse distinto al estar apuntado:
/// teñir un icono, revelar un chevron, subrayar un título.
///
/// Dentro de un [SPressable] lee el estado de esa superficie (el hijo se
/// enciende con el puntero en cualquier parte de la fila). Suelto detecta su
/// propio hover.
///
/// ```dart
/// SPressable(
///   onTap: abrir,
///   child: SHoverBuilder(
///     builder: (context, hovered) => Icon(
///       Icons.chevron_right,
///       color: hovered ? context.s.color.fg : context.s.color.fgSubtle,
///     ),
///   ),
/// )
/// ```
class SHoverBuilder extends StatelessWidget {
  const SHoverBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool isHovered) builder;

  @override
  Widget build(BuildContext context) {
    final scope = _SPressableScope.maybeOf(context);
    // Se reusa el estado de la superficie de arriba: otro MouseRegion dentro se
    // desincronizaría al mover el puntero entre subwidgets.
    if (scope != null) return builder(context, scope.hovered);
    return SPressable.detector(
      builder: (context, hovered, _) => builder(context, hovered),
    );
  }
}

/// Estado de interacción de la superficie, visible para todo su subárbol.
class _SPressableScope extends InheritedWidget {
  final bool hovered;
  final bool pressed;

  const _SPressableScope({
    required this.hovered,
    required this.pressed,
    required super.child,
  });

  static _SPressableScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SPressableScope>();

  @override
  bool updateShouldNotify(_SPressableScope old) =>
      old.hovered != hovered || old.pressed != pressed;
}

/// Anillo de foco dibujado por fuera de la superficie, sin ocupar espacio.
///
/// Duplica al pintor de [SButton] a propósito; si aparece un tercero se extrae.
class _RingPainter extends CustomPainter {
  final Color color;
  final BorderRadius radius;

  /// 0 = sin anillo, 1 = anillo completo. Se anima por opacidad y no por grosor
  /// para que el trazo no se vea borroso a mitad de la transición.
  final double progress;

  const _RingPainter({
    required this.color,
    required this.radius,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // El medio grosor centra el trazo: sin él la mitad del anillo cae encima
    // del borde del hijo y se ve más delgado.
    final outset = _focusRingGap + _focusRingWidth / 2;
    final rect = Rect.fromLTWH(
      -outset,
      -outset,
      size.width + outset * 2,
      size.height + outset * 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _focusRingWidth
      ..color = color.withValues(alpha: color.a * progress.clamp(0, 1));

    canvas.drawRRect(
      radius.add(BorderRadius.circular(outset)).resolve(null).toRRect(rect),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.radius != radius;
}
