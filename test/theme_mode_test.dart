import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/app/light_theme_lock.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import 'features/auth/fake_auth_port.dart';

/// El candado del tema: claro en el area de acceso, la preferencia del usuario
/// una vez dentro del portal. El criterio es el estado de sesion, NO el ancho ni
/// la plataforma.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clientProfile = UserProfile(
    displayName: 'Cliente de Prueba',
    email: 'cliente@sozu.com',
    roleName: 'Cliente',
    personId: 7,
  );

  /// BiometricService lee secure storage al construirse.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  /// Brillo que recibe el hijo del candado, con el modo oscuro pedido.
  Future<Brightness> brilloBajoElCandado(
    WidgetTester tester, {
    required bool conSesion,
    UserProfile? perfil,
  }) async {
    late Brightness visto;
    final port = FakeAuthPort(profileRow: perfil ?? clientProfile);
    final container = ProviderContainer(
      overrides: [authPortProvider.overrideWithValue(port)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: sozuLightTheme(),
          darkTheme: sozuDarkTheme(),
          themeMode: ThemeMode.dark,
          home: LightThemeLock(
            child: Builder(
              builder: (context) {
                visto = Theme.of(context).brightness;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    if (conSesion) {
      await container
          .read(authProvider)
          .signIn('cliente@sozu.com', 'secreta123');
    }
    await tester.pumpAndSettle();
    return visto;
  }

  group('LightThemeLock', () {
    testWidgets('sin sesion el acceso va claro aunque se pida oscuro', (
      tester,
    ) async {
      expect(
        await brilloBajoElCandado(tester, conSesion: false),
        Brightness.light,
      );
    });

    testWidgets('dentro del portal manda la preferencia del usuario', (
      tester,
    ) async {
      expect(
        await brilloBajoElCandado(tester, conSesion: true),
        Brightness.dark,
      );
    });

    testWidgets('con cambio de contrasena pendiente todavia no entro', (
      tester,
    ) async {
      const temporal = UserProfile(
        displayName: 'Cliente de Prueba',
        email: 'cliente@sozu.com',
        roleName: 'Cliente',
        personId: 7,
        requiresPasswordChange: true,
      );
      expect(
        await brilloBajoElCandado(tester, conSesion: true, perfil: temporal),
        Brightness.light,
      );
    });
  });
}
