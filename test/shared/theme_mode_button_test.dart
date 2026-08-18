import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sozu_cliente_app/shared/components/theme_mode_button.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// El menu del selector de tema tenia dos defectos visibles en el telefono:
/// cambiaba de ancho segun que opcion estuviera activa (solo esa llevaba
/// palomita, y era la que definia el ancho), y la palomita quedaba pegada al
/// texto.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> abrirMenu(WidgetTester tester, {required bool oscuro}) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: oscuro ? sozuDarkTheme() : sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: const Scaffold(
            body: Align(alignment: Alignment.topLeft, child: ThemeModeButton()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ThemeModeButton));
    await tester.pumpAndSettle();
  }

  for (final oscuro in [false, true]) {
    final tema = oscuro ? 'oscuro' : 'claro';

    testWidgets('$tema: las tres opciones miden lo mismo', (tester) async {
      await abrirMenu(tester, oscuro: oscuro);

      final anchos = <double>{};
      for (final label in ['Sistema', 'Claro', 'Oscuro']) {
        expect(find.text(label), findsOneWidget);
        anchos.add(
          tester
              .getRect(
                find.ancestor(of: find.text(label), matching: find.byType(Row)),
              )
              .width,
        );
      }
      expect(
        anchos.length,
        1,
        reason: 'el hueco de la palomita se reserva en las tres',
      );
    });

    testWidgets('$tema: la palomita no queda pegada al texto', (tester) async {
      await abrirMenu(tester, oscuro: oscuro);

      // `system` es el modo por defecto, asi que la palomita esta en "Sistema".
      // El `Text` va dentro de un `Expanded`, asi que su borde derecho ES el
      // inicio del hueco reservado: la distancia mide justo esa separacion.
      final texto = tester.getRect(find.text('Sistema'));
      final check = tester.getRect(find.byIcon(Icons.check));
      expect(
        check.left - texto.right,
        greaterThanOrEqualTo(8),
        reason: 'sin aire, la palomita se lee como parte de la palabra',
      );
    });
  }
}
