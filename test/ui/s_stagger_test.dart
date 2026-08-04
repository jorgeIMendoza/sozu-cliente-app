import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_cliente_app/ui/primitives/s_stagger.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';
import 'package:sozu_cliente_app/ui/tokens/motion.dart';

/// Contrato de la entrada escalonada.
///
/// Los dos tests que de verdad importan son los que protegen fallas silenciosas:
/// que un rebuild NO reinicie la animación (si se rompe, la app parpadea en
/// momentos aleatorios y nadie sabe por qué) y que con "reducir movimiento" el
/// hijo se pinte sin capas intermedias (si se rompe, sigue mareando a quien pidió
/// que la interfaz no se mueva).
void main() {
  /// Envoltura mínima, SIN `MaterialApp`: sus transiciones de ruta traen sus
  /// propios `FadeTransition`, y con ellos en el árbol un `findsNothing` no
  /// prueba nada.
  ///
  /// `disableAnimations` viaja por `MediaQuery` y solo llega a
  /// `context.s.motion` porque `SozuAdaptiveTokens` lo traduce a
  /// `SozuMotion.reduced`, igual que en la app. Sin ese envoltorio el widget
  /// nunca vería la señal y el test pasaría por la razón equivocada.
  Widget host({required Widget child, bool disableAnimations = false}) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(1440, 900),
        disableAnimations: disableAnimations,
      ),
      child: Theme(
        data: sozuLightTheme(),
        child: SozuAdaptiveTokens(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  /// Solo los `FadeTransition` que pone la primitiva.
  final fade = find.descendant(
    of: find.byType(SFadeInUp),
    matching: find.byType(FadeTransition),
  );

  double opacityOf(WidgetTester tester) =>
      tester.widget<FadeTransition>(fade).opacity.value;

  group('SFadeInUp', () {
    testWidgets('arranca en opacidad 0 y termina en 1', (tester) async {
      await tester.pumpWidget(
        host(child: const SFadeInUp(child: Text('hola'))),
      );

      expect(opacityOf(tester), 0);

      // Una duración completa de `SozuMotion.normal` más un margen: al terminar,
      // el elemento está totalmente visible.
      await tester.pump(
        SozuMotion.full.normal + const Duration(milliseconds: 50),
      );
      expect(opacityOf(tester), 1);
    });

    testWidgets('con delay espera antes de empezar', (tester) async {
      await tester.pumpWidget(
        host(
          child: const SFadeInUp(
            delay: Duration(milliseconds: 200),
            child: Text('hola'),
          ),
        ),
      );

      // A la mitad del retardo todavía no arrancó.
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacityOf(tester), 0);

      // Este pump pasa el retardo y deja que el timer dispare el arranque; el
      // progreso del controlador solo avanza en los frames SIGUIENTES, así que
      // hace falta un segundo pump para llegar al final.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(
        SozuMotion.full.normal + const Duration(milliseconds: 50),
      );
      expect(opacityOf(tester), 1);
    });

    testWidgets('un rebuild NO reinicia la animación', (tester) async {
      await tester.pumpWidget(host(child: const _Rebuildable()));

      await tester.pump(
        SozuMotion.full.normal + const Duration(milliseconds: 50),
      );
      expect(opacityOf(tester), 1);

      // Rebuild forzado desde arriba, como haría un cambio de tema o un provider
      // que emite: el hijo se reconstruye pero la entrada ya ocurrió.
      await tester.tap(find.text('rebuild'));
      await tester.pump();

      expect(find.text('rebuilds: 1'), findsOneWidget);
      expect(opacityOf(tester), 1);
    });

    testWidgets('con reduced motion pinta el hijo sin capas intermedias', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          disableAnimations: true,
          child: const SFadeInUp(child: Text('hola')),
        ),
      );

      expect(find.text('hola'), findsOneWidget);

      Finder dentro(Finder matching) =>
          find.descendant(of: find.byType(SFadeInUp), matching: matching);

      expect(dentro(find.byType(FadeTransition)), findsNothing);
      expect(dentro(find.byType(Opacity)), findsNothing);
      expect(dentro(find.byType(Transform)), findsNothing);
      expect(dentro(find.byType(AnimatedBuilder)), findsNothing);
    });
  });

  group('SStaggered.delayForIndex', () {
    test('el índice 0 no espera', () {
      expect(SStaggered.delayForIndex(0), Duration.zero);
    });

    test('crece con el índice mientras no llegue al techo', () {
      final primero = SStaggered.delayForIndex(1);
      final segundo = SStaggered.delayForIndex(2);
      expect(primero, greaterThan(Duration.zero));
      expect(segundo, greaterThan(primero));
    });

    test('satura en maxDelay: el índice 50 no espera 2 segundos', () {
      const step = Duration(milliseconds: 40);
      const maxDelay = Duration(milliseconds: 320);

      final tarde = SStaggered.delayForIndex(
        50,
        step: step,
        maxDelay: maxDelay,
      );

      // Sin techo serían 50 * 40 = 2000 ms y la lista se sentiría trabada.
      expect(tarde, maxDelay);
      expect(tarde, lessThan(const Duration(milliseconds: 2000)));
    });
  });

  group('SStaggered', () {
    testWidgets('envuelve cada hijo y conserva el orden', (tester) async {
      await tester.pumpWidget(
        host(
          child: const SStaggered(
            children: [Text('uno'), Text('dos'), Text('tres')],
          ),
        ),
      );

      final envueltos = tester
          .widgetList<SFadeInUp>(find.byType(SFadeInUp))
          .toList();
      expect(envueltos.length, 3);
      expect(envueltos.map((w) => (w.child as Text).data).toList(), [
        'uno',
        'dos',
        'tres',
      ]);

      // El retardo crece con la posición: eso es el escalonado.
      expect(envueltos[0].delay, Duration.zero);
      expect(envueltos[1].delay, greaterThan(envueltos[0].delay));
      expect(envueltos[2].delay, greaterThan(envueltos[1].delay));
    });

    testWidgets('no impone scroll: no hay ListView en el árbol', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(child: const SStaggered(children: [Text('uno'), Text('dos')])),
      );

      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('con builder, el contenedor lo decide quien lo usa', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          child: SStaggered(
            children: const [Text('uno'), Text('dos')],
            builder: (context, kids) => Wrap(children: kids),
          ),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(SFadeInUp), findsNWidgets(2));
    });
  });
}

/// Padre que se reconstruye a voluntad, para probar que la entrada no se
/// reinicia. El `SFadeInUp` conserva su elemento (misma posición, mismo tipo),
/// que es exactamente el caso de un rebuild real.
class _Rebuildable extends StatefulWidget {
  const _Rebuildable();

  @override
  State<_Rebuildable> createState() => _RebuildableState();
}

class _RebuildableState extends State<_Rebuildable> {
  int _veces = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SFadeInUp(child: Text('rebuilds: $_veces')),
        // GestureDetector y no un botón de Material: este árbol de prueba no
        // tiene `Material` ancestro a propósito.
        GestureDetector(
          onTap: () => setState(() => _veces++),
          child: const Text('rebuild'),
        ),
      ],
    );
  }
}
