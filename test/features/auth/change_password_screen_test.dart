import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/features/auth/components/login_form.dart';
import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/auth/screens/change_password_screen.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import 'fake_auth_port.dart';

/// El cambio de contraseña temporal CIERRA la sesión y devuelve al login con el
/// aviso de éxito. Antes conservaba la sesión y entraba directo al portal: el
/// usuario nunca confirmaba que su contraseña nueva servía para entrar.
void main() {
  const clientProfile = UserProfile(
    displayName: 'Cliente de Prueba',
    email: 'cliente@sozu.com',
    roleName: 'Cliente',
    roleId: 23,
    personId: 7,
    requiresPasswordChange: true,
  );

  /// Mismo andamio que login_form_test: en un test la plataforma es Android y
  /// BiometricService lee secure storage; `null` = "no hay biometría guardada".
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  /// Monta la pantalla con un router mínimo (/change-password + /login): el
  /// `context.go` del éxito necesita un GoRouter real para llegar al login.
  Future<ProviderContainer> pumpChangePassword(
    WidgetTester tester,
    FakeAuthPort port,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [authPortProvider.overrideWithValue(port)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/change-password',
      routes: [
        GoRoute(
          path: '/change-password',
          builder: (_, _) => const ChangePasswordScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) =>
              const Scaffold(body: SingleChildScrollView(child: LoginForm())),
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

  Future<void> fillAndSubmit(WidgetTester tester, String password) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), password);
    await tester.enterText(fields.at(1), password);
    await tester.tap(find.text('Cambiar Contraseña').last);
    await tester.pumpAndSettle();
  }

  testWidgets('al cambiarla cierra sesión y el login confirma el cambio', (
    tester,
  ) async {
    final port = FakeAuthPort(profileRow: clientProfile);
    final container = await pumpChangePassword(tester, port);
    final auth = container.read(authProvider);
    await auth.signIn('cliente@sozu.com', 'secreta123');
    await tester.pumpAndSettle();

    await fillAndSubmit(tester, 'NuevaSegura9!');

    expect(port.log, containsAllInOrder(['updatePassword', 'signOut']));
    expect(container.read(passwordChangedProvider), isTrue);
    expect(find.byType(LoginForm), findsOneWidget);
    expect(
      find.textContaining('Contraseña actualizada'),
      findsOneWidget,
      reason: 'el login debe confirmar el cambio, no dejarlo mudo',
    );
  });

  testWidgets('si falla muestra el motivo real y NO cierra la sesión', (
    tester,
  ) async {
    final port = FakeAuthPort(profileRow: clientProfile);
    final container = await pumpChangePassword(tester, port);
    final auth = container.read(authProvider);
    await auth.signIn('cliente@sozu.com', 'secreta123');
    await tester.pumpAndSettle();

    port.nextFailure = AuthFailure.network;
    await fillAndSubmit(tester, 'NuevaSegura9!');

    expect(
      find.text('No pudimos conectar. Revisa tu conexion e intenta de nuevo.'),
      findsOneWidget,
    );
    expect(container.read(passwordChangedProvider), isFalse);
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
  });
}
