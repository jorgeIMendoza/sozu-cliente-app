import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/client/properties/providers/properties_providers.dart';
import 'package:sozu_cliente_app/features/client/properties/screens/propiedades_screen.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import '../client_test_support.dart';
import 'fake_properties_port.dart';

/// "En adquisición" y "Patrimonio" eran dos pestañas del shell y ahora son un
/// filtro de la MISMA pantalla. Lo que este archivo fija es que el filtro
/// reparte bien las dos listas del backend, que siguen llegando separadas.
void main() {
  /// Dos en adquisición (Toreo 101, Toreo 102) y una entregada (Reforma 301).
  final payload = <String, dynamic>{
    'en_adquisicion': [
      {'id': 11, 'nombre': '101', 'proyecto': 'Toreo'},
      {'id': 12, 'nombre': '102', 'proyecto': 'Toreo'},
    ],
    'patrimonio_activo': [
      {'id': 21, 'nombre': '301', 'proyecto': 'Reforma'},
    ],
  };

  Future<void> pumpPantalla(
    WidgetTester tester, {
    PropiedadesFiltro filtro = PropiedadesFiltro.todas,
    Map<String, dynamic>? datos,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    // Alto generoso: en móvil las cards miden ~300 px y el finder no ve lo que
    // no se construyó.
    tester.view.physicalSize = const Size(390, 3000);
    addTearDown(tester.view.reset);

    final port = FakePropertiesPort()..propertiesJson = datos ?? payload;

    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [propertiesPortProvider.overrideWithValue(port)],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: PropiedadesScreen(filtroInicial: filtro),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin filtro salen las dos listas juntas', (tester) async {
    await pumpPantalla(tester);

    expect(find.text('101'), findsOneWidget);
    expect(find.text('102'), findsOneWidget);
    expect(find.text('301'), findsOneWidget);
    // El conteo de cada pastilla sale de la lista que le toca.
    expect(find.text('Todas (3)'), findsOneWidget);
    expect(find.text('En adquisición (2)'), findsOneWidget);
    expect(find.text('Entregadas (1)'), findsOneWidget);
  });

  testWidgets('el filtro inicial de la ruta vieja preselecciona el suyo', (
    tester,
  ) async {
    await pumpPantalla(tester, filtro: PropiedadesFiltro.entregadas);

    expect(find.text('301'), findsOneWidget);
    expect(find.text('101'), findsNothing);
    expect(find.text('102'), findsNothing);
  });

  testWidgets('cambiar de pastilla cambia la lista', (tester) async {
    await pumpPantalla(tester);

    await tester.tap(find.text('En adquisición (2)'));
    await tester.pumpAndSettle();

    expect(find.text('101'), findsOneWidget);
    expect(find.text('301'), findsNothing);
  });

  testWidgets(
    'el vacío por filtro no dice lo mismo que el vacío por búsqueda',
    (tester) async {
      await pumpPantalla(
        tester,
        filtro: PropiedadesFiltro.entregadas,
        datos: {
          'en_adquisicion': [
            {'id': 11, 'nombre': '101', 'proyecto': 'Toreo'},
          ],
        },
      );

      expect(
        find.text('Aún no tienes propiedades entregadas.'),
        findsOneWidget,
      );

      // Con texto que no encuentra nada, el mensaje cambia: se arregla borrando
      // el texto, no cambiando de pestaña.
      await tester.tap(find.text('Todas (1)'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('Sin resultados'), findsOneWidget);
    },
  );
}
