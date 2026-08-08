import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Contrato de la confirmación con condiciones.
///
/// Lo que se fija aquí es que las condiciones se vean y que cancelar no pase
/// por aceptado: el diálogo existe justo para que la consecuencia quede del
/// lado de quien acepta.
void main() {
  Future<List<bool?>> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final holder = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                holder.add(
                  await showSConfirm(
                    context,
                    titulo: 'Antes de subir tu documento',
                    mensaje: 'Al aceptar confirmas que el archivo cumple:',
                    puntos: const [
                      'Sube el archivo en PDF y legible.',
                      'Un solo PDF con el frente y el reverso.',
                    ],
                    etiquetaAceptar: 'Acepto y subir',
                    tono: SConfirmTone.warning,
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return holder;
  }

  testWidgets('muestra cada condición y devuelve true al aceptar', (
    tester,
  ) async {
    final holder = await abrir(tester);

    expect(find.text('Sube el archivo en PDF y legible.'), findsOneWidget);
    expect(
      find.text('Un solo PDF con el frente y el reverso.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Acepto y subir'));
    await tester.pumpAndSettle();

    expect(holder.single, isTrue);
  });

  testWidgets('cancelar devuelve false, no null ni true', (tester) async {
    final holder = await abrir(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(holder.single, isFalse);
  });

  testWidgets('tocar fuera no cierra: hay que decidir', (tester) async {
    final holder = await abrir(tester);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Antes de subir tu documento'), findsOneWidget);
    expect(holder, isEmpty);
  });
}
