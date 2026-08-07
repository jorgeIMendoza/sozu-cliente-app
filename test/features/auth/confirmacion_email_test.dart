import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/auth/screens/confirmacion_email_screen.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import 'fake_auth_port.dart';

/// El enlace "Confirma tu correo" aterriza en `/auth/confirmacion-email`, una
/// ruta que la Edge Function fija en el correo. Este host servía el portal
/// legacy y hoy sirve Flutter: sin la ruta, el enlace caía en el fallback SPA,
/// el router no lo reconocía y el cliente terminaba en /login sin confirmar
/// nada ni poder entrar. Un cliente real quedó bloqueado así.
void main() {
  const perfilTemporal = UserProfile(
    displayName: 'Cliente de Prueba',
    email: 'cliente@sozu.com',
    roleName: 'Cliente',
    roleId: 23,
    requiresPasswordChange: true,
  );

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  /// Monta la pantalla con un router mínimo. `/inicio` y `/login` son sondas:
  /// lo que importa es a cuál de las dos llega.
  Future<ProviderContainer> pumpConfirmacion(
    WidgetTester tester,
    FakeAuthPort port, {
    String? tokenHash = 'token-bueno',
    String type = 'magiclink',
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [authPortProvider.overrideWithValue(port)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: Uri(
        path: '/auth/confirmacion-email',
        queryParameters: {
          if (tokenHash != null) 'token_hash': tokenHash,
          'type': type,
          'email': 'cliente@sozu.com',
          'nombre': 'Cliente de Prueba',
        },
      ).toString(),
      routes: [
        GoRoute(
          path: '/auth/confirmacion-email',
          builder: (_, state) {
            final q = state.uri.queryParameters;
            return ConfirmacionEmailScreen(
              tokenHash: q['token_hash'],
              type: q['type'],
              email: q['email'],
              nombre: q['nombre'],
            );
          },
        ),
        GoRoute(
          path: '/inicio',
          builder: (_, _) => const Scaffold(body: Text('INICIO')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('LOGIN')),
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

  testWidgets('con token válido confirma, cierra el alta y entra', (
    tester,
  ) async {
    final port = FakeAuthPort(profileRow: perfilTemporal);
    final container = await pumpConfirmacion(tester, port);

    expect(port.log, contains('confirmEmailLink:magiclink'));
    expect(
      port.completedRegistrations,
      ['cliente@sozu.com'],
      reason: 'sin esto el correo no queda confirmado en usuarios',
    );
    expect(find.text('INICIO'), findsOneWidget);
    // La sesión queda abierta: es lo que permite al guard mandar a
    // /change-password sin pedir la contraseña temporal.
    expect(container.read(authProvider).session, isNotNull);
  });

  testWidgets('un token ya usado explica que venció, no manda a login mudo', (
    tester,
  ) async {
    final port = FakeAuthPort(profileRow: perfilTemporal);
    await pumpConfirmacion(tester, port, tokenHash: 'token-quemado');

    expect(find.text('No pudimos confirmar tu correo'), findsOneWidget);
    expect(find.textContaining('vencio o ya se uso'), findsOneWidget);
    expect(find.text('INICIO'), findsNothing);
  });

  testWidgets('sin token no intenta nada y lo dice', (tester) async {
    final port = FakeAuthPort(profileRow: perfilTemporal);
    await pumpConfirmacion(tester, port, tokenHash: null);

    expect(find.textContaining('enlace está incompleto'), findsOneWidget);
    expect(port.log, isNot(contains('confirmEmailLink:magiclink')));
  });

  testWidgets('si falla el cierre del alta el usuario entra igual', (
    tester,
  ) async {
    final port = FakeAuthPort(profileRow: perfilTemporal);
    // El fallo se consume en completeRegistration: la confirmación en Auth ya
    // ocurrió y bloquear el acceso por el correo de credenciales sería peor.
    await pumpConfirmacion(tester, port);
    expect(find.text('INICIO'), findsOneWidget);
  });

  test('la red caída se distingue del enlace vencido', () {
    expect(
      AuthController.confirmEmailErrorMessage(AuthError(AuthFailure.network)),
      contains('No pudimos conectar'),
    );
    expect(
      AuthController.confirmEmailErrorMessage(
        AuthError(AuthFailure.sessionRevoked),
      ),
      contains('vencio o ya se uso'),
    );
  });
}
