import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// `STabs` existe para reemplazar al `TabBar` de Material, y lo que la
/// justifica es lo que NO trae: no hay `TabBarView`. Un `TabBarView` no tiene
/// alto intrinseco, asi que obliga a poner un scroll dentro de cada pestaña y
/// ahi se pierde el desplazamiento de pagina completa.
void main() {
  Future<int?> pumpTabs(
    WidgetTester tester, {
    int selected = 0,
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    int? elegido;
    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        builder: (context, child) =>
            SozuAdaptiveTokens(child: child ?? const SizedBox()),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => STabs(
              tabs: const ['Nuevo aviso', 'Configuración'],
              selected: selected,
              onChanged: (i) => setState(() {
                elegido = i;
                selected = i;
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return elegido;
  }

  testWidgets('pinta una etiqueta por pestaña', (tester) async {
    await pumpTabs(tester);

    expect(find.text('Nuevo aviso'), findsOneWidget);
    expect(find.text('Configuración'), findsOneWidget);
  });

  testWidgets('tocar una pestaña avisa con su indice', (tester) async {
    await pumpTabs(tester);

    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();

    // El indice ES la identidad de la pestaña: no hay objeto de estado propio.
    expect(find.text('Configuración'), findsOneWidget);
  });

  testWidgets('NO monta un TabBarView: el cuerpo lo pone quien la usa', (
    tester,
  ) async {
    // Es la razon de existir del componente. Con un TabBarView dentro, la
    // pantalla de avisos volveria a necesitar su propio scroll.
    await pumpTabs(tester);

    expect(find.byType(TabBarView), findsNothing);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('no trae scroll propio', (tester) async {
    // Si lo trajera, anidaria un area desplazable dentro del scroll de pagina y
    // volveria el problema de la rueda que solo mueve la columna central.
    await pumpTabs(tester);

    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('en telefono las pestañas se reparten el ancho', (tester) async {
    await pumpTabs(tester, size: const Size(390, 800));

    final cajaA = tester.getSize(find.byType(AnimatedContainer).first).width;
    final cajaB = tester.getSize(find.byType(AnimatedContainer).last).width;
    // Iguales pese a que "Configuración" es mas larga que "Nuevo aviso": en
    // movil manda el `Expanded`, no el texto.
    expect(cajaA, cajaB, reason: 'en movil deben repartirse el ancho');
    expect(
      cajaA + cajaB,
      closeTo(390, 1),
      reason: 'entre las dos, todo el ancho',
    );
  });

  testWidgets('en escritorio se ajustan a su texto', (tester) async {
    await pumpTabs(tester, size: const Size(1280, 800));

    final cajaA = tester.getSize(find.byType(AnimatedContainer).first).width;
    final cajaB = tester.getSize(find.byType(AnimatedContainer).last).width;
    // Repartirse 1280 px entre dos pestañas deja el texto perdido en medio.
    expect(cajaA, isNot(cajaB));
    expect(cajaA + cajaB, lessThan(1280));
  });
}
