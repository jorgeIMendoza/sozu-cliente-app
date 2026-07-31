import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/primitives/s_progress_bar.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';
import 'package:sozu_cliente_app/ui/tokens/radii.dart';

/// Contrato de [SProgressBar].
///
/// Lo que de verdad importa: que con "reducir movimiento" NO haya barrido (se
/// rompe sin que nadie lo note hasta que marea a alguien), que el porcentaje se
/// recorte (los 8 sitios legacy le pasan valores calculados) y que los colores
/// salgan de los roles, porque un verde crudo se rompe en silencio en tema
/// oscuro.

/// Tema creado UNA vez: `SozuTheme` no implementa `==`, así que un `ThemeData`
/// nuevo por test dispara la transición de 200 ms del `AnimatedTheme` interno de
/// `MaterialApp` y contaría como animación corriendo.
final ThemeData _theme = sozuLightTheme();

/// Monta [child] con los tokens resueltos en un ancho fijo de 200 px.
Future<void> pump(
  WidgetTester tester,
  Widget child, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(1440, 900),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp(
        theme: _theme,
        builder: (context, c) =>
            SozuAdaptiveTokens(child: c ?? const SizedBox()),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 200, child: child),
          ),
        ),
      ),
    ),
  );
}

/// Las dos cajas pintadas, en orden: pista y relleno.
Finder boxes() => find.descendant(
  of: find.byType(SProgressBar),
  matching: find.byType(Container),
);

/// Fracción del ancho que ocupa el relleno en este frame (0-1).
double fillFactor(WidgetTester tester) => tester
    .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
    .widthFactor!;

/// Ancho pintado del relleno en px.
double fillWidth(WidgetTester tester) => tester.getSize(boxes().at(1)).width;

Color colorOf(WidgetTester tester, int index) =>
    tester.widget<Container>(boxes().at(index)).color!;

void main() {
  const light = SozuColorRoles.light;

  group('reducir movimiento', () {
    testWidgets('muestra el valor final en el primer frame, sin animar', (
      tester,
    ) async {
      await pump(
        tester,
        const SProgressBar(percent: 40),
        disableAnimations: true,
      );

      // Sin `pumpAndSettle`: el valor final tiene que estar YA.
      expect(fillFactor(tester), closeTo(0.4, 0.0001));
      expect(fillWidth(tester), closeTo(80, 0.01));
      // Y no queda ningún tween corriendo detrás.
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('con movimiento normal SÍ barre de 0 al valor', (tester) async {
      await pump(tester, const SProgressBar(percent: 40));

      // El barrido arranca en 0: es el efecto, no un estado intermedio.
      expect(fillFactor(tester), 0);
      await tester.pump(const Duration(milliseconds: 200));
      final medio = fillFactor(tester);
      expect(medio, greaterThan(0));
      expect(medio, lessThan(0.4));

      await tester.pumpAndSettle();
      expect(fillFactor(tester), closeTo(0.4, 0.0001));
    });
  });

  group('percent', () {
    testWidgets('recorta por arriba de 100', (tester) async {
      await pump(
        tester,
        const SProgressBar(percent: 140),
        disableAnimations: true,
      );

      // Sin clamp, FractionallySizedBox pinta 280 px dentro de 200 y Flutter
      // denuncia overflow.
      expect(fillFactor(tester), 1);
      expect(fillWidth(tester), 200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('recorta por abajo de 0', (tester) async {
      await pump(
        tester,
        const SProgressBar(percent: -20),
        disableAnimations: true,
      );

      expect(fillFactor(tester), 0);
      expect(fillWidth(tester), 0);
    });

    testWidgets('sigue siendo escala 0-100, no 0-1', (tester) async {
      // Los 8 sitios legacy pasan porcentajes: un 25 debe leerse como 25%, no
      // como 2500%.
      await pump(
        tester,
        const SProgressBar(percent: 25),
        disableAnimations: true,
      );

      expect(fillWidth(tester), closeTo(50, 0.01));
    });
  });

  group('grosor', () {
    double heightOf(WidgetTester tester) =>
        tester.getSize(find.byType(SProgressBar)).height;

    testWidgets('las tres variantes miden distinto', (tester) async {
      final alturas = <SProgressBarThickness, double>{};
      for (final t in SProgressBarThickness.values) {
        await pump(
          tester,
          SProgressBar(percent: 50, thickness: t),
          disableAnimations: true,
        );
        alturas[t] = heightOf(tester);
      }

      expect(
        alturas[SProgressBarThickness.thin]!,
        lessThan(alturas[SProgressBarThickness.medium]!),
      );
      expect(
        alturas[SProgressBarThickness.medium]!,
        lessThan(alturas[SProgressBarThickness.thick]!),
      );
      // Las medidas de los sitios de uso legacy: 3 px la fina del portal, 8 px
      // la del portal, 10 px la de móvil.
      expect(alturas.values, containsAll(<double>[3, 8, 10]));
    });

    testWidgets('el default es la de 8 px', (tester) async {
      await pump(
        tester,
        const SProgressBar(percent: 50),
        disableAnimations: true,
      );

      expect(heightOf(tester), 8);
    });
  });

  group('colores y forma', () {
    testWidgets('pista y relleno salen de los roles muted y primary', (
      tester,
    ) async {
      await pump(
        tester,
        const SProgressBar(percent: 50),
        disableAnimations: true,
      );

      // El legacy pintaba `SozuBrand.green500` cocido y una pista en
      // `surfaceAlt`; si alguno reaparece, el tema oscuro se rompe en silencio.
      expect(colorOf(tester, 0), light.muted);
      expect(colorOf(tester, 1), light.primary);
    });

    testWidgets('el radio es el token full, no un 999 literal', (tester) async {
      await pump(
        tester,
        const SProgressBar(percent: 50),
        disableAnimations: true,
      );

      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(SProgressBar),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(SozuRadii.standard.full));
    });
  });

  group('accesibilidad', () {
    testWidgets('anuncia el porcentaje ya recortado', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const SProgressBar(percent: 140, semanticsLabel: 'Avance de pago'),
        disableAnimations: true,
      );

      expect(
        tester.getSemantics(find.byType(SProgressBar)),
        matchesSemantics(label: 'Avance de pago', value: '100%'),
      );
      handle.dispose();
    });
  });
}
