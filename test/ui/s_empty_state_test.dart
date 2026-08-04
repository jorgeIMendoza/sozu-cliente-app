import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_cliente_app/ui/primitives/s_card.dart';
import 'package:sozu_cliente_app/ui/primitives/s_empty_state.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';

/// Contrato de la variante EN CARD del estado vacío (`SEmptyState.card`).
///
/// El resto del contrato de `SEmptyState` (anclado arriba, `centered`, mensaje
/// opcional) vive en `primitives_test.dart`.
void main() {
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

  testWidgets('.card se pinta dentro de una SCard', (tester) async {
    await pump(
      tester,
      const SEmptyState.card(icon: Icons.inbox, title: 'Sin documentos'),
    );

    expect(find.byType(SCard), findsOneWidget);
    expect(find.text('Sin documentos'), findsOneWidget);
  });

  testWidgets('el constructor normal NO mete card', (tester) async {
    await pump(
      tester,
      const SEmptyState(icon: Icons.inbox, title: 'Sin documentos'),
    );

    // Son el mismo widget: si la card se colara siempre, cada pantalla que ya
    // envuelve el vacío quedaría con dos superficies anidadas.
    expect(find.byType(SCard), findsNothing);
  });

  testWidgets('.card ignora el anclaje arriba y se mide por su contenido', (
    tester,
  ) async {
    await pump(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: SEmptyState.card(icon: Icons.inbox, title: 'Sin documentos'),
      ),
    );

    // Sin card el bloque lleva un margen superior responsive de 32/48 px; dentro
    // de la card ese margen es el padding de la card, no un hueco extra.
    final cardTop = tester.getTopLeft(find.byType(SCard)).dy;
    expect(cardTop, 0);
    expect(tester.getSize(find.byType(SCard)).height, lessThan(300));
  });
}
