import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/home/adapters/home_adapter.dart';
import 'package:sozu_cliente_app/features/client/home/providers/home_providers.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

import '../client_test_support.dart';
import 'fake_home_port.dart';

/// Providers de `home` contra el PUERTO (sin Supabase) y, lo critico de la
/// tanda, la reconstruccion del puerto al cambiar la impersonacion o la
/// sesion: si esto se rompe, un admin ve datos de otro cliente.
void main() {
  test('los providers de datos resuelven contra el puerto', () async {
    final port = FakeHomePort();
    final container = makeClientContainer(
      overrides: [homePortProvider.overrideWithValue(port)],
    );

    final resumen = await container.read(summaryProvider.future);
    final menu = await container.read(menuProvider.future);
    final notif = await container.read(notificationsProvider.future);

    expect(resumen.nombreLegal, 'Alex Hernández');
    expect(menu.map((m) => m.route), ['/inicio', '/pagos']);
    expect(notif.noLeidas, 2);
    expect(port.log, ['summary', 'menu', 'notifications']);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeHomePort()..nextFailure = ApiError(403, 'forbidden_role');
    final container = makeClientContainer(
      overrides: [homePortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(summaryProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'forbidden_role')),
    );
  });

  test('cambiar la impersonacion reconstruye el puerto con el id', () {
    final container = makeClientContainer();

    final antes = container.read(homePortProvider) as HomeAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante = container.read(homePortProvider) as HomeAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);

    container.read(impersonationProvider).clear();
    final despues = container.read(homePortProvider) as HomeAdapter;
    expect(despues.impersonate, isNull);
  });

  test('cambiar de usuario autenticado reconstruye el puerto', () {
    final container = makeClientContainer();

    final antes = container.read(homePortProvider);
    container.read(testUserIdProvider.notifier).state = 'user-2';

    expect(identical(container.read(homePortProvider), antes), isFalse);
  });
}
