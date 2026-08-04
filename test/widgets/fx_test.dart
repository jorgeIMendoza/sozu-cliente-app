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
///
/// Los grupos de abajo cubren los otros dos widgets de este archivo que también
/// tenían valores cocidos: el hundido de [PressableScale] y el conteo de
/// [CountUpMoney].
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

  // [PressableScale] hundía a 0.97 cocido mientras las primitivas de `ui/`
  // hunden a `motion.pressScale` (0.975). Es una diferencia invisible en un
  // screenshot y perfectamente visible al usar la app: dos cosas que se tocan
  // igual responden distinto. El test compara contra el TOKEN, no contra 0.975,
  // para que cambiar el token no obligue a editar el test.
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
  // no tenerlo, porque pasa en el elemento más grande de la pantalla.
  group('CountUpMoney', () {
    testWidgets('anima desde 0', (t) async {
      await t.pumpWidget(wrap(const CountUpMoney(value: 1000000)));
      expect(find.text(r'$0.00'), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text(r'$1,000,000.00'), findsOneWidget);
    });

    testWidgets('con movimiento reducido muestra el total de una', (t) async {
      await t.pumpWidget(
        wrap(const CountUpMoney(value: 1000000), reduce: true),
      );
      // Sin `pumpAndSettle`: el valor final tiene que estar en el PRIMER frame.
      expect(find.text(r'$1,000,000.00'), findsOneWidget);
      // Y no queda ningún tween corriendo detrás.
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });
  });
}
