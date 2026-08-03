import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/properties/adapters/properties_adapter.dart';
import 'package:sozu_cliente_app/features/client/properties/providers/properties_providers.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

import '../client_test_support.dart';
import 'fake_properties_port.dart';

/// Providers de `properties` contra el PUERTO (sin Supabase) y la
/// reconstruccion del puerto al cambiar la impersonacion.
void main() {
  test('los providers de datos resuelven contra el puerto', () async {
    final port = FakePropertiesPort();
    final container = makeClientContainer(
      overrides: [propertiesPortProvider.overrideWithValue(port)],
    );

    final props = await container.read(propertiesProvider.future);
    final pagos = await container.read(paymentsProvider.future);
    final detalle = await container.read(propertyDetailProvider(11).future);
    final edo = await container.read(accountStatementProvider(42).future);

    expect(props.enAdquisicion.single.proyecto, 'Toreo');
    expect(pagos.saldoPendiente, 600.0);
    expect(detalle.id, 11);
    expect(edo.saldoPendiente, 600.0);
    expect(port.log, [
      'properties',
      'payments',
      'property:11',
      'accountStatement:42',
    ]);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakePropertiesPort()
      ..nextFailure = ApiError(403, 'forbidden_role');
    final container = makeClientContainer(
      overrides: [propertiesPortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(paymentsProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'forbidden_role')),
    );
  });

  test('cambiar la impersonacion reconstruye el puerto con el id', () {
    final container = makeClientContainer();

    final antes = container.read(propertiesPortProvider) as PropertiesAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante = container.read(propertiesPortProvider) as PropertiesAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);

    container.read(impersonationProvider).clear();
    expect(
      (container.read(propertiesPortProvider) as PropertiesAdapter).impersonate,
      isNull,
    );
  });
}
