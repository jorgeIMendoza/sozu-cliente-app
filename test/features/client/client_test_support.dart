import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';

/// Stub minimo de [AuthPort] para construir la impersonacion real: sin sesion
/// y sin cambios. `noSuchMethod` cubre el resto del contrato, que estos tests
/// no ejercitan (y que la feature auth puede seguir evolucionando).
class _StubAuthPort implements AuthPort {
  final _changes = StreamController<AuthSession?>.broadcast();

  @override
  AuthSession? get currentSession => null;

  @override
  Stream<AuthSession?> get sessionChanges => _changes.stream;

  void dispose() {
    unawaited(_changes.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Id de usuario autenticado mutable, para simular un cambio de sesion.
final testUserIdProvider = StateProvider<String?>((ref) => 'user-1');

/// Container para probar los providers de `client`: impersonacion REAL (sobre
/// un stub de AuthPort) y el id de sesion tomado de [testUserIdProvider], de
/// modo que los tests puedan ejercitar la reconstruccion en cascada de los
/// puertos.
ProviderContainer makeClientContainer({List<Override> overrides = const []}) {
  final authPort = _StubAuthPort();
  final container = ProviderContainer(
    overrides: [
      authUserIdProvider.overrideWith((ref) => ref.watch(testUserIdProvider)),
      // ChangeNotifierProvider dispone el controller al morir el container;
      // un ref.onDispose(controller.dispose) aqui seria un doble dispose.
      impersonationProvider.overrideWith(
        (ref) => ImpersonationController(authPort),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  addTearDown(authPort.dispose);
  return container;
}
