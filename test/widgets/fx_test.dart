import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';

/// Lo que queda vivo de `widgets/fx.dart`. [FadeSlideIn] y [CountUpMoney] se
/// borraron el 2026-08-20: no los usaba nadie en `lib/`, solo estas pruebas.
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

  group('PressableScale', () {
    double escala(WidgetTester t) => t
        .widget<AnimatedScale>(
          find.descendant(
            of: find.byType(PressableScale),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;

    testWidgets('hunde con el factor del token', (t) async {
      await t.pumpWidget(
        wrap(PressableScale(onTap: () {}, child: const Text('toca'))),
      );
      expect(escala(t), 1.0);

      // El gesto se mantiene apretado: el hundido solo existe entre el down y
      // el up, así que soltar aquí devolvería la escala a 1 antes de medirla.
      final gesto = await t.startGesture(t.getCenter(find.text('toca')));
      await t.pump();
      expect(escala(t), SozuMotion.full.pressScale);

      await gesto.up();
      await t.pumpAndSettle();
      expect(escala(t), 1.0);
    });

    testWidgets('con movimiento reducido no hunde', (t) async {
      await t.pumpWidget(
        wrap(
          PressableScale(onTap: () {}, child: const Text('toca')),
          reduce: true,
        ),
      );
      final gesto = await t.startGesture(t.getCenter(find.text('toca')));
      await t.pump();
      // `SozuMotion.reduced.pressScale` es 1.0: el mismo código deja de hundir
      // sin una rama `if (reduceMotion)` en el widget.
      expect(escala(t), 1.0);
      await gesto.up();
    });
  });

  // El conteo de la cifra hero no respetaba "reducir movimiento": los 900 ms
  // corrían igual. Contar dígitos es movimiento, y de los peores para quien pidió
}
