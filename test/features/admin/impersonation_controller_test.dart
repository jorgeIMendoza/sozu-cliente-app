import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';

import '../auth/fake_auth_port.dart';

/// [ImpersonationController] contra [FakeAuthPort]: el target de "Ver como"
/// no debe sobrevivir a un cambio de usuario en la misma pestaña.
void main() {
  AuthSession session(String userId) => AuthSession(
    userId: userId,
    email: '$userId@sozu.com',
    lastSignInAt: DateTime.utc(2026, 8, 1, 12),
    refreshToken: 'rt-$userId',
  );

  test('cambiar de usuario limpia el cliente impersonado', () async {
    final port = FakeAuthPort();
    port.emitSession(session('admin-a'));
    final controller = ImpersonationController(port);
    addTearDown(controller.dispose);

    controller.select(7, 'Alex Hernández', 'alex@x.com');
    expect(controller.active, isTrue);

    port.emitSession(session('admin-b'));
    await pumpEventQueue();

    expect(controller.active, isFalse);
    expect(controller.clientId, isNull);
    expect(controller.clientName, isNull);
  });

  test('cerrar sesión (session null) también limpia el target', () async {
    final port = FakeAuthPort();
    port.emitSession(session('admin-a'));
    final controller = ImpersonationController(port);
    addTearDown(controller.dispose);

    controller.select(7, 'Alex Hernández', 'alex@x.com');
    port.emitSession(null);
    await pumpEventQueue();

    expect(controller.active, isFalse);
  });

  test('un refresh del MISMO usuario no tumba la impersonación', () async {
    final port = FakeAuthPort();
    port.emitSession(session('admin-a'));
    final controller = ImpersonationController(port);
    addTearDown(controller.dispose);

    controller.select(7, 'Alex Hernández', 'alex@x.com');
    port.emitSession(session('admin-a'));
    await pumpEventQueue();

    expect(controller.active, isTrue);
    expect(controller.clientId, 7);
  });
}
