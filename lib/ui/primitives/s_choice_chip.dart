import 'dart:math' as math;

import 'package:flutter/material.dart';
// `material.dart` no reexporta `rendering.dart`: sin esto no hay
// RenderShiftedBox ni MatrixUtils.
import 'package:flutter/rendering.dart';

import 'package:sozu_cliente_app/ui/primitives/s_pressable.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';

/// Tamaño de la pastilla. Solo cambia el aire y un paso de la escala
/// tipográfica: el área tocable siempre llega a [_minTapTarget].
enum SChoiceChipSize {
  /// 28 px de pastilla. Filas densas de filtros, barras de herramientas.
  sm,

  /// 36 px de pastilla. Por defecto.
  md,
}

/// Pastilla SELECCIONABLE del design system: filtros, segmentos, opciones
/// múltiples.
///
/// No es `SBadge`: la insignia es de solo lectura y esta responde al puntero, al
/// teclado y tiene estado seleccionado. Si el chip no se puede tocar, es una
/// insignia.
///
/// El estado seleccionado se pinta con el par de marca (fondo teñido + texto
/// verde oscuro), NO con verde sólido: blanco sobre el verde de marca queda en
/// 3.4:1 y el tinte llega a 4.3:1.
///
/// ```dart
/// SChoiceChip(
///   label: 'Pagados',
///   selected: _estatus == 'pagado',
///   onSelected: (v) => setState(() => _estatus = v ? 'pagado' : 'todos'),
/// )
/// ```
class SChoiceChip extends StatelessWidget {
  /// Texto de la opción. Ya viene formateado: la pastilla no traduce.
  final String label;

  final bool selected;

  /// Recibe el valor INVERTIDO al pulsar. En un grupo excluyente (un solo
  /// activo) se ignora el valor y se fija la opción.
  final ValueChanged<bool> onSelected;

  /// Icono a la izquierda del texto.
  final IconData? icon;

  /// `false` apaga el gesto, el hover y el foco además de atenuar los colores.
  final bool enabled;

  final SChoiceChipSize size;

  const SChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.enabled = true,
    this.size = SChoiceChipSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final disabled = !enabled;

    // MergeSemantics ENVUELVE al Semantics: al revés el nodo `selected` y el
    // `button` de SPressable quedan hermanos y el lector anuncia dos controles.
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        child: _TapTarget(
          child: SPressable(
            onTap: disabled ? null : () => onSelected(!selected),
            borderRadius: t.radius.fullBorder,
            // La pastilla pinta su propio fondo OPACO encima, así que el de
            // SPressable no se vería; el hover lo resuelve `_SChoiceChipStyle`.
            // Por lo mismo el velo de press queda tapado: el feedback al pulsar
            // es el hundido (`motion.pressScale`) más el cambio de selección.
            hoverColor: Colors.transparent,
            semanticLabel: label,
            child: SHoverBuilder(
              builder: (context, highlighted) => _pill(
                t,
                _SChoiceChipStyle.resolve(
                  selected: selected,
                  highlighted: highlighted,
                  disabled: disabled,
                  size: size,
                  colors: t.color,
                  theme: t,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(SozuTheme t, _SChoiceChipStyle style) {
    return AnimatedContainer(
      duration: t.motion.instant,
      curve: t.motion.standard,
      constraints: BoxConstraints(minHeight: style.height),
      padding: style.padding,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: t.radius.fullBorder,
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: style.iconSize, color: style.foreground),
            SizedBox(width: style.gap),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.textStyle.copyWith(color: style.foreground),
          ),
        ],
      ),
    );
  }
}

/// Área tocable mínima en los dos ejes (WCAG 2.5.5 y HIG de Apple). La pastilla
/// se ve más baja: esto NO la agranda, agranda lo que se puede tocar.
const double _minTapTarget = 44.0;

/// Apariencia ya resuelta de la pastilla: **el único lugar del archivo que sabe
/// de estados**. Todos los campos son requeridos, así que un estado nuevo no
/// puede olvidarse de uno.
@immutable
class _SChoiceChipStyle {
  final Color background;

  /// Texto e icono.
  final Color foreground;

  final Color border;

  /// Alto de la pastilla, no del área tocable.
  final double height;

  final EdgeInsets padding;
  final TextStyle textStyle;
  final double iconSize;

  /// Separación entre icono y texto.
  final double gap;

  const _SChoiceChipStyle({
    required this.background,
    required this.foreground,
    required this.border,
    required this.height,
    required this.padding,
    required this.textStyle,
    required this.iconSize,
    required this.gap,
  });

  /// Traduce (estado × tamaño × roles de color) a apariencia concreta.
  ///
  /// [colors] llega aparte de [theme] para poder resolver contra un set fijo
  /// ([SozuColorRoles.light]) sin `BuildContext`.
  factory _SChoiceChipStyle.resolve({
    required bool selected,
    required bool highlighted,
    required bool disabled,
    required SChoiceChipSize size,
    required SozuColorRoles colors,
    required SozuTheme theme,
  }) {
    final m = _SChoiceChipMetrics.forSize(size, theme);
    final c = colors;

    // Deshabilitado pierde el verde pero NO la distinción: el relleno inerte
    // sigue diciendo cuál estaba elegida.
    final (Color background, Color foreground, Color border) = switch ((
      disabled,
      selected,
      highlighted,
    )) {
      (true, true, _) => (c.muted, c.fgSubtle, c.borderSoft),
      (true, false, _) => (c.surface, c.fgSubtle, c.borderSoft),
      // El par del tono `positive` de SBadge: un chip y una insignia en la
      // misma pantalla no pueden ser dos verdes distintos.
      (false, true, true) => (c.primarySoftStrong, c.primaryHover, c.primary),
      (false, true, false) => (
        c.primarySoftStrong,
        c.primaryHover,
        c.primaryBorder,
      ),
      (false, false, true) => (c.surfaceAlt, c.fg, c.primaryBorder),
      (false, false, false) => (c.surface, c.fgMuted, c.border),
    };

    return _SChoiceChipStyle(
      background: background,
      foreground: foreground,
      border: border,
      height: m.height,
      padding: m.padding,
      textStyle: m.textStyle,
      iconSize: m.iconSize,
      gap: m.gap,
    );
  }
}

/// Medidas por tamaño.
@immutable
class _SChoiceChipMetrics {
  final double height;
  final EdgeInsets padding;
  final TextStyle textStyle;
  final double iconSize;
  final double gap;

  const _SChoiceChipMetrics({
    required this.height,
    required this.padding,
    required this.textStyle,
    required this.iconSize,
    required this.gap,
  });

  factory _SChoiceChipMetrics.forSize(SChoiceChipSize size, SozuTheme t) {
    // Sin padding vertical: el alto lo fija `height` como minHeight, y sumar
    // vertical haría crecer la pastilla con densidad compacta.
    EdgeInsets h(double value) => EdgeInsets.symmetric(horizontal: value);

    switch (size) {
      case SChoiceChipSize.sm:
        return _SChoiceChipMetrics(
          height: 28,
          padding: h(t.space.sm),
          textStyle: t.text.caption.copyWith(fontWeight: FontWeight.w600),
          iconSize: _iconSizeSm,
          gap: t.space.xxs,
        );
      case SChoiceChipSize.md:
        return _SChoiceChipMetrics(
          height: 36,
          padding: h(t.space.md),
          textStyle: t.text.bodySmall.copyWith(fontWeight: FontWeight.w600),
          iconSize: _iconSizeMd,
          gap: t.space.xs,
        );
    }
  }
}

/// Iconos de la pastilla. Fuera de la escala de espaciado a propósito: son
/// tamaños de glifo.
const double _iconSizeSm = 14;
const double _iconSizeMd = 16;

/// Estira el área TOCABLE de su hijo hasta [_minTapTarget] en los dos ejes, sin
/// tocar cómo se pinta: el hijo queda centrado a su tamaño real.
///
/// El anillo de foco y el fondo de hover siguen dibujándose alrededor de la
/// pastilla y no de la caja de 44 px, que es la razón de no usar un `Padding`.
class _TapTarget extends SingleChildRenderObjectWidget {
  const _TapTarget({required Widget super.child});

  @override
  _RenderTapTarget createRenderObject(BuildContext context) =>
      _RenderTapTarget();
}

class _RenderTapTarget extends RenderShiftedBox {
  _RenderTapTarget() : super(null);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(
      Size(
        math.max(child.size.width, _minTapTarget),
        math.max(child.size.height, _minTapTarget),
      ),
    );
    (child.parentData! as BoxParentData).offset = Alignment.center.alongOffset(
      size - child.size as Offset,
    );
  }

  /// Un toque en el aire que rodea a la pastilla se resuelve como un toque en su
  /// centro, así que llega al `InkWell` de dentro.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTest(result, position: position)) return true;

    final center = child!.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (result, position) => child!.hitTest(result, position: center),
    );
  }
}
