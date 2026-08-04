import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/primitives/s_pressable.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';
import 'package:sozu_cliente_app/ui/tokens/elevation.dart';
import 'package:sozu_cliente_app/ui/tokens/motion.dart';

/// Monta el widget con los tokens del design system resueltos.
///
/// El contenido va CENTRADO y no en la esquina: el puntero de prueba nace en
/// `Offset.zero`, y con el widget pegado al origen empezaría hovereado, así que
/// no habría forma de medir el estado de reposo.
Future<void> pump(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: sozuLightTheme(),
      builder: (context, c) {
        // El MediaQuery va POR ENCIMA de SozuAdaptiveTokens: es ahí donde se lee
        // `disableAnimations` para elegir SozuMotion.reduced.
        final tokens = SozuAdaptiveTokens(child: c ?? const SizedBox());
        if (!reduceMotion) return tokens;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: tokens,
        );
      },
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  );
}

/// Fila de prueba: contenido mínimo para que la superficie tenga tamaño.
Widget fila({
  required VoidCallback? onTap,
  bool hoverLift = false,
  bool pressScale = true,
  String? semanticLabel,
  bool isNavigation = false,
  FocusNode? focusNode,
}) => SPressable(
  onTap: onTap,
  hoverLift: hoverLift,
  pressScale: pressScale,
  semanticLabel: semanticLabel,
  isNavigation: isNavigation,
  focusNode: focusNode,
  child: const SizedBox(height: 56, width: 320, child: Text('Fila')),
);

/// Decoración REALMENTE pintada, no la de destino.
///
/// `AnimatedContainer.decoration` es el valor al que va, así que sirve para el
/// estado final pero miente a mitad de la transición. El `DecoratedBox` que
/// cuelga de él sí tiene el valor interpolado del frame actual, que es lo único
/// que permite distinguir una animación de un salto.
BoxDecoration paintedDecoration(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(AnimatedContainer),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return box.decoration as BoxDecoration;
}

double scaleOf(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

/// Deja el puntero del mouse encima del widget.
///
/// Hace falta un puntero real (`createGesture`) y no un evento sintético: el
/// `MouseTracker` solo reporta hover para punteros que dio de alta.
Future<TestGesture> hover(WidgetTester tester, {Finder? on}) async {
  final target = on ?? find.byType(SPressable);
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(target));
  return gesture;
}

void main() {
  const light = SozuColorRoles.light;
  const shadows = SozuElevation.light;
  const motion = SozuMotion.full;

  group('hover', () {
    testWidgets('en reposo no pinta fondo y en hover usa surfaceAlt', (
      tester,
    ) async {
      await pump(tester, fila(onTap: () {}));
      expect(paintedDecoration(tester).color, Colors.transparent);

      await hover(tester);
      await tester.pumpAndSettle();

      // Este es el cambio que hoy no existe en casi ninguna fila de la app: sin
      // él nada indica que la fila se puede tocar antes de tocarla.
      expect(paintedDecoration(tester).color, light.surfaceAlt);
    });

    testWidgets('el hoverColor explícito manda sobre el default', (
      tester,
    ) async {
      await pump(
        tester,
        SPressable(
          onTap: () {},
          hoverColor: light.primarySoft,
          child: const SizedBox(height: 56, width: 320),
        ),
      );

      await hover(tester);
      await tester.pumpAndSettle();
      expect(paintedDecoration(tester).color, light.primarySoft);
    });

    testWidgets('el cambio de color es ANIMADO, no un salto', (tester) async {
      await pump(tester, fila(onTap: () {}));
      await hover(tester);
      // Primer frame: se registra el hover y arranca la transición.
      await tester.pump();
      // Mitad de la duración: si el color fuera un salto ya estaría en el final.
      await tester.pump(motion.instant ~/ 2);

      final mid = paintedDecoration(tester).color!;
      expect(mid, isNot(Colors.transparent));
      expect(mid, isNot(light.surfaceAlt));
      // Interpolar desde transparente pasa por alfas intermedios. Un salto daría
      // exactamente 0 o exactamente 1.
      expect(mid.a, greaterThan(0));
      expect(mid.a, lessThan(1));
    });

    testWidgets('onTap null no reacciona al hover', (tester) async {
      await pump(tester, fila(onTap: null));
      await hover(tester);
      await tester.pumpAndSettle();

      // Una superficie muerta que igual se ilumina es peor que una que no
      // parece tocable: promete una acción que no va a pasar.
      expect(paintedDecoration(tester).color, Colors.transparent);
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    });
  });

  group('press', () {
    testWidgets('hunde al presionar y vuelve al soltar', (tester) async {
      await pump(tester, fila(onTap: () {}));
      expect(scaleOf(tester), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SPressable)),
      );
      await tester.pump();
      expect(scaleOf(tester), motion.pressScale);
      expect(scaleOf(tester), lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleOf(tester), 1);
    });

    testWidgets('pressScale false no hunde', (tester) async {
      await pump(tester, fila(onTap: () {}, pressScale: false));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SPressable)),
      );
      await tester.pump();
      expect(scaleOf(tester), 1);
      await gesture.up();
    });

    testWidgets('dispara onTap y onLongPress', (tester) async {
      var taps = 0;
      var longPresses = 0;
      await pump(
        tester,
        SPressable(
          onTap: () => taps++,
          onLongPress: () => longPresses++,
          child: const SizedBox(height: 56, width: 320),
        ),
      );

      await tester.tap(find.byType(SPressable));
      await tester.pumpAndSettle();
      expect(taps, 1);

      await tester.longPress(find.byType(SPressable));
      await tester.pumpAndSettle();
      expect(longPresses, 1);
      expect(taps, 1);
    });
  });

  group('hoverLift', () {
    testWidgets('true sube la sombra de sm a md', (tester) async {
      await pump(tester, fila(onTap: () {}, hoverLift: true));
      expect(paintedDecoration(tester).boxShadow, shadows.sm);

      await hover(tester);
      await tester.pumpAndSettle();
      expect(paintedDecoration(tester).boxShadow, shadows.md);
    });

    testWidgets('false no toca la sombra en ningún estado', (tester) async {
      await pump(tester, fila(onTap: () {}));
      // `null` y no lista vacía: una fila no debe recibir sombra ni siquiera
      // vacía, porque en una lista una sombra que sube se lee como si la fila se
      // despegara de sus vecinas.
      expect(paintedDecoration(tester).boxShadow, isNull);

      await hover(tester);
      await tester.pumpAndSettle();
      expect(paintedDecoration(tester).boxShadow, isNull);
    });
  });

  group('teclado', () {
    testWidgets('Enter activa la superficie enfocada', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var taps = 0;

      await pump(tester, fila(onTap: () => taps++, focusNode: node));
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Esta es la razón de usar InkWell y no GestureDetector: con el gesture
      // detector la fila no es enfocable y con teclado no hay forma de abrirla.
      expect(taps, 1);
    });

    testWidgets('el foco resalta igual que el hover', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pump(tester, fila(onTap: () {}, focusNode: node));

      node.requestFocus();
      await tester.pumpAndSettle();
      // Puntero y teclado son la misma idea ("este es el elemento apuntado"), así
      // que se pintan igual: quien navega con teclado no tiene que aprender otro
      // lenguaje visual.
      expect(paintedDecoration(tester).color, light.surfaceAlt);
    });

    testWidgets('onTap null no toma foco', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pump(tester, fila(onTap: null, focusNode: node));

      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
    });
  });

  group('reducir movimiento', () {
    testWidgets('no hunde al presionar', (tester) async {
      await pump(tester, fila(onTap: () {}), reduceMotion: true);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SPressable)),
      );
      await tester.pump();

      // El hundido es movimiento, y quien pidió no moverse ya lo pidió una vez.
      expect(scaleOf(tester), 1);
      await gesture.up();
    });

    testWidgets('el color de hover SIGUE cambiando', (tester) async {
      await pump(tester, fila(onTap: () {}), reduceMotion: true);
      expect(paintedDecoration(tester).color, Colors.transparent);

      await hover(tester);
      // Un solo frame y sin settle: con duración cero el color ya está en el
      // valor final, no a mitad de camino.
      await tester.pump();

      // Lo que se apaga es la interpolación, NO la información: el color dice
      // "esto se puede tocar", y quitarlo dejaría la fila indistinguible de un
      // bloque de texto.
      expect(paintedDecoration(tester).color, light.surfaceAlt);
    });
  });

  group('semantica', () {
    testWidgets('semanticLabel null NO agrega nodo con label vacío', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, fila(onTap: () {}));

      // Sin etiqueta no se envuelve nada: un Semantics con label vacío se fusiona
      // con los hijos y el lector anuncia un control anónimo en lugar del
      // contenido de la fila.
      expect(
        find.descendant(
          of: find.byType(SPressable),
          matching: find.byType(MergeSemantics),
        ),
        findsNothing,
      );
      // La semántica sigue siendo la del hijo.
      expect(tester.getSemantics(find.text('Fila')).label, 'Fila');
      handle.dispose();
    });

    testWidgets('con semanticLabel se anuncia como un solo botón', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, fila(onTap: () {}, semanticLabel: 'Abrir fila'));

      final node = tester.getSemantics(find.byType(SPressable));
      expect(node.label, 'Abrir fila');
      // El hijo se excluye: sin eso el lector diría "Fila, botón Abrir fila".
      expect(node.label, isNot(contains('Fila,')));
      handle.dispose();
    });

    testWidgets('isNavigation se anuncia como ENLACE', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        fila(onTap: () {}, semanticLabel: 'Ver propiedad', isNavigation: true),
      );

      expect(
        tester.getSemantics(find.byType(SPressable)),
        matchesSemantics(
          label: 'Ver propiedad',
          isLink: true,
          isButton: false,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });
  });

  group('SHoverBuilder', () {
    testWidgets('dentro de un SPressable lee el hover de la superficie', (
      tester,
    ) async {
      var visto = false;
      await pump(
        tester,
        SPressable(
          onTap: () {},
          child: SizedBox(
            height: 56,
            width: 320,
            child: SHoverBuilder(
              builder: (context, isHovered) {
                visto = isHovered;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      expect(visto, isFalse);

      await hover(tester);
      await tester.pumpAndSettle();
      // Reusa el estado de la fila entera: el chevron se enciende con el puntero
      // en cualquier parte de la fila, no solo encima del chevron.
      expect(visto, isTrue);
    });

    testWidgets('suelto detecta su propio hover', (tester) async {
      var visto = false;
      await pump(
        tester,
        SHoverBuilder(
          builder: (context, isHovered) {
            visto = isHovered;
            return const SizedBox(height: 56, width: 320);
          },
        ),
      );

      await hover(tester, on: find.byType(SHoverBuilder));
      await tester.pumpAndSettle();
      expect(visto, isTrue);
    });
  });

  group('SPressable.detector', () {
    testWidgets('expone hover y press al builder', (tester) async {
      bool? hovered;
      bool? pressed;
      await pump(
        tester,
        SPressable.detector(
          builder: (context, h, p) {
            hovered = h;
            pressed = p;
            // ColoredBox y no SizedBox pelón: una caja vacía no participa del
            // hit test, así que el `pointer down` no llegaría al Listener (el
            // hover sí, porque lo resuelve el MouseTracker aparte).
            return const ColoredBox(
              color: Colors.white,
              child: SizedBox(height: 56, width: 320),
            );
          },
        ),
      );
      expect(hovered, isFalse);
      expect(pressed, isFalse);

      final target = find.byType(SPressable);
      final gesture = await hover(tester, on: target);
      await tester.pump();
      expect(hovered, isTrue);

      await gesture.down(tester.getCenter(target));
      await tester.pump();
      expect(pressed, isTrue);

      await gesture.up();
      await tester.pump();
      expect(pressed, isFalse);
      expect(hovered, isTrue);
    });
  });
}
