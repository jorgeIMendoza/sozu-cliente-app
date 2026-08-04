import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_cliente_app/ui/primitives/s_button.dart';
import 'package:sozu_cliente_app/ui/primitives/s_card.dart';
import 'package:sozu_cliente_app/ui/primitives/s_error_state.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';

/// Contrato del estado de error.
///
/// Un error sin salida es una pantalla muerta: lo que se fija aquí es que el
/// reintento SIEMPRE esté y SIEMPRE dispare.
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

  testWidgets('pulsar Reintentar invoca onRetry', (tester) async {
    var reintentos = 0;
    await pump(
      tester,
      SErrorState(title: 'No cargó', onRetry: () => reintentos++),
    );

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    expect(reintentos, 1);
  });

  testWidgets('va en card y usa el botón del design system', (tester) async {
    await pump(tester, SErrorState(title: 'No cargó', onRetry: () {}));

    expect(find.byType(SCard), findsOneWidget);
    // SButton y no FilledButton: el FilledButton se pinta con el ThemeData de
    // Material y se desincroniza del resto de los botones.
    expect(find.byType(SButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('el mensaje es opcional y no altera el título', (tester) async {
    await pump(tester, SErrorState(title: 'No cargó', onRetry: () {}));
    expect(find.text('No cargó'), findsOneWidget);
    expect(find.text('Revisa tu conexión'), findsNothing);

    await pump(
      tester,
      SErrorState(
        title: 'No cargó',
        message: 'Revisa tu conexión',
        onRetry: () {},
      ),
    );
    expect(find.text('No cargó'), findsOneWidget);
    expect(find.text('Revisa tu conexión'), findsOneWidget);
  });
}
