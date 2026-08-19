import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/client/layouts/client_bottom_nav.dart';
import 'package:sozu_cliente_app/features/client/layouts/client_shell.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import '../auth/fake_auth_port.dart';

/// Fija el comportamiento de HOY de la navegacion del cliente, ANTES de
/// unificar los tres shells (`PortalShell`, `_SideNav` y el bottom nav).
///
/// No comprueba que el diseno sea bueno -no lo es: se elige en tres sitios y
/// con dos criterios distintos-. Comprueba lo que el usuario puede hacer, para
/// que la unificacion no se lleve nada por delante sin avisar.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // El shell necesita router (sus items navegan con `context.go`) y
    // ProviderScope (lee sesion e impersonacion).
    final router = GoRouter(
      initialLocation: '/inicio',
      routes: [GoRoute(path: '/inicio', builder: (_, _) => child)],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authPortProvider.overrideWithValue(FakeAuthPort())],
        child: MaterialApp.router(
          routerConfig: router,
          theme: sozuLightTheme(),
          builder: (context, c) =>
              SozuAdaptiveTokens(child: c ?? const SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('el menu es una sola fuente', () {
    test('los nueve destinos siguen ahi', () {
      // Si esta lista cambia sin querer, media navegacion desaparece sin que
      // falle nada mas: el menu se pinta desde aqui en los dos shells.
      expect(clienteMenuTabs().map((t) => t.route).toList(), [
        '/inicio',
        '/propiedades',
        '/productos',
        '/pagos',
        '/estado-cuenta',
        '/facturas',
        '/mantenimientos',
        '/notificaciones',
        '/perfil',
      ]);
    });

    test('cada destino tiene etiqueta e icono', () {
      for (final t in clienteMenuTabs()) {
        expect(t.label, isNotEmpty, reason: '${t.route} sin etiqueta');
        expect(t.icon, isNotNull, reason: '${t.route} sin icono');
      }
    });

    test('rutas permitidas y menu no se desincronizan', () {
      expect(
        portalAllowedRoutes(),
        clienteMenuTabs().map((t) => t.route).toSet(),
      );
    });
  });

  group('ClientShell decide por ANCHO, no por plataforma', () {
    // Era el defecto de fondo: `isPortalMode` miraba `kIsWeb && ancho>=1024` y
    // `isDesktop` solo el ancho, en tres sitios distintos. Una tablet Android
    // ancha recibia el layout de telefono.
    //
    // En la VM de test `kIsWeb` es false, asi que estos dos casos son
    // exactamente los que ANTES se comportaban mal.

    testWidgets('angosto: barra inferior, sin barra lateral', (tester) async {
      await pump(
        tester,
        const ClientShell(
          currentPath: '/inicio',
          child: Scaffold(body: Text('contenido')),
        ),
        size: const Size(390, 900),
      );

      expect(find.text('contenido'), findsOneWidget);
      expect(find.byType(ClientBottomNav), findsOneWidget);
    });

    testWidgets('ancho: barra lateral, sin barra inferior', (tester) async {
      await pump(
        tester,
        const ClientShell(
          currentPath: '/inicio',
          child: Scaffold(body: Text('contenido')),
        ),
        size: const Size(1440, 900),
      );

      expect(find.text('contenido'), findsOneWidget);
      expect(
        find.byType(ClientBottomNav),
        findsNothing,
        reason: 'con sidebar la barra inferior sobra',
      );
      // La barra lateral se monta: con `kIsWeb` false ANTES no lo hacia, y el
      // menu quedaba abajo aunque hubiera 1440 px de ancho.
      expect(find.byType(SLogo), findsWidgets);
    });

    testWidgets('el menu se pinta en las dos anchuras', (tester) async {
      for (final size in [const Size(390, 900), const Size(1440, 900)]) {
        await pump(
          tester,
          const ClientShell(
            currentPath: '/inicio',
            child: Scaffold(body: Text('contenido')),
          ),
          size: size,
        );
        expect(
          find.text('Inicio'),
          findsWidgets,
          reason: 'sin menu en ${size.width.toInt()} px',
        );
      }
    });
  });
}
