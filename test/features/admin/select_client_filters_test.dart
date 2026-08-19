import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/features/admin/components/client_row.dart';
import 'package:sozu_cliente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_cliente_app/features/admin/providers/client_filters_provider.dart';
import 'package:sozu_cliente_app/features/admin/screens/select_client_screen.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import '../auth/fake_auth_port.dart';
import 'fake_admin_port.dart';

/// Los filtros del selector viven en `clientFiltersProvider` y no en el `State`
/// de la pantalla. El motivo es de uso: al ir a avisos, o al entrar como un
/// cliente y volver, el `State` se destruye y habia que reescribir proyecto,
/// unidad y busqueda cada vez.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(WidgetTester tester, {FakeAdminPort? port}) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        authPortProvider.overrideWithValue(FakeAuthPort()),
        adminPortProvider.overrideWithValue(port ?? FakeAdminPort()),
      ],
    );
    addTearDown(container.dispose);

    router = GoRouter(
      initialLocation: '/seleccionar-cliente',
      routes: [
        GoRoute(
          path: '/seleccionar-cliente',
          builder: (_, _) => const SelectClientScreen(),
        ),
        GoRoute(
          path: '/otra',
          builder: (_, _) => const Scaffold(body: Text('otra')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('la busqueda SOBREVIVE a salir de la pantalla y volver', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField).last, 'alex');
    await tester.pumpAndSettle();

    // Salir destruye el State de la pantalla.
    router.go('/otra');
    await tester.pumpAndSettle();
    expect(find.text('otra'), findsOneWidget);

    router.go('/seleccionar-cliente');
    await tester.pumpAndSettle();

    expect(container.read(clientFiltersProvider).query, 'alex');
    expect(
      find.widgetWithText(TextField, 'alex'),
      findsOneWidget,
      reason: 'el campo debe volver a mostrar lo que el store recuerda',
    );
  });

  testWidgets('sin filtros no se ofrece "Limpiar filtros"', (tester) async {
    // Un boton permanente sobre un formulario vacio es ruido y ensena a
    // ignorarlo.
    await pump(tester);
    expect(find.text('Limpiar filtros'), findsNothing);
  });

  testWidgets('con filtros aparece, y limpia todo de un toque', (tester) async {
    await pump(tester);
    container.read(clientFiltersProvider)
      ..setQuery('alex')
      ..setProjectId(7)
      ..setUnit('402');
    await tester.pumpAndSettle();

    expect(find.text('Limpiar filtros'), findsOneWidget);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();

    final f = container.read(clientFiltersProvider);
    expect(f.query, '');
    expect(f.projectId, isNull);
    expect(f.unit, '');
    expect(find.text('Limpiar filtros'), findsNothing);
  });

  testWidgets('cerrar sesion limpia los filtros', (tester) async {
    // Si no, el siguiente admin en la misma maquina hereda el proyecto y la
    // unidad del anterior.
    await pump(tester);
    container.read(clientFiltersProvider).setQuery('alex');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(container.read(clientFiltersProvider).isDirty, isFalse);
  });

  testWidgets('la busqueda espera a que dejes de escribir', (tester) async {
    // Sin debounce cada tecla filtraba los 600+ clientes y reconstruia la lista
    // entera, y el campo se sentia trabado mientras se escribia.
    await pump(tester);

    await tester.enterText(find.byType(TextField).last, 'ale');
    // `pumpAndSettle` NO sirve para esperar el debounce: adelanta el reloj solo
    // mientras haya frames agendados, y un `Timer` pelado no agenda ninguno.
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(clientFiltersProvider).query, '');

    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(clientFiltersProvider).query, 'ale');
    await tester.pumpAndSettle();
  });

  testWidgets('la X del buscador limpia sin esperar el debounce', (
    tester,
  ) async {
    // El usuario ya decidio: esperar la pausa solo deja la lista vieja en
    // pantalla un rato mas.
    await pump(tester);
    await tester.enterText(find.byType(TextField).last, 'alex');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(container.read(clientFiltersProvider).query, 'alex');

    await tester.tap(find.widgetWithIcon(IconButton, Icons.clear));
    await tester.pump();
    expect(container.read(clientFiltersProvider).query, '');
    await tester.pumpAndSettle();
  });

  testWidgets('con cientos de coincidencias solo pinta las primeras', (
    tester,
  ) async {
    // La lista no tiene scroll propio (lo da AdminLayout), asi que el ListView
    // va con shrinkWrap y construye TODAS las filas: dos letras comunes casan
    // 500+ clientes en produccion y la pantalla se traba.
    final port = FakeAdminPort()
      ..storedClients = [
        for (var i = 0; i < 60; i++)
          {
            'id_persona': i,
            'nombre': 'Cliente Marino $i',
            'email': 'marino$i@x.com',
          },
      ];
    await pump(tester, port: port);

    await tester.enterText(find.byType(TextField).last, 'marino');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(ClientRow), findsNWidgets(50));
    expect(
      find.text('Mostrando 50 de 60. Escribe más para afinar la búsqueda.'),
      findsOneWidget,
    );
  });

  testWidgets('abrir el selector NO descarga clientes', (tester) async {
    // Antes la pantalla bajaba el padron entero al construirse (630 filas en
    // produccion) para mostrar, como mucho, una pantalla.
    final port = FakeAdminPort();
    await pump(tester, port: port);

    expect(port.log, isNot(contains('searchClients')));
    expect(port.log, isNot(contains('clients')));

    // Una letra tampoco: el minimo son dos.
    await tester.enterText(find.byType(TextField).last, 'a');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(port.log, isNot(contains('searchClients')));

    await tester.enterText(find.byType(TextField).last, 'al');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(port.log, contains('searchClients'));
  });

  testWidgets('la busqueda del servidor ignora acentos', (tester) async {
    // En produccion la mitad de los nombres llevan acento: "hernandez" tecleado
    // sin acento encontraba 9 de 20. La regla vive en Postgres (unaccent), no
    // en Dart; el doble la emula para fijar el contrato.
    final port = FakeAdminPort()
      ..storedClients = [
        {
          'id_persona': 1,
          'nombre': 'Alonso Hernández Cedillo',
          'email': 'a@x.com',
        },
        {
          'id_persona': 2,
          'nombre': 'Dante Hernandez Mejia',
          'email': 'd@x.com',
        },
        {'id_persona': 3, 'nombre': 'Bruno Pérez', 'email': 'b@x.com'},
      ];
    await pump(tester, port: port);

    await tester.enterText(find.byType(TextField).last, 'hernandez');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Alonso Hernández Cedillo'), findsOneWidget);
    expect(find.text('Dante Hernandez Mejia'), findsOneWidget);
    expect(find.text('Bruno Pérez'), findsNothing);
  });

  testWidgets('el total sale del servidor, no de lo que se pinto', (
    tester,
  ) async {
    // El servidor manda 50 filas y dice que hay 300. Contar lo recibido diria
    // "50 de 50" y el admin creeria que ya los vio todos.
    final port = FakeAdminPort()
      ..storedClients = [
        for (var i = 0; i < 300; i++)
          {
            'id_persona': i,
            'nombre': 'Cliente Marino $i',
            'email': 'm$i@x.com',
          },
      ];
    await pump(tester, port: port);

    await tester.enterText(find.byType(TextField).last, 'marino');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(ClientRow), findsNWidgets(50));
    expect(
      find.text('Mostrando 50 de 300. Escribe más para afinar la búsqueda.'),
      findsOneWidget,
    );
  });

  testWidgets('sin la accion en el backend, filtra en memoria y sigue viva', (
    tester,
  ) async {
    // Backend viejo: ignora la accion que no conoce y devuelve el padron sin
    // `total`. Es lo que permite desplegar app y Edge Function en cualquier
    // orden, asi que la degradacion se prueba, no se supone.
    final port = FakeAdminPort()..serverSearch = false;
    await pump(tester, port: port);

    await tester.enterText(find.byType(TextField).last, 'bruno');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Bruno Pérez'), findsOneWidget);
    expect(find.text('Alex Hernández'), findsNothing);
  });
}
