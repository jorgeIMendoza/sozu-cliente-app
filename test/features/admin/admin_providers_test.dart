import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

import 'fake_admin_port.dart';

/// Lo que fija este archivo es que los providers de admin funcionan contra el
/// PUERTO, no contra Supabase: todo corre con [FakeAdminPort] y ni un test
/// inicializa el backend. Antes esto era imposible (ver ADR 0002).
void main() {
  ProviderContainer makeContainer(FakeAdminPort port) {
    final container = ProviderContainer(
      overrides: [adminPortProvider.overrideWithValue(port)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('adminClientsProvider resuelve la lista del puerto', () async {
    final port = FakeAdminPort();
    final container = makeContainer(port);

    final data = await container.read(adminClientsProvider.future);

    expect(data.clientes, hasLength(2));
    expect(data.clientes.first.nombre, 'Alex Hernández');
    expect(port.log, ['clients']);
  });

  test('adminProjectsProvider resuelve el catálogo del puerto', () async {
    final port = FakeAdminPort();
    final container = makeContainer(port);

    final projects = await container.read(adminProjectsProvider.future);

    expect(projects.map((p) => p.nombre), ['Toreo', 'Reforma']);
    expect(port.log, ['projectCatalog']);
  });

  test('adminOwnersProvider pasa proyecto y unidad al puerto', () async {
    final port = FakeAdminPort();
    final container = makeContainer(port);

    final owners = await container.read(
      adminOwnersProvider((projectId: 1, propertyNumber: '101')).future,
    );
    final empty = await container.read(
      adminOwnersProvider((projectId: 2, propertyNumber: '999')).future,
    );

    expect(owners.single.idPersona, 7);
    expect(empty, isEmpty);
    expect(port.log, ['owners', 'owners']);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeAdminPort()..nextFailure = ApiError(403, 'forbidden_role');
    final container = makeContainer(port);

    await expectLater(
      container.read(adminClientsProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'forbidden_role')),
    );
  });
}
