import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/layouts/admin_layout.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Lo que fija este archivo es que el scroll del admin cubra el VIEWPORT
/// COMPLETO, no solo la columna de contenido.
///
/// El bug era el orden: cuando el limitador de ancho envolvia al scroll, la
/// rueda del raton solo movia el contenido y en los laterales la pagina no
/// respondia. En escritorio ancho eso es la mayor parte de la pantalla.
void main() {
  Future<void> pumpLayout(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        builder: (context, child) =>
            SozuAdaptiveTokens(child: child ?? const SizedBox()),
        home: const AdminLayout(
          maxWidth: 400,
          child: SizedBox(height: 2000, child: Text('contenido')),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('el scroll ocupa todo el ancho, no solo el contenido', (
    tester,
  ) async {
    await pumpLayout(tester, size: const Size(1280, 800));

    final scrollWidth = tester
        .getSize(find.byType(SingleChildScrollView))
        .width;

    // 1280 y no 400: el area desplazable es el viewport, aunque el contenido se
    // acote a maxWidth.
    expect(scrollWidth, 1280);
  });

  testWidgets('un puntero en el lateral desplaza la pagina', (tester) async {
    await pumpLayout(tester, size: const Size(1280, 800));

    final before = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;

    // x=60: fuera de la columna de 400 px centrada (que va de 440 a 840).
    await tester.dragFrom(const Offset(60, 400), const Offset(0, -300));
    await tester.pump();

    final after = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(
      after,
      greaterThan(before),
      reason: 'en los laterales la rueda no hacia nada',
    );
  });
}
