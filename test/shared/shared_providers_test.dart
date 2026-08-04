import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';

import 'fake_app_version_port.dart';
import 'fake_push_port.dart';

/// Lo que fija este archivo es que los providers transversales funcionan contra
/// los PUERTOS, no contra Supabase: todo corre con dobles y ni un test
/// inicializa el backend (ver ADR 0002).
void main() {
  ProviderContainer makeContainer(List<Override> overrides) {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container;
  }

  group('pushPortProvider', () {
    test('el doble recibe token y preferencia sin tocar red', () async {
      final port = FakePushPort();
      final container = makeContainer([
        pushPortProvider.overrideWithValue(port),
      ]);

      final push = container.read(pushPortProvider);
      await push.registerToken(token: 'tok-1', platform: 'android');
      await push.setEnabled(false);

      expect(port.tokens, {'tok-1': 'android'});
      expect(await push.enabled(), isFalse);
      expect(port.log, ['registerToken', 'setEnabled', 'enabled']);
    });

    test('un fallo del puerto sale como ApiError', () async {
      final port = FakePushPort()
        ..nextFailure = ApiError(403, 'forbidden_role');
      final container = makeContainer([
        pushPortProvider.overrideWithValue(port),
      ]);

      await expectLater(
        container.read(pushPortProvider).enabled(),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'forbidden_role'),
        ),
      );
    });
  });

  group('appVersionGateProvider', () {
    test('resuelve la info del puerto', () async {
      final port = FakeAppVersionPort(
        info: const AppVersionInfo(minVersion: '2.1.0', forceUpdate: true),
      );
      final container = makeContainer([
        appVersionPortProvider.overrideWithValue(port),
      ]);

      final info = await container.read(appVersionGateProvider.future);

      expect(info?.minVersion, '2.1.0');
      expect(info?.forceUpdate, isTrue);
      expect(port.calls, 1);
    });

    test('un fallo degrada a null: la app nunca gatea por error', () async {
      final port = FakeAppVersionPort()
        ..nextFailure = ApiError(0, 'network_error');
      final container = makeContainer([
        appVersionPortProvider.overrideWithValue(port),
      ]);

      expect(await container.read(appVersionGateProvider.future), isNull);
    });
  });
}
