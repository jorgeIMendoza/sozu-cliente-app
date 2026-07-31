import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_cliente_app/ui/primitives/s_card.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';
import 'package:sozu_cliente_app/ui/tokens/radii.dart';
import 'package:sozu_cliente_app/ui/tokens/spacing.dart';

/// Contrato de la superficie de card.
///
/// Lo que se fija aquí es la DIFERENCIA entre las dos variantes (la de móvil
/// flota, la del portal es plana con borde) y que los tokens salgan del tema y no
/// de literales: eso es justo lo que se perdió cuando `AppCard` y `PortalCard`
/// eran dos widgets con la sombra y el radio cocidos.
void main() {
  // 1280 px: densidad `comfortable`, o sea la escala `standard` de tokens.
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        builder: (context, c) =>
            SozuAdaptiveTokens(child: c ?? const SizedBox()),
        home: Scaffold(body: child),
      ),
    );
  }

  BoxDecoration decorationOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(of: find.byType(SCard), matching: find.byType(Container)),
    );
    return container.decoration! as BoxDecoration;
  }

  Container containerOf(WidgetTester tester) => tester.widget<Container>(
    find.descendant(of: find.byType(SCard), matching: find.byType(Container)),
  );

  testWidgets('elevated se separa del fondo: borde Y sombra', (tester) async {
    await pump(tester, const SCard(child: Text('hola')));
    final d = decorationOf(tester);

    // Las dos cosas: `AppCard` traia sombra sin borde y `PortalCard` borde sin
    // sombra. Unificarlas en una sola card significa quedarse con ambas.
    expect(d.boxShadow, isNotEmpty);
    expect(d.border, isNotNull);
    expect(d.color, SozuColorRoles.light.surface);
  });

  testWidgets('outlined es plana: borde sí, sombra no', (tester) async {
    await pump(tester, const SCard.outlined(child: Text('hola')));
    final d = decorationOf(tester);

    // Esta es la diferencia medible entre las dos variantes.
    expect(d.boxShadow, isEmpty);
    expect(d.border, isNotNull);
    expect((d.border! as Border).top.color, SozuColorRoles.light.border);
  });

  testWidgets('borderColor manda en las dos variantes', (tester) async {
    const azul = Color(0xFF0000FF);

    await pump(tester, const SCard(borderColor: azul, child: Text('hola')));
    // En elevated agrega un borde que la variante no lleva.
    expect((decorationOf(tester).border! as Border).top.color, azul);

    await pump(
      tester,
      const SCard.outlined(borderColor: azul, child: Text('hola')),
    );
    // En outlined reemplaza al borde por defecto.
    expect((decorationOf(tester).border! as Border).top.color, azul);
  });

  testWidgets('radio y padding salen de los tokens, no de literales', (
    tester,
  ) async {
    await pump(tester, const SCard(child: Text('hola')));
    final container = containerOf(tester);

    expect(
      (container.decoration! as BoxDecoration).borderRadius,
      SozuRadii.standard.lgBorder,
    );
    expect(container.padding, EdgeInsets.all(SozuSpacing.standard.md));
  });

  testWidgets('padding configurable, incluido a sangre', (tester) async {
    await pump(
      tester,
      const SCard(padding: EdgeInsets.zero, child: Text('hola')),
    );
    expect(containerOf(tester).padding, EdgeInsets.zero);
  });

  testWidgets('fullWidth ocupa el ancho del padre; false mide el contenido', (
    tester,
  ) async {
    await pump(tester, const SCard(child: SizedBox(width: 40, height: 10)));
    expect(tester.getSize(find.byType(SCard)).width, 1280);

    await pump(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: SCard(fullWidth: false, child: SizedBox(width: 40, height: 10)),
      ),
    );
    // 40 de contenido + 16 de padding y 1 de borde por lado.
    expect(tester.getSize(find.byType(SCard)).width, 40 + 2 * 16 + 2 * 1);
  });

  testWidgets('clip recorta al radio solo cuando se pide', (tester) async {
    await pump(tester, const SCard(child: Text('hola')));
    expect(containerOf(tester).clipBehavior, Clip.none);

    await pump(tester, const SCard(clip: true, child: Text('hola')));
    expect(containerOf(tester).clipBehavior, Clip.antiAlias);
  });
}
