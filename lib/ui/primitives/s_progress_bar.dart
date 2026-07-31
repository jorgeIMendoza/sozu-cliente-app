import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Grosor de la barra. Es el único eje de variación: una barra de progreso
/// siempre se lee igual, lo que cambia es cuánto peso tiene en la pantalla.
enum SProgressBarThickness {
  /// 3 px - dentro de una card o de una fila de lista, como remate del dato.
  thin,

  /// 8 px - el caso normal: bloque de avance de pago, avance de obra.
  medium,

  /// 10 px - avance protagonista de la pantalla (hero de resumen, perfil).
  thick,
}

/// Duración del llenado.
///
/// Queda fuera de la escala de movimiento a propósito: los tokens describen
/// transiciones de estado y se topan en 380 ms, y esto es un barrido que recorre
/// todo el ancho y cuyo punto es verse avanzar. Mismo criterio que `CountUpMoney`
/// en `widgets/fx.dart`.
const Duration _fillDuration = Duration(milliseconds: 700);

/// Grosores en px. Son la FORMA del componente, no aire entre cosas: por eso no
/// salen de la escala de espaciado, igual que los altos de `SButton`.
const double _thinHeight = 3;
const double _mediumHeight = 8;
const double _thickHeight = 10;

/// Barra de progreso global del design system. [percent] va de 0 a 100.
///
/// El relleno se anima al cambiar de valor; con movimiento reducido
/// (`context.s.motion.normal` en `Duration.zero`) pinta el valor final de una,
/// sin barrido.
///
/// ```dart
/// SProgressBar(percent: r.porcentajePagado)
/// SProgressBar(percent: item.avancePago, thickness: SProgressBarThickness.thin)
/// ```
class SProgressBar extends StatelessWidget {
  /// Avance en porcentaje (0-100). Los valores fuera de rango se recortan.
  final double percent;

  final SProgressBarThickness thickness;

  /// Qué mide la barra, para el lector de pantalla ("Avance de pago"). El
  /// porcentaje se anuncia siempre.
  final String? semanticsLabel;

  const SProgressBar({
    super.key,
    required this.percent,
    this.thickness = SProgressBarThickness.medium,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final style = _SProgressBarStyle.resolve(thickness: thickness, theme: t);
    final fraction = percent.clamp(0, 100) / 100;

    return Semantics(
      container: true,
      label: semanticsLabel,
      value: '${(fraction * 100).round()}%',
      child: ClipRRect(
        borderRadius: style.radius,
        child: t.motion.normal == Duration.zero
            ? _track(style, fraction)
            : TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: fraction),
                duration: _fillDuration,
                // Curva propia y no `motion.enter`: la define el llenado, no la
                // escala de movimiento.
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => _track(style, value),
              ),
      ),
    );
  }

  /// Pista con el relleno al [fraction] de su ancho (0-1).
  Widget _track(_SProgressBarStyle style, double fraction) => Container(
    height: style.height,
    color: style.track,
    child: FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: fraction,
      child: Container(color: style.fill),
    ),
  );
}

/// Apariencia ya resuelta: el único lugar del archivo que sabe de grosores.
@immutable
class _SProgressBarStyle {
  final double height;

  /// Pista sin recorrer.
  final Color track;

  /// Parte recorrida.
  final Color fill;

  final BorderRadius radius;

  const _SProgressBarStyle({
    required this.height,
    required this.track,
    required this.fill,
    required this.radius,
  });

  factory _SProgressBarStyle.resolve({
    required SProgressBarThickness thickness,
    required SozuTheme theme,
  }) {
    final height = switch (thickness) {
      SProgressBarThickness.thin => _thinHeight,
      SProgressBarThickness.medium => _mediumHeight,
      SProgressBarThickness.thick => _thickHeight,
    };
    return _SProgressBarStyle(
      height: height,
      // `muted` es el rol de relleno inerte, y la pista de una barra es su
      // ejemplo canónico (ver SozuColorRoles.muted).
      track: theme.color.muted,
      fill: theme.color.primary,
      radius: theme.radius.fullBorder,
    );
  }
}
