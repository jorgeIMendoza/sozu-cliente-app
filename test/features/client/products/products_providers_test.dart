import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/products/adapters/products_adapter.dart';
import 'package:sozu_cliente_app/features/client/products/providers/products_providers.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

import '../client_test_support.dart';
import 'fake_products_port.dart';

/// Providers de `products` contra el PUERTO (sin Supabase) y la
/// reconstruccion del puerto al cambiar la impersonacion.
void main() {
  test('productsProvider resuelve contra el puerto', () async {
    final port = FakeProductsPort();
    final container = makeClientContainer(
      overrides: [productsPortProvider.overrideWithValue(port)],
    );

    final data = await container.read(productsProvider.future);

    expect(data.propiedades, hasLength(1));
    expect(port.log, ['products']);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeProductsPort()
      ..nextFailure = ApiError(403, 'forbidden_role');
    final container = makeClientContainer(
      overrides: [productsPortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(productsProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'forbidden_role')),
    );
  });

  test('cambiar la impersonacion reconstruye el puerto con el id', () {
    final container = makeClientContainer();

    final antes = container.read(productsPortProvider) as ProductsAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante = container.read(productsPortProvider) as ProductsAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);
  });
}
