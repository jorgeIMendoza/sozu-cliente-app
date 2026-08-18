import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/features/admin/components/admin_header_bar.dart';
import 'package:sozu_cliente_app/features/admin/layouts/admin_layout.dart';
import 'package:sozu_cliente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_cliente_app/features/admin/screens/announcements_screen.dart';
import 'package:sozu_cliente_app/features/admin/screens/select_client_screen.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import '../auth/fake_auth_port.dart';
import 'fake_admin_port.dart';

/// Las DOS pantallas de admin tienen que comportarse igual: mismo layout y UN
/// solo scroll, el de la pagina, que cubre el viewport completo.
///
/// Antes no era asi. `announcements` usaba `AdminLayout.fixed` porque su
/// `TabBarView` no cabia en un scroll de pagina, y cargaba un
/// `SingleChildScrollView` por pestaña: en escritorio la rueda del raton solo
/// respondia sobre la columna central. Este archivo existe para que no vuelva.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authPortProvider.overrideWithValue(FakeAuthPort()),
        adminPortProvider.overrideWithValue(FakeAdminPort()),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/x',
      routes: [GoRoute(path: '/x', builder: (_, _) => screen)],
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

  for (final (nombre, screen) in <(String, Widget)>[
    ('selector de cliente', const SelectClientScreen()),
    ('avisos', const AnnouncementsScreen()),
  ]) {
    testWidgets('$nombre monta AdminLayout', (tester) async {
      await pump(tester, screen);
      expect(find.byType(AdminLayout), findsOneWidget);
    });

    testWidgets('$nombre tiene UN solo scroll y cubre el viewport', (
      tester,
    ) async {
      await pump(tester, screen);

      // UN solo scroll de PAGINA. No se cuenta `Scrollable` a secas porque cada
      // campo de texto monta el suyo por dentro (EditableText); lo que no puede
      // haber es un segundo scroll de pagina anidado.
      expect(
        find.byType(SingleChildScrollView),
        findsOneWidget,
        reason: 'un scroll anidado deja la rueda muerta en los laterales',
      );
      // 1280 y no el ancho de la columna: el area desplazable es la pagina.
      expect(tester.getSize(find.byType(SingleChildScrollView)).width, 1280);
    });
  }

  testWidgets('las dos tienen titulo Y subtitulo, a la misma altura', (
    tester,
  ) async {
    // Sin subtitulo en avisos el encabezado medía distinto y las acciones caian
    // a otra altura que en el selector: dos pantallas de la misma area que no
    // cuadran al cambiar de una a otra.
    final alturas = <double>[];
    for (final (titulo, screen) in <(String, Widget)>[
      ('Selecciona un cliente', const SelectClientScreen()),
      ('Enviar avisos', const AnnouncementsScreen()),
    ]) {
      await pump(tester, screen);
      expect(find.text(titulo), findsOneWidget);

      final cabecera = find.byType(AdminHeaderBar);
      expect(cabecera, findsOneWidget);
      final cabeceraRect = tester.getRect(cabecera);
      alturas.add(cabeceraRect.height);

      // Las dos deben traer subtitulo: es lo que iguala el alto del bloque.
      expect(
        tester.widget<AdminHeaderBar>(cabecera).subtitle,
        isNotNull,
        reason: 'sin subtitulo el encabezado mide menos y no cuadran',
      );
      // Relativo al encabezado, no absoluto: `AdminLayout` mete su gutter.
      expect(tester.getRect(find.text(titulo)).left, cabeceraRect.left);
    }
    expect(
      alturas.first,
      alturas.last,
      reason: 'los dos encabezados deben medir lo mismo',
    );
  });

  testWidgets('avisos ya no usa TabBar/TabBarView de Material', (tester) async {
    // Son los que obligaban al layout aparte, y ademas pintan con `colorScheme`
    // en vez de con los roles de SOZU.
    await pump(tester, const AnnouncementsScreen());

    expect(find.byType(TabBarView), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(STabs), findsOneWidget);
  });

  testWidgets('avisos conserva sus dos pestañas y se cambia entre ellas', (
    tester,
  ) async {
    await pump(tester, const AnnouncementsScreen());

    expect(find.text('Nuevo aviso'), findsWidgets);
    expect(find.text('Configuración'), findsOneWidget);

    await tester.tap(find.text('Configuración'));
    await tester.pump();

    expect(
      find.textContaining('Animación al llegar'),
      findsOneWidget,
      reason: 'la pestaña de configuracion debe cambiar el cuerpo',
    );
  });
}
