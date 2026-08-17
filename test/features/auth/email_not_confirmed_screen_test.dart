import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/auth/screens/email_not_confirmed_screen.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import 'fake_auth_port.dart';

/// Bloqueo por correo sin confirmar. Aqui la sesion YA esta cerrada: el gate
/// hizo signOut y dejo el correo en `blockedEmail`, asi que todo lo que esta
/// pantalla puede hacer depende de que ese correo exista.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  Future<ProviderContainer> pumpBloqueo(
    WidgetTester tester,
    FakeAuthPort port, {
    String? correoBloqueado,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [authPortProvider.overrideWithValue(port)],
    );
    addTearDown(container.dispose);
    container.read(authProvider).blockedEmail = correoBloqueado;

    final router = GoRouter(
      initialLocation: emailNotConfirmedPath,
      routes: [
        GoRoute(
          path: emailNotConfirmedPath,
          builder: (_, _) => const EmailNotConfirmedScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('pantalla de login')),
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
    await tester.pumpAndSettle();
    return container;
  }

  const boton = 'Reenviar correo de confirmación';

  testWidgets('con correo bloqueado nombra la cuenta y ofrece reenviar', (
    tester,
  ) async {
    final port = FakeAuthPort();
    await pumpBloqueo(tester, port, correoBloqueado: 'cliente@sozu.com');

    expect(find.textContaining('cliente@sozu.com'), findsOneWidget);
    expect(find.text(boton), findsOneWidget);
  });

  testWidgets('SIN correo no hay a donde reenviar: el boton no existe', (
    tester,
  ) async {
    // El gate puede dejar el bloqueo sin correo. Pintar el boton ahi daba un
    // reenvio que no podia funcionar.
    final port = FakeAuthPort();
    await pumpBloqueo(tester, port, correoBloqueado: null);

    expect(find.text(boton), findsNothing);
    expect(find.text('Confirma tu correo'), findsOneWidget);
  });

  testWidgets('al reenviar bien el boton desaparece y queda el aviso', (
    tester,
  ) async {
    // Se esconde a proposito: pedir enlaces en cadena invalida el anterior y
    // hace creer que ninguno llego.
    final port = FakeAuthPort();
    await pumpBloqueo(tester, port, correoBloqueado: 'cliente@sozu.com');

    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();

    expect(port.log, contains('resendEmailConfirmation'));
    expect(find.textContaining('Te enviamos un correo nuevo'), findsOneWidget);
    expect(find.text(boton), findsNothing);
  });

  testWidgets('si el reenvio falla el boton SIGUE, para poder reintentar', (
    tester,
  ) async {
    final port = FakeAuthPort()..nextFailure = AuthFailure.network;
    await pumpBloqueo(tester, port, correoBloqueado: 'cliente@sozu.com');

    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos conectar. Revisa tu conexion e intenta de nuevo.'),
      findsOneWidget,
    );
    expect(
      find.text(boton),
      findsOneWidget,
      reason: 'sin correo enviado hay que poder reintentar',
    );
  });

  testWidgets('volver al login limpia el bloqueo antes de navegar', (
    tester,
  ) async {
    // Si no se limpia primero, el router devuelve a esta pantalla en cuanto
    // intenta salir: el bloqueo sigue puesto.
    final port = FakeAuthPort();
    final container = await pumpBloqueo(
      tester,
      port,
      correoBloqueado: 'cliente@sozu.com',
    );

    await tester.tap(find.text('Volver al inicio de sesión'));
    await tester.pumpAndSettle();

    expect(container.read(authProvider).blockedEmail, isNull);
    expect(find.text('pantalla de login'), findsOneWidget);
  });
}
