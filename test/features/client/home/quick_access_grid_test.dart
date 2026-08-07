import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/client/home/components/quick_access_grid.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// El grid reparte el ancho EXACTO entre sus columnas: 4 en móvil (dos filas de
/// cuatro) y 8 en escritorio (una sola fila). Si se reparte de más, la última
/// celda de cada fila se sale y Flutter pinta la franja de overflow.
void main() {
  List<QuickAccessItem> items() => [
    for (var i = 0; i < 8; i++)
      QuickAccessItem(
        icon: Icons.circle_outlined,
        label: 'Acceso $i',
        onTap: () {},
      ),
  ];

  Future<void> pumpGrid(
    WidgetTester tester,
    Size size, {
    List<QuickAccessItem>? custom,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        builder: (context, child) =>
            SozuAdaptiveTokens(child: child ?? const SizedBox()),
        home: Scaffold(
          body: SingleChildScrollView(
            child: QuickAccessGrid(items: custom ?? items()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Ancho de la celda: el SizedBox que el grid pone alrededor de cada acceso.
  double anchoCelda(WidgetTester tester, int i) {
    final celdas = find.ancestor(
      of: find.text('Acceso $i'),
      matching: find.byType(SizedBox),
    );
    return tester
        .widgetList<SizedBox>(celdas)
        .firstWhere((s) => s.width != null)
        .width!;
  }

  testWidgets('en móvil son 4 columnas: dos filas de cuatro', (tester) async {
    await pumpGrid(tester, const Size(390, 900));

    final ancho = anchoCelda(tester, 0);
    // Las 4 de una fila caben en el ancho disponible; la quinta arrancaría otra.
    expect(ancho * 4, lessThanOrEqualTo(390));
    expect(ancho * 5, greaterThan(390));
    // Y todas miden lo mismo: sin celda huérfana más angosta al final.
    for (var i = 1; i < 8; i++) {
      expect(anchoCelda(tester, i), ancho);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('en escritorio son 8 columnas: una sola fila', (tester) async {
    await pumpGrid(tester, const Size(1400, 900));

    final ancho = anchoCelda(tester, 0);
    expect(ancho * 8, lessThanOrEqualTo(1400));
    // Todos los accesos comparten la misma Y: es una fila, no dos.
    final y = tester.getTopLeft(find.text('Acceso 0')).dy;
    for (var i = 1; i < 8; i++) {
      expect(tester.getTopLeft(find.text('Acceso $i')).dy, y);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('el badge solo aparece cuando hay algo que avisar', (
    tester,
  ) async {
    await pumpGrid(
      tester,
      const Size(390, 900),
      custom: [
        QuickAccessItem(
          icon: Icons.payments_outlined,
          label: 'Pagar',
          badge: '3',
          onTap: () {},
        ),
        QuickAccessItem(
          icon: Icons.folder_outlined,
          label: 'Documentos',
          onTap: () {},
        ),
      ],
    );

    expect(find.text('3'), findsOneWidget);
    // El otro acceso no pinta pastilla: solo están los dos textos de etiqueta.
    expect(find.byType(Text), findsNWidgets(3));
  });

  testWidgets('tocar un acceso dispara su destino', (tester) async {
    var tocado = 0;
    await pumpGrid(
      tester,
      const Size(390, 900),
      custom: [
        QuickAccessItem(
          icon: Icons.payments_outlined,
          label: 'Pagar',
          onTap: () => tocado++,
        ),
      ],
    );

    await tester.tap(find.text('Pagar'));
    await tester.pumpAndSettle();
    expect(tocado, 1);
  });
}
