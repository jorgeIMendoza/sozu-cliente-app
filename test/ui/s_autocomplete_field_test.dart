import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Contrato del campo de búsqueda por escritura.
///
/// Lo que se fija aquí es justo lo que lo diferencia de un `DropdownButton`: que
/// NO vuelque el catálogo, y que un cero-resultados se vea en pantalla en vez de
/// no pasar nada.
void main() {
  const projects = ['Daiku', 'Dalia Residencial', 'Mutuo Vive', 'Productos'];

  Future<void> pumpField(
    WidgetTester tester, {
    String? value,
    ValueChanged<String?>? onSelected,
    double width = 400,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: SAutocompleteField<String>(
                options: projects,
                value: value,
                labelOf: (p) => p,
                labelText: 'Proyecto',
                noResultsLabel: 'Ningún proyecto coincide con',
                onSelected: onSelected ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('con el campo vacío NO muestra el catálogo', (tester) async {
    await pumpField(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // Esta es la razón de existir del widget: el desplegable anterior mostraba
    // las 4 entradas de golpe.
    for (final p in projects) {
      expect(find.text(p), findsNothing);
    }
  });

  testWidgets('al escribir filtra por coincidencia', (tester) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'da');
    await tester.pumpAndSettle();

    expect(find.text('Daiku'), findsOneWidget);
    expect(find.text('Dalia Residencial'), findsOneWidget);
    // Las que no coinciden no deben aparecer.
    expect(find.text('Mutuo Vive'), findsNothing);
    expect(find.text('Productos'), findsNothing);
  });

  testWidgets('el filtro ignora mayúsculas', (tester) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'DAIKU');
    await tester.pumpAndSettle();
    expect(find.text('Daiku'), findsOneWidget);
  });

  testWidgets('sin coincidencias muestra el fallback con el texto buscado', (
    tester,
  ) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    // Sin este fallback, "no existe" y "se rompió" se ven igual: nada.
    // El texto buscado sale 2 veces (en el campo y en el fallback), asi que se
    // afirma sobre la fila completa del fallback.
    expect(find.text('Ningún proyecto coincide con "zzz"'), findsOneWidget);
  });

  testWidgets('seleccionar notifica y pone el label en el campo', (
    tester,
  ) async {
    String? selected;
    await pumpField(tester, onSelected: (v) => selected = v);

    await tester.enterText(find.byType(TextField), 'dai');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daiku'));
    await tester.pumpAndSettle();

    expect(selected, 'Daiku');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Daiku',
    );
  });

  testWidgets('el fallback NO es seleccionable', (tester) async {
    var callbacks = 0;
    await pumpField(tester, onSelected: (_) => callbacks++);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ningún proyecto coincide'));
    await tester.pumpAndSettle();

    // Tocar "sin resultados" no debe elegir nada.
    expect(callbacks, 0);
  });

  testWidgets('con valor elegido ofrece limpiar y notifica null', (
    tester,
  ) async {
    String? selected = 'Daiku';
    await pumpField(tester, value: 'Daiku', onSelected: (v) => selected = v);

    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });

  testWidgets('deshabilitado con catálogo vacío', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        home: Scaffold(
          body: SAutocompleteField<String>(
            options: const [],
            labelOf: (p) => p,
            enabled: false,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('el menú mide lo mismo que el campo, aun sobre 520 px', (
    tester,
  ) async {
    // 700 px a proposito: el menu tenia un `maxWidth: 520` fijo, asi que con un
    // campo mas angosto que eso el bug no se ve. En escritorio el campo pasa de
    // 520 y el desplegable quedaba visiblemente mas angosto que el input.
    await pumpField(tester, width: 700);
    await tester.enterText(find.byType(TextField), 'dai');
    await tester.pumpAndSettle();

    // El STextField, no el TextField interno: ese mide 3 px menos por el borde.
    final fieldWidth = tester.getSize(find.byType(STextField)).width;
    final menuWidth = tester
        .getSize(
          find.ancestor(
            of: find.text('Daiku'),
            matching: find.byType(ListView),
          ),
        )
        .width;

    expect(fieldWidth, 700);
    expect(menuWidth, closeTo(fieldWidth, 4));
  });

  testWidgets('sin valor NO hay flecha de desplegable', (tester) async {
    await pumpField(tester);

    // Esto se escribe, no se despliega: una flecha promete un menu que un toque
    // no abre.
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets('desmontar no revienta: el controller se libera', (tester) async {
    // El widget crea su propio TextEditingController en build (`??=`) y antes
    // solo liberaba el FocusNode, asi que fugaba en cada montaje.
    await pumpField(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });
}
