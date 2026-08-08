import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/expediente/adapters/expediente_adapter.dart';
import 'package:sozu_cliente_app/features/client/expediente/providers/expediente_providers.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

import '../client_test_support.dart';
import 'fake_expediente_port.dart';

/// Providers del expediente contra el PUERTO (sin Supabase).
void main() {
  test('identityFile resuelve contra el puerto', () async {
    final port = FakeExpedientePort();
    final container = makeClientContainer(
      overrides: [expedientePortProvider.overrideWithValue(port)],
    );

    final expediente = await container.read(identityFileProvider.future);

    expect(expediente.subidos, 3);
    expect(port.log, ['identityFile']);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeExpedientePort()
      ..nextFailure = ApiError(403, 'forbidden_role');
    final container = makeClientContainer(
      overrides: [expedientePortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(identityFileProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'forbidden_role')),
    );
  });

  test('uploadDocument propaga DocumentoInvalidoError', () async {
    final port = FakeExpedientePort()
      ..nextFailure = DocumentoInvalidoError('El PDF no es una CSF valida');
    final container = makeClientContainer(
      overrides: [expedientePortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container
          .read(expedientePortProvider)
          .uploadDocument(typeId: 6, fileName: 'csf.pdf', fileBase64: ''),
      throwsA(isA<DocumentoInvalidoError>()),
    );
  });

  test('cambiar la impersonacion reconstruye el puerto con el id', () {
    final container = makeClientContainer();

    final antes = container.read(expedientePortProvider) as ExpedienteAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante = container.read(expedientePortProvider) as ExpedienteAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);
  });
}
