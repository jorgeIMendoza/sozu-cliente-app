import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/auth/screens/forgot_password_screen.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import 'fake_auth_port.dart';

/// Contrato de "recuperar contraseña". Las tres reglas que lo definen y que se
/// rompen sin ruido: la respuesta es NEUTRA (no dice si la cuenta existe), un
/// fallo real SI se muestra, y topar el limite de envios NO es un fallo.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  Future<void> pumpForgot(WidgetTester tester, FakeAuthPort port) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [authPortProvider.overrideWithValue(port)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/forgot-password',
      routes: [
        GoRoute(
          path: '/forgot-password',
          builder: (_, _) => const ForgotPasswordScreen(),
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
  }

  Future<void> enviar(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextFormField).first, email);
    await tester.tap(find.text('Validar').last);
    await tester.pumpAndSettle();
  }

  testWidgets('el exito es NEUTRO: no confirma si la cuenta existe', (
    tester,
  ) async {
    final port = FakeAuthPort();
    await pumpForgot(tester, port);

    await enviar(tester, 'quiensabe@sozu.com');

    expect(port.log, contains('sendPasswordReset'));
    expect(find.text('Revisa tu correo'), findsOneWidget);
    // "Si existe una cuenta activa": el condicional es la garantia. Afirmar que
    // se envio delataria que el correo esta dado de alta.
    expect(find.textContaining('Si existe una cuenta activa'), findsOneWidget);
  });

  testWidgets('un fallo REAL de red se muestra, no se traga', (tester) async {
    // Tragarlos era peor que el riesgo que evitaban: un SMTP caido se veia
    // identico a un envio exitoso y el usuario esperaba un correo que nunca
    // salio. La neutralidad la da el backend, que responde igual exista o no la
    // cuenta, asi que mostrar un error de red no filtra nada.
    final port = FakeAuthPort()..nextFailure = AuthFailure.network;
    await pumpForgot(tester, port);

    await enviar(tester, 'cliente@sozu.com');

    expect(
      find.text('No pudimos conectar. Revisa tu conexion e intenta de nuevo.'),
      findsOneWidget,
    );
    expect(
      find.text('Revisa tu correo'),
      findsNothing,
      reason: 'un fallo no puede acabar en la pantalla de exito',
    );
  });

  testWidgets('topar el limite NO es error: manda al enlace que ya tiene', (
    tester,
  ) async {
    // El backend responde 200 y no envia. Decir "revisa tu correo" mandaba al
    // usuario a esperar algo que no iba a llegar, y a pedir mas enlaces, que es
    // justo lo que dispara el limite.
    final port = FakeAuthPort()
      ..nextResetResult = const PasswordResetResult(
        rateLimited: true,
        retryAfterMinutes: 7,
      );
    await pumpForgot(tester, port);

    await enviar(tester, 'cliente@sozu.com');

    expect(find.text('Usa el enlace que ya tienes'), findsOneWidget);
    expect(find.textContaining('7 minutos'), findsOneWidget);
    expect(
      find.text('Revisa tu correo'),
      findsNothing,
      reason: 'no se envio correo nuevo, no puede decir que lo revise',
    );
  });

  testWidgets('sin correo valido no se llama al backend', (tester) async {
    final port = FakeAuthPort();
    await pumpForgot(tester, port);

    await enviar(tester, 'esto-no-es-un-correo');

    expect(find.text('Correo no válido'), findsOneWidget);
    expect(port.log, isNot(contains('sendPasswordReset')));
  });
}
