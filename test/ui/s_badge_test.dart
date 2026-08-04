import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/primitives/s_badge.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';

/// Contrato de la insignia de estatus.
///
/// Lo que se fija aquí es lo que un refactor rompe en silencio: que los cuatro
/// tonos sigan siendo distinguibles a la vista, que el rojo y el ámbar usen el
/// rol de TEXTO (contraste AA) y no el relleno, y que el fondo sea opaco - un
/// tono translúcido se ve bien sobre blanco y se ensucia sobre `surfaceAlt`.
void main() {
  const light = SozuColorRoles.light;
  const dark = SozuColorRoles.dark;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark
            ? sozuDarkTheme()
            : sozuLightTheme(),
        builder: (context, c) =>
            SozuAdaptiveTokens(child: c ?? const SizedBox()),
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
  }

  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<Container>(
                find.descendant(
                  of: find.byType(SBadge),
                  matching: find.byType(Container),
                ),
              )
              .decoration
          as BoxDecoration;

  Color? textColorOf(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  group('tonos', () {
    testWidgets('los cuatro tonos dan fondo Y texto distintos entre sí', (
      tester,
    ) async {
      final fondos = <Color>[];
      final textos = <Color>[];

      for (final tone in SBadgeTone.values) {
        await pump(tester, SBadge(label: 'Estatus', tone: tone));
        fondos.add(decorationOf(tester).color!);
        textos.add(textColorOf(tester, 'Estatus')!);
      }

      // Un refactor que colapse dos tonos en el mismo par de roles deja la
      // pantalla igual de bonita y sin decir nada: cuatro estatus, un color.
      expect(fondos.toSet(), hasLength(SBadgeTone.values.length));
      expect(textos.toSet(), hasLength(SBadgeTone.values.length));
    });

    testWidgets('en tema oscuro también son cuatro colores distintos', (
      tester,
    ) async {
      final fondos = <Color>[];
      for (final tone in SBadgeTone.values) {
        await pump(
          tester,
          SBadge(label: 'Estatus', tone: tone),
          brightness: Brightness.dark,
        );
        fondos.add(decorationOf(tester).color!);
      }
      expect(fondos.toSet(), hasLength(SBadgeTone.values.length));
      // Y son los del set oscuro, no los del claro pintados sobre negro.
      expect(fondos.first, dark.primarySoftStrong);
      expect(dark.primarySoftStrong, isNot(light.primarySoftStrong));
    });

    testWidgets('positive usa el par de marca', (tester) async {
      await pump(
        tester,
        const SBadge(label: 'Pagado', tone: SBadgeTone.positive),
      );
      // `primarySoftStrong` (10%) y no `primarySoft` (6%): los cuatro tonos
      // comparten nivel de tinte, si no el verde se ve lavado al lado del ambar.
      expect(decorationOf(tester).color, light.primarySoftStrong);
      expect(textColorOf(tester, 'Pagado'), light.primaryHover);
    });

    testWidgets('pending usa warningFg, no el ámbar de relleno', (
      tester,
    ) async {
      await pump(
        tester,
        const SBadge(label: 'Pendiente', tone: SBadgeTone.pending),
      );
      expect(decorationOf(tester).color, light.warningSoft);
      // `warning` (el relleno) no alcanza AA en 12 px sobre `warningSoft`.
      expect(textColorOf(tester, 'Pendiente'), light.warningFg);
      expect(textColorOf(tester, 'Pendiente'), isNot(light.warning));
    });

    testWidgets('negative usa dangerSoft OPACO, no danger con alpha', (
      tester,
    ) async {
      await pump(
        tester,
        const SBadge(label: 'Vencido', tone: SBadgeTone.negative),
      );
      final bg = decorationOf(tester).color!;
      expect(bg, light.dangerSoft);
      // El fondo translúcido de la versión legacy (`danger` al 10 %) se
      // compone con lo que haya detrás: sobre `surfaceAlt` sale gris sucio.
      expect(bg.a, 1.0);
      expect(textColorOf(tester, 'Vencido'), light.danger);
    });

    testWidgets('neutral no se tiñe de marca', (tester) async {
      await pump(tester, const SBadge(label: 'Otro'));
      expect(decorationOf(tester).color, light.surfaceAlt);
      expect(textColorOf(tester, 'Otro'), light.fgMuted);
    });

    testWidgets('el tono por defecto es neutral', (tester) async {
      // Un estatus desconocido no debe leerse como "todo bien".
      expect(const SBadge(label: 'Otro').tone, SBadgeTone.neutral);
    });
  });

  group('forma y tamaños', () {
    testWidgets('es una pill: radio full', (tester) async {
      await pump(tester, const SBadge(label: 'Pagado'));
      expect(
        decorationOf(tester).borderRadius,
        SozuTheme.light.radius.fullBorder,
      );
    });

    testWidgets('se ajusta al contenido, no al ancho disponible', (
      tester,
    ) async {
      await pump(tester, const SBadge(label: 'Ok'));
      expect(tester.getSize(find.byType(SBadge)).width, lessThan(200));
    });

    testWidgets('sm es más chica que md en alto y en ancho', (tester) async {
      await pump(tester, const SBadge(label: 'Pendiente', size: SBadgeSize.sm));
      final sm = tester.getSize(find.byType(SBadge));

      await pump(tester, const SBadge(label: 'Pendiente', size: SBadgeSize.md));
      final md = tester.getSize(find.byType(SBadge));

      expect(sm.width, lessThan(md.width));
      expect(sm.height, lessThan(md.height));
    });

    testWidgets('el tamaño por defecto es md', (tester) async {
      expect(const SBadge(label: 'X').size, SBadgeSize.md);
    });
  });

  group('icono', () {
    testWidgets('sin icono no monta ninguno', (tester) async {
      await pump(tester, const SBadge(label: 'Pagado'));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('el icono va a la izquierda del texto y en su mismo color', (
      tester,
    ) async {
      await pump(
        tester,
        const SBadge(
          label: 'Vencido',
          tone: SBadgeTone.negative,
          icon: Icons.error_outline,
        ),
      );

      expect(
        tester.getCenter(find.byIcon(Icons.error_outline)).dx,
        lessThan(tester.getCenter(find.text('Vencido')).dx),
      );
      // Un icono de otro color rompe la lectura del chip como una sola pieza.
      expect(
        tester.widget<Icon>(find.byType(Icon)).color,
        textColorOf(tester, 'Vencido'),
      );
    });

    testWidgets('el icono ensancha la insignia', (tester) async {
      await pump(tester, const SBadge(label: 'Vencido'));
      final sinIcono = tester.getSize(find.byType(SBadge)).width;

      await pump(
        tester,
        const SBadge(label: 'Vencido', icon: Icons.error_outline),
      );
      expect(tester.getSize(find.byType(SBadge)).width, greaterThan(sinIcono));
    });
  });

  testWidgets('el label se pinta tal cual, sin recortes', (tester) async {
    await pump(tester, const SBadge(label: 'Pago en revisión'));
    expect(find.text('Pago en revisión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
