import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/providers/auth_provider.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

import 'fake_auth_port.dart';

/// Lo que fija este archivo es que `AuthController` funciona contra el PUERTO,
/// no contra Supabase: todo corre con [FakeAuthPort] y ni un test inicializa
/// el backend. Antes esto era imposible (ver ADR 0002 §1.1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const perfilCliente = UserProfile(
    nombre: 'Cliente de Prueba',
    email: 'cliente@sozu.com',
    rolNombre: 'Cliente',
    idPersona: 7,
  );

  /// BiometricService lee secure storage desde `_init` (en tests
  /// `defaultTargetPlatform` es Android); `null` = "no hay biometría guardada".
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  /// Construye el controller y deja terminar el `_init` asíncrono.
  Future<AuthController> makeController(FakeAuthPort port) async {
    final controller = AuthController(port);
    await pumpEventQueue();
    return controller;
  }

  test('arranca sin sesión: listo y deslogueado', () async {
    final port = FakeAuthPort();
    final controller = await makeController(port);

    expect(controller.isLoading, isFalse);
    expect(controller.session, isNull);
    expect(controller.profile, isNull);
  });

  test('signIn correcto: sesión viva y perfil cargado', () async {
    final port = FakeAuthPort(profileRow: perfilCliente);
    final controller = await makeController(port);

    await controller.signIn('cliente@sozu.com', 'secreta123');
    await pumpEventQueue();

    expect(controller.session?.userId, 'user-de-prueba');
    expect(controller.profile?.rolNombre, 'Cliente');
    expect(controller.isCliente, isTrue);
    expect(controller.locked, isFalse);
  });

  test('signIn con contraseña equivocada lanza AuthError traducible', () async {
    final port = FakeAuthPort(profileRow: perfilCliente);
    final controller = await makeController(port);

    Object? error;
    try {
      await controller.signIn('cliente@sozu.com', 'incorrecta');
    } catch (e) {
      error = e;
    }

    expect(error, isA<AuthError>());
    expect(
      AuthController.mensajeErrorAcceso(error!),
      'Correo o contrasena incorrectos.',
    );
    expect(controller.session, isNull);
  });

  test('mensajeErrorAcceso distingue límite de intentos y red caída', () {
    expect(
      AuthController.mensajeErrorAcceso(AuthError(AuthFailure.tooManyAttempts)),
      'Demasiados intentos. Espera un minuto y vuelve a probar.',
    );
    expect(
      AuthController.mensajeErrorAcceso(AuthError(AuthFailure.network)),
      'No pudimos conectar. Revisa tu conexion e intenta de nuevo.',
    );
    expect(
      AuthController.mensajeErrorAcceso(
        AuthError(AuthFailure.emailNotConfirmed),
      ),
      'Tu correo aun no esta confirmado. Revisa tu bandeja.',
    );
    // Sin AuthError no hubo respuesta del servidor: fue la red.
    expect(
      AuthController.mensajeErrorAcceso(Exception('boom')),
      'No pudimos conectar. Revisa tu conexion e intenta de nuevo.',
    );
  });

  test(
    'changePassword con actual equivocada: Wrong... y NO cambia nada',
    () async {
      final port = FakeAuthPort(profileRow: perfilCliente);
      final controller = await makeController(port);
      await controller.signIn('cliente@sozu.com', 'secreta123');

      await expectLater(
        controller.changePassword('incorrecta', 'NuevaSegura9'),
        throwsA(isA<WrongCurrentPasswordError>()),
      );
      expect(port.log, isNot(contains('updatePassword')));
      expect(port.password, 'secreta123');
    },
  );

  test(
    'changePassword sin red: propaga AuthError, no acusa contraseña mala',
    () async {
      final port = FakeAuthPort(profileRow: perfilCliente);
      final controller = await makeController(port);
      await controller.signIn('cliente@sozu.com', 'secreta123');

      port.nextFailure = AuthFailure.network;
      await expectLater(
        controller.changePassword('secreta123', 'NuevaSegura9'),
        throwsA(
          isA<AuthError>().having(
            (e) => e.reason,
            'reason',
            AuthFailure.network,
          ),
        ),
      );
      expect(port.log, isNot(contains('updatePassword')));
    },
  );

  test(
    'changePassword feliz: verifica, cambia y limpia el flag, en orden',
    () async {
      final port = FakeAuthPort(profileRow: perfilCliente);
      final controller = await makeController(port);
      await controller.signIn('cliente@sozu.com', 'secreta123');
      port.log.clear();

      await controller.changePassword('secreta123', 'NuevaSegura9');

      expect(
        port.log,
        containsAllInOrder([
          'verifyPassword',
          'updatePassword',
          'markPasswordChanged',
        ]),
      );
      expect(port.password, 'NuevaSegura9');
    },
  );

  test('cierre de sesión emitido por el puerto limpia el perfil', () async {
    final port = FakeAuthPort(profileRow: perfilCliente);
    final controller = await makeController(port);
    await controller.signIn('cliente@sozu.com', 'secreta123');
    await pumpEventQueue();
    expect(controller.profile, isNotNull);

    port.emitSession(null);
    await pumpEventQueue();

    expect(controller.session, isNull);
    expect(controller.profile, isNull);
  });

  test('signOut revoca en el servidor vía el puerto', () async {
    final port = FakeAuthPort(profileRow: perfilCliente);
    final controller = await makeController(port);
    await controller.signIn('cliente@sozu.com', 'secreta123');
    await pumpEventQueue();

    await controller.signOut();
    await pumpEventQueue();

    expect(port.log, contains('signOut'));
    expect(controller.session, isNull);
    expect(controller.profile, isNull);
    expect(controller.locked, isFalse);
  });
}
