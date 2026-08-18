import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_cliente_app/features/admin/screens/announcements_screen.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import '../auth/fake_auth_port.dart';
import 'fake_admin_port.dart';

/// Dos quejas de uso reales sobre esta pantalla:
///
/// 1. En escritorio se desperdiciaba media ventana: el formulario iba en una
///    columna de 880 px y los avisos recientes quedaban fuera de pantalla.
/// 2. "Avisos recientes" pintaba la lista ENTERA, asi que la pagina crecia sin
///    techo segun cuantos avisos hubiera.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  AvisoApp aviso(int i) => AvisoApp.fromJson({
    'id': i,
    'titulo': 'Aviso $i',
    'mensaje': 'cuerpo $i',
    'tipo': 'informativa',
    'categoria': 'pagos',
    'canales': ['push'],
    'estado': 'enviado',
  });

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    int avisos = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final port = FakeAdminPort();
    port.storedAnnouncements.addAll([
      for (var i = 1; i <= avisos; i++) aviso(i),
    ]);

    final container = ProviderContainer(
      overrides: [
        authPortProvider.overrideWithValue(FakeAuthPort()),
        adminPortProvider.overrideWithValue(port),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/x',
      routes: [
        GoRoute(path: '/x', builder: (_, _) => const AnnouncementsScreen()),
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

  testWidgets('en escritorio el formulario y los avisos van lado a lado', (
    tester,
  ) async {
    await pump(tester, size: const Size(1440, 1200), avisos: 2);

    // Contra un campo DEL formulario y no contra la pestaña "Nuevo aviso": la
    // pestaña vive arriba de las dos columnas, asi que compararse con ella daba
    // verde sin probar nada.
    final form = tester.getRect(find.text('Título'));
    final recientes = tester.getRect(find.text('Avisos recientes'));
    expect(
      recientes.left,
      greaterThan(form.right),
      reason: 'en escritorio deben ir en columnas, no apilados',
    );
  });

  testWidgets('en telefono se apilan', (tester) async {
    await pump(tester, size: const Size(390, 2400), avisos: 2);

    final form = tester.getRect(find.text('Título'));
    final recientes = tester.getRect(find.text('Avisos recientes'));
    expect(
      recientes.top,
      greaterThan(form.top),
      reason: 'sin ancho, dos columnas dejan los campos ilegibles',
    );
  });

  testWidgets('muestra 5 avisos por pagina, no la lista entera', (
    tester,
  ) async {
    await pump(tester, size: const Size(1440, 2000), avisos: 12);

    for (var i = 1; i <= 5; i++) {
      expect(find.text('Aviso $i'), findsOneWidget);
    }
    expect(find.text('Aviso 6'), findsNothing);
    expect(find.text('1 de 3'), findsOneWidget);
    expect(find.text('12 en total'), findsOneWidget);
  });

  testWidgets('se pasa de pagina hacia adelante y hacia atras', (tester) async {
    await pump(tester, size: const Size(1440, 2000), avisos: 12);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso 6'), findsOneWidget);
    expect(find.text('Aviso 1'), findsNothing);
    expect(find.text('2 de 3'), findsOneWidget);

    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso 1'), findsOneWidget);
  });

  testWidgets('con 5 o menos no se pinta el paginador', (tester) async {
    // Una sola pagina no se navega: el control seria ruido inerte.
    await pump(tester, size: const Size(1440, 2000), avisos: 4);

    expect(find.text('Aviso 4'), findsOneWidget);
    // Por el boton y no por el contador: " de " tambien esta en "Enviar de
    // inmediato", asi que un textContaining daba positivo siempre.
    expect(find.text('Anterior'), findsNothing);
    expect(find.text('Siguiente'), findsNothing);
  });
}
