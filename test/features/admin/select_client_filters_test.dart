import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        authPortProvider.overrideWithValue(FakeAuthPort()),
        adminPortProvider.overrideWithValue(FakeAdminPort()),
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
}
