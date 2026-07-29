import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/ui/theme/page_transitions.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';
import 'package:sozu_cliente_app/ui/tokens/motion.dart';

/// Contrato de la transición de página.
///
/// Lo que estos tests protegen no es "que anime", es que la FORMA de la
/// animación dependa del formato de pantalla (deslizamiento solo donde hay pila
/// de navegación) y que la señal de "reducir movimiento" llegue hasta acá. Las
/// dos cosas se rompen en silencio: nadie abre un bug porque el escritorio se
/// desliza de más.
///
/// La animación se controla con [AlwaysStoppedAnimation] en vez de un
/// `AnimationController`: la transición es una función pura del valor de la
/// animación, así que fijar el valor en 0.5 es exactamente "a mitad del
/// recorrido" y sin depender de cuántos frames bombee el tester.
void main() {
  /// Marca la raíz de lo que devuelve `sozuPageTransition`. Los finders se acotan
  /// a este subárbol: `MaterialApp` mete sus propias transiciones de ruta
  /// (`ZoomPageTransitionsBuilder` trae `FadeTransition` adentro), así que un
  /// `findsNothing` global no probaría nada.
  const raiz = ValueKey('raiz-transicion');
  const hijo = ValueKey('hijo-pagina');

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    required double t,
    double secundaria = 0.0,
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: disableAnimations),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: Builder(
            builder: (context) => KeyedSubtree(
              key: raiz,
              child: sozuPageTransition(
                context,
                AlwaysStoppedAnimation<double>(t),
                AlwaysStoppedAnimation<double>(secundaria),
                const SizedBox.expand(key: hijo),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Centro del hijo, no su esquina: la escala de entrada (0.98) es respecto al
  /// centro, así que mueve la esquina izquierda unos píxeles aunque NO haya
  /// desplazamiento. Comparar centros aísla la traslación de la escala, que es
  /// justo lo que se quiere distinguir.
  Future<double> centroXCon(
    WidgetTester tester, {
    required Size size,
    required double t,
  }) async {
    await pump(tester, size: size, t: t);
    return tester.getCenter(find.byKey(hijo)).dx;
  }

  Finder dentroDeRaiz(Type tipo) =>
      find.descendant(of: find.byKey(raiz), matching: find.byType(tipo));

  const escritorio = Size(1280, 900);
  const movil = Size(360, 780);

  group('escritorio (1280 px)', () {
    testWidgets('fade + escala, sin deslizamiento', (tester) async {
      await pump(tester, size: escritorio, t: 0.5);

      expect(dentroDeRaiz(FadeTransition), findsWidgets);
      expect(dentroDeRaiz(ScaleTransition), findsOneWidget);
      // El deslizamiento pertenece a móvil: en escritorio el usuario hizo clic
      // en la sidebar, la pantalla no "viene de un lado".
      expect(dentroDeRaiz(SlideTransition), findsNothing);
    });

    testWidgets('el centro NO se mueve en horizontal', (tester) async {
      final mitad = await centroXCon(tester, size: escritorio, t: 0.5);
      final fin = await centroXCon(tester, size: escritorio, t: 1.0);
      expect(mitad, closeTo(fin, 0.01));
    });

    testWidgets('la escala arranca por debajo de 1 y termina en 1', (
      tester,
    ) async {
      await pump(tester, size: escritorio, t: 0.0);
      final inicial = tester.getSize(find.byKey(hijo));
      final pintadoInicial = tester.getRect(find.byKey(hijo));
      // El hijo mide lo mismo (la escala es de pintado, no de layout); lo que
      // cambia es el rect proyectado.
      expect(inicial.width, escritorio.width);
      expect(pintadoInicial.width, lessThan(escritorio.width));

      await pump(tester, size: escritorio, t: 1.0);
      expect(
        tester.getRect(find.byKey(hijo)).width,
        closeTo(escritorio.width, 0.01),
      );
    });
  });

  group('móvil (360 px)', () {
    testWidgets('fade + deslizamiento horizontal', (tester) async {
      await pump(tester, size: movil, t: 0.5);

      expect(dentroDeRaiz(FadeTransition), findsWidgets);
      expect(dentroDeRaiz(SlideTransition), findsOneWidget);
      expect(dentroDeRaiz(ScaleTransition), findsNothing);
    });

    testWidgets('el centro SÍ se mueve, y viene de la derecha', (tester) async {
      final mitad = await centroXCon(tester, size: movil, t: 0.5);
      final fin = await centroXCon(tester, size: movil, t: 1.0);
      expect(mitad, greaterThan(fin));
      // 6% del ancho es el recorrido total: a mitad de la curva de entrada ya se
      // consumió buena parte, así que basta con que quede por debajo del tope.
      expect(mitad - fin, lessThanOrEqualTo(movil.width * 0.06 + 0.01));
    });

    testWidgets('en t = 0 arranca desplazado 6% del ancho', (tester) async {
      final inicio = await centroXCon(tester, size: movil, t: 0.0);
      final fin = await centroXCon(tester, size: movil, t: 1.0);
      expect(inicio - fin, closeTo(movil.width * 0.06, 0.01));
    });
  });

  group('la página que se queda atrás se atenúa', () {
    /// Opacidad de la capa EXTERNA: es la que maneja `secondaryAnimation`. En
    /// orden de descendencia es la primera que se encuentra bajo la raíz.
    double opacidadExterna(WidgetTester tester) => tester
        .widgetList<FadeTransition>(dentroDeRaiz(FadeTransition))
        .first
        .opacity
        .value;

    testWidgets('sin segunda animación no toca la opacidad', (tester) async {
      await pump(tester, size: escritorio, t: 1.0);
      expect(opacidadExterna(tester), closeTo(1.0, 0.001));
    });

    testWidgets('tapada por completo queda atenuada, no invisible', (
      tester,
    ) async {
      await pump(tester, size: escritorio, t: 1.0, secundaria: 1.0);
      final opacidad = opacidadExterna(tester);
      // Atenuada: si se quedara en 1.0 las dos páginas competirían a opacidad
      // completa a mitad del recorrido.
      expect(opacidad, lessThan(1.0));
      // Pero NO en 0: la que entra no tapa todo mientras se mueve, y el hueco
      // mostraría el color del scaffold como un destello.
      expect(opacidad, greaterThan(0.0));
    });
  });

  group('reducir animaciones', () {
    testWidgets('la duración es cero y el árbol queda pelón', (tester) async {
      Duration? duracion;
      tester.view.physicalSize = escritorio;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: escritorio, disableAnimations: true),
          child: MaterialApp(
            theme: sozuLightTheme(),
            builder: (context, child) =>
                SozuAdaptiveTokens(child: child ?? const SizedBox()),
            home: Builder(
              builder: (context) {
                duracion = sozuPageTransitionDuration(context);
                return KeyedSubtree(
                  key: raiz,
                  child: sozuPageTransition(
                    context,
                    const AlwaysStoppedAnimation<double>(0.5),
                    const AlwaysStoppedAnimation<double>(0.0),
                    const SizedBox.expand(key: hijo),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(duracion, Duration.zero);
      // Ni opacidad ni transform propios: una capa de composición por pantalla
      // que no se usa sigue costando, y quien pidió que nada se mueva no tiene
      // por qué pagarla.
      expect(dentroDeRaiz(FadeTransition), findsNothing);
      expect(dentroDeRaiz(Transform), findsNothing);
      expect(dentroDeRaiz(ScaleTransition), findsNothing);
      expect(dentroDeRaiz(SlideTransition), findsNothing);
      expect(find.byKey(hijo), findsOneWidget);
    });

    testWidgets('con animaciones activas la duración sale del token', (
      tester,
    ) async {
      Duration? duracion;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: escritorio),
          child: MaterialApp(
            theme: sozuLightTheme(),
            builder: (context, child) =>
                SozuAdaptiveTokens(child: child ?? const SizedBox()),
            home: Builder(
              builder: (context) {
                duracion = sozuPageTransitionDuration(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      // Contra el TOKEN, no contra un número: si mañana `normal` cambia, la
      // transición debe seguirlo sin tocar este test.
      expect(duracion, SozuMotion.full.normal);
    });
  });

  group('navegación real con GoRouter', () {
    testWidgets('ir y volver entre dos rutas no lanza excepciones', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/uno',
        routes: [
          GoRoute(
            path: '/uno',
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              transitionDuration: sozuPageTransitionDuration(context),
              reverseTransitionDuration: sozuPageTransitionDuration(context),
              transitionsBuilder: sozuPageTransition,
              child: Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => context.push('/dos'),
                    child: const Text('ir a dos'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/dos',
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              transitionDuration: sozuPageTransitionDuration(context),
              reverseTransitionDuration: sozuPageTransitionDuration(context),
              transitionsBuilder: sozuPageTransition,
              child: const Scaffold(body: Center(child: Text('pantalla dos'))),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          theme: sozuLightTheme(),
          routerConfig: router,
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ir a dos'));
      await tester.pumpAndSettle();
      expect(find.text('pantalla dos'), findsOneWidget);

      // El regreso usa la misma duración (el default de 300 ms de go_router
      // ignoraría el token).
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('ir a dos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
