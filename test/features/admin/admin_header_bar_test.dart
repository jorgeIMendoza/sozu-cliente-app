import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/components/admin_header_bar.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Las acciones del encabezado van a la DERECHA en las dos anchuras.
///
/// En escritorio siempre fue asi (Row con el titulo en `Expanded`). En telefono
/// colgaban a la izquierda, y ahi parecian parte del subtitulo en vez de
/// controles.
///
/// El aserto es la alineacion y NO "caben en una fila": el ancho del texto
/// depende de la fuente, y en un widget test Flutter usa una de bloques mucho
/// mas ancha que Inter. Un test de "una sola fila" pasaria o fallaria por el
/// motivo equivocado.
void main() {
  Future<void> pump(WidgetTester tester, double ancho) async {
    tester.view.physicalSize = Size(ancho, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        builder: (context, child) =>
            SozuAdaptiveTokens(child: child ?? const SizedBox()),
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminHeaderBar(
                title: 'Selecciona un cliente',
                subtitle: 'Acceso administrador',
                actions: [
                  AdminHeaderAction(label: 'Enviar avisos', onPressed: () {}),
                  AdminHeaderAction(
                    label: 'Cerrar sesión',
                    isDanger: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (nombre, ancho) in <(String, double)>[
    ('telefono', 390),
    ('escritorio', 1280),
  ]) {
    testWidgets('$nombre: las acciones terminan pegadas al borde derecho', (
      tester,
    ) async {
      await pump(tester, ancho);

      final acciones = find.byType(AdminHeaderAction);
      final derechas = [
        for (var i = 0; i < acciones.evaluate().length; i++)
          tester.getRect(acciones.at(i)).right,
      ];
      expect(derechas, isNotEmpty);
      // Alguna accion llega al borde: es lo que significa "alineadas a la
      // derecha", quepan en una fila o en dos.
      expect(derechas.reduce((a, b) => a > b ? a : b), ancho);
    });

    testWidgets('$nombre: el titulo se queda a la izquierda', (tester) async {
      await pump(tester, ancho);
      expect(tester.getRect(find.text('Selecciona un cliente')).left, 0);
    });
  }
}
