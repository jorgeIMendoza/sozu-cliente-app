import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/profile/adapters/profile_adapter.dart';
import 'package:sozu_cliente_app/features/client/profile/providers/profile_providers.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

import '../client_test_support.dart';
import 'fake_profile_port.dart';

/// Providers de `profile` contra el PUERTO (sin Supabase) y la
/// reconstruccion del puerto al cambiar la impersonacion.
void main() {
  test('profileProvider resuelve contra el puerto', () async {
    final port = FakeProfilePort();
    final container = makeClientContainer(
      overrides: [profilePortProvider.overrideWithValue(port)],
    );

    final perfil = await container.read(profileProvider.future);

    expect(perfil.nombreLegal, 'Alex Hernández');
    expect(port.log, ['profile']);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeProfilePort()..nextFailure = ApiError(403, 'no_persona');
    final container = makeClientContainer(
      overrides: [profilePortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(profileProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'no_persona')),
    );
  });

  test('cambiar la impersonacion reconstruye el puerto con el id', () {
    final container = makeClientContainer();

    final antes = container.read(profilePortProvider) as ProfileAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante = container.read(profilePortProvider) as ProfileAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);

    container.read(impersonationProvider).clear();
    expect(
      (container.read(profilePortProvider) as ProfileAdapter).impersonate,
      isNull,
    );
  });
}
