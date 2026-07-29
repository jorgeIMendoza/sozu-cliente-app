import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';

/// [FadeSlideIn] toma su duración de `context.s.motion.slow` en vez del 450 ms
/// que traía cocido, y para leer el token tuvo que mover el arranque del
/// controller de `initState` a `didChangeDependencies`.
///
/// Eso cambia el ciclo de vida del widget, que es la parte que puede romperse en
/// silencio: si el arranque se dispara dos veces la entrada se reinicia a media
/// animación, y si no se dispara el contenido se queda invisible para siempre.
/// De ahí estos tres casos: que anime, que respete "reducir movimiento" (antes
/// no lo hacía: los 450 ms corrían igual) y que el retraso de escalonado siga
/// retrasando.
void main() {
  Widget wrap(Widget child, {bool reduce = false}) => MediaQuery(
    data: MediaQueryData(
      size: const Size(1440, 900),
      disableAnimations: reduce,
    ),
    child: MaterialApp(
      builder: (context, c) => SozuAdaptiveTokens(child: c ?? const SizedBox()),
      home: Scaffold(body: child),
    ),
  );

  double opacidad(WidgetTester t) => t
      .widget<FadeTransition>(
        find
            .descendant(
              of: find.byType(FadeSlideIn),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  testWidgets('anima de 0 a 1', (t) async {
    await t.pumpWidget(wrap(const FadeSlideIn(child: Text('hola'))));
    expect(opacidad(t), 0.0);
    await t.pump(const Duration(milliseconds: 190));
    final medio = opacidad(t);
    expect(medio, greaterThan(0.0));
    expect(medio, lessThan(1.0));
    await t.pumpAndSettle();
    expect(opacidad(t), 1.0);
  });

  testWidgets('con movimiento reducido aparece ya colocado', (t) async {
    await t.pumpWidget(
      wrap(const FadeSlideIn(child: Text('hola')), reduce: true),
    );
    await t.pump();
    expect(opacidad(t), 1.0);
  });

  testWidgets('con delay arranca despues', (t) async {
    await t.pumpWidget(
      wrap(const FadeSlideIn(delayMs: 300, child: Text('hola'))),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(opacidad(t), 0.0);
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(opacidad(t), 1.0);
  });
}
