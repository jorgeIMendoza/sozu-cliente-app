import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/features/auth/components/login_form.dart';
import 'package:sozu_cliente_app/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import 'fake_auth_port.dart';

/// Lo que fija este archivo es el **acceso al modo administrador desde el
/// teléfono**: hasta que existió el long-press del sello de versión, el único
/// camino era Ctrl+Shift+A, un atajo cuyo handler ni se instala en Android/iOS.
///
/// El gesto no es una frontera de seguridad (el permiso real lo da el backend
/// con `administrar_app_clientes`), así que lo que hay que proteger con tests no
/// es el secreto: es que **no se dispare por accidente** y que el sello siga
/// pareciendo texto.
void main() {
  /// Umbral del gesto en `login_form.dart` (`_kAdminHoldDuration`, privado).
  const holdDuration = Duration(milliseconds: 1500);

  /// El umbral con un margen: sostener EXACTAMENTE el deadline es una carrera.
  const holdWithMargin = Duration(milliseconds: 1600);

  const badgeLabel = 'Acceso administrador';

  /// Único andamio de entorno que el formulario exige: **el canal de
  /// flutter_secure_storage respondiendo `null`.** En un test
  /// `defaultTargetPlatform` es Android, así que `BiometricService` sí entra
  /// a leer el flag de biometría; sin handler eso lanza
  /// `MissingPluginException` dentro del fire-and-forget de `initState` y el
  /// test muere por un error asíncrono ajeno al gesto. Devolver `null` es la
  /// respuesta honesta: "no hay biometría guardada".
  ///
  /// El backend NO se toca: `authPortProvider` se sobreescribe con
  /// [FakeAuthPort] en `pumpLoginForm`.
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  /// Monta el formulario como lo monta la app: tema claro forzado (lo hace
  /// `AuthLayout`), tokens adaptativos y el scroll de página.
  ///
  /// El `SingleChildScrollView` reproduce el de `AuthLayout`: sin él, el alto de
  /// un teléfono desbordaría por el andamio del test y no por el formulario, que
  /// es lo que se quiere medir.
  Future<void> pumpLoginForm(
    WidgetTester tester, {
    Size size = const Size(390, 900),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authPortProvider.overrideWithValue(FakeAuthPort())],
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: const Scaffold(body: SingleChildScrollView(child: LoginForm())),
        ),
      ),
    );
    // Deja resolver el `_prepareBiometrics()` que initState dispara sin await.
    await tester.pump();
  }

  Finder versionStamp() => find.text(appVersionLabel);

  /// Sostiene el sello el tiempo pedido. `tester.longPress` NO sirve: presiona
  /// `kLongPressTimeout` (500 ms), un tercio del umbral de este gesto, así que
  /// pasaría por un toque largo cualquiera.
  Future<void> holdVersionStamp(
    WidgetTester tester, {
    Duration duration = holdWithMargin,
  }) async {
    final gesture = await tester.startGesture(tester.getCenter(versionStamp()));
    await tester.pump(duration);
    await gesture.up();
    await tester.pump();
  }

  testWidgets('el long-press del sello de versión enciende el modo admin', (
    tester,
  ) async {
    await pumpLoginForm(tester);
    expect(find.text(badgeLabel), findsNothing);

    await holdVersionStamp(tester);

    expect(
      find.text(badgeLabel),
      findsOneWidget,
      reason: 'la pastilla es el único indicio de que el gesto surtió efecto',
    );
  });

  testWidgets('un segundo long-press lo apaga (es interruptor, no botón)', (
    tester,
  ) async {
    await pumpLoginForm(tester);

    await holdVersionStamp(tester);
    expect(find.text(badgeLabel), findsOneWidget);

    await holdVersionStamp(tester);
    expect(find.text(badgeLabel), findsNothing);
  });

  testWidgets('un toque simple NO enciende el modo admin', (tester) async {
    await pumpLoginForm(tester);

    await tester.tap(versionStamp());
    // El umbral completo y de sobra: si el gesto se disparara tarde, aquí se
    // vería.
    await tester.pump(holdDuration * 2);

    expect(
      find.text(badgeLabel),
      findsNothing,
      reason: 'el pie del login se toca sin querer; 1.5 s es lo que lo evita',
    );
  });

  testWidgets('el sello sigue siendo texto: ni botón ni superficie pulsable', (
    tester,
  ) async {
    await pumpLoginForm(tester);
    final handle = tester.ensureSemantics();
    final stamp = versionStamp();

    final node = tester.getSemantics(stamp);
    expect(node.label, appVersionLabel);
    expect(node.flagsCollection.isButton, isFalse);
    expect(node.flagsCollection.isLink, isFalse);
    expect(
      find.ancestor(
        of: stamp,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.button ?? false),
        ),
      ),
      findsNothing,
    );

    // Nada de ripple, hover ni cursor de mano: si el sello se ve pulsable, se
    // toca por accidente. Por eso el gesto va en un RawGestureDetector y no en
    // SPressable / InkWell.
    expect(
      find.ancestor(of: stamp, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.ancestor(of: stamp, matching: find.byType(SPressable)),
      findsNothing,
    );

    handle.dispose();
  });

  testWidgets('el formulario se monta a 360 px sin overflow', (tester) async {
    await pumpLoginForm(tester, size: const Size(360, 800));

    expect(tester.takeException(), isNull);
    expect(find.byType(LoginForm), findsOneWidget);

    // El gesto también tiene que servir en el ancho más angosto que se soporta:
    // es justo donde vive el usuario que no tiene teclado.
    await holdVersionStamp(tester);
    expect(find.text(badgeLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // -------------------------------------------------------------------------
  // Botón de biometría
  // -------------------------------------------------------------------------

  const biometricLabel = 'Entrar con huella o rostro';

  /// Hace que secure storage responda como si la biometría estuviera activada y
  /// con refresh token guardado, que es lo único que `disponibleParaLogin()`
  /// consulta. Las claves son las de `BiometricService` (privadas allá).
  void mockBiometricsEnabled({
    required bool enabled,
    bool withToken = true,
    bool withUserId = true,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            if (call.method != 'read' || !enabled) return null;
            final args = call.arguments as Map<Object?, Object?>;
            return switch (args['key'] as String?) {
              'sozu_biometria_habilitada' => 'true',
              'sozu_biometria_user_id' => withUserId ? 'user-de-prueba' : null,
              'sozu_biometria_refresh_token' =>
                withToken ? 'refresh-token-de-prueba' : null,
              _ => null,
            };
          },
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async => null,
          ),
    );
  }

  /// Hace que la huella se pida pero SIEMPRE se rechace, y cuenta cuantas veces
  /// se pidio.
  ///
  /// El canal es el de `DefaultLocalAuthPlatform`
  /// (`plugins.flutter.io/local_auth`), NO los canales pigeon de
  /// `local_auth_android`: en un test no corre el registrant de la plataforma,
  /// asi que `LocalAuthPlatform.instance` se queda en la implementacion por
  /// defecto. Mockear los de pigeon no falla, simplemente no hace nada, y el
  /// prompt del montaje revienta con `MissingPluginException` desde un
  /// fire-and-forget.
  ///
  /// Responder `false` en vez de un error reproduce el caso real de cancelar el
  /// prompt: `autenticar()` devuelve false y el boton queda como reintento.
  _PromptCounter mockBiometricPromptAlwaysRejected() {
    final counter = _PromptCounter();
    const channel = MethodChannel('plugins.flutter.io/local_auth');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'authenticate':
              counter.value++;
              return false;
            case 'isDeviceSupported':
            case 'deviceSupportsBiometrics':
              return true;
            case 'getAvailableBiometrics':
              return <String>['fingerprint'];
            default:
              return false;
          }
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    return counter;
  }

  testWidgets('sin biometría guardada NO se ofrece el botón de huella', (
    tester,
  ) async {
    mockBiometricsEnabled(enabled: false);
    mockBiometricPromptAlwaysRejected();
    await pumpLoginForm(tester);

    expect(find.text(biometricLabel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con biometría guardada se ofrece el botón de huella', (
    tester,
  ) async {
    mockBiometricsEnabled(enabled: true);
    mockBiometricPromptAlwaysRejected();
    await pumpLoginForm(tester);
    // El botón aparece tras los awaits de `disponibleParaLogin()`, no en el
    // primer frame. `pumpAndSettle` NO sirve: el prompt automático deja el botón
    // en estado `loading` y ese spinner no termina nunca.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text(biometricLabel), findsOneWidget);
  });

  testWidgets('activada pero sin token guardado: el botón se ofrece igual', (
    tester,
  ) async {
    // El caso real: el refresh token guardado se invalido. Antes la visibilidad
    // del boton dependia de `disponibleParaLogin()` (activada Y con token), asi
    // que el boton desaparecia y se leia como que la biometria se rompio. Ahora
    // basta que el usuario la haya activado.
    mockBiometricsEnabled(enabled: true, withToken: false);
    final prompts = mockBiometricPromptAlwaysRejected();
    await pumpLoginForm(tester);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text(biometricLabel), findsOneWidget);
    // Sin token no se pide la huella al montar: no podria entrar de todas formas.
    expect(prompts.value, 0);
  });

  testWidgets('la pastilla de admin esconde el botón de huella', (
    tester,
  ) async {
    // La pastilla puesta significa que quien entra NO es cliente, y la
    // biometria es solo para clientes. Es la unica senal disponible antes de
    // autenticar: el token guardado es opaco y el rol se sabe con el perfil ya
    // cargado.
    mockBiometricsEnabled(enabled: true);
    final prompts = mockBiometricPromptAlwaysRejected();
    await pumpLoginForm(tester);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text(biometricLabel), findsOneWidget);
    // El prompt automatico del montaje, el unico que debe existir.
    expect(prompts.value, 1);

    await holdVersionStamp(tester); // pone la pastilla
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text(badgeLabel), findsOneWidget);
    expect(find.text(biometricLabel), findsNothing);
    expect(
      prompts.value,
      1,
      reason: 'poner la pastilla de admin no debe pedir la huella',
    );
  });

  testWidgets('quitar la pastilla devuelve el botón de huella', (tester) async {
    mockBiometricsEnabled(enabled: true);
    mockBiometricPromptAlwaysRejected();
    await pumpLoginForm(tester);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    await holdVersionStamp(tester); // pone
    await tester.pump();
    expect(find.text(biometricLabel), findsNothing);

    await holdVersionStamp(tester); // quita
    await tester.pump();

    expect(find.text(badgeLabel), findsNothing);
    expect(find.text(biometricLabel), findsOneWidget);
  });
}

/// Caja mutable para contar prompts desde el handler del canal.
class _PromptCounter {
  int value = 0;
}
