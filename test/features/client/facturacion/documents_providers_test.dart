import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/facturacion/adapters/documents_adapter.dart';
import 'package:sozu_cliente_app/features/client/facturacion/providers/documents_providers.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

import '../client_test_support.dart';
import 'fake_documents_port.dart';

/// Providers de `documents` contra el PUERTO (sin Supabase) y la
/// reconstruccion del puerto al cambiar la impersonacion.
void main() {
  test('los providers de datos resuelven contra el puerto', () async {
    final port = FakeDocumentsPort();
    final container = makeClientContainer(
      overrides: [documentsPortProvider.overrideWithValue(port)],
    );

    final docs = await container.read(documentsProvider.future);

    expect(docs.total, 1);
    expect(port.log, ['documents']);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeDocumentsPort()
      ..nextFailure = ApiError(403, 'forbidden_role');
    final container = makeClientContainer(
      overrides: [documentsPortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(documentsProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'forbidden_role')),
    );
  });

  test('cambiar la impersonacion reconstruye el puerto con el id', () {
    final container = makeClientContainer();

    final antes = container.read(documentsPortProvider) as DocumentsAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante = container.read(documentsPortProvider) as DocumentsAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);
  });
}
