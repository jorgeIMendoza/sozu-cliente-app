import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/features/auth/components/login_form.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import 'fake_auth_port.dart';

/// El acceso administrador NO se activa desde esta pantalla: lo da el permiso
/// del rol (`canManageClientApp`) y el destino post-login sale del perfil, igual
/// en web y en móvil.
///
/// Hubo dos interruptores manuales, Ctrl+Shift+A y un long-press de 1.5 s sobre
/// el sello de versión. Los dos murieron al conceder el acceso por rol. Lo que
/// este archivo protege ahora es que **no vuelvan**: el sello es texto inerte y
/// sostenerlo no enciende nada.
void main() {
  /// Con margen sobre el umbral que tenía el gesto viejo (1.5 s): si alguien lo
  /// reintroduce con el mismo threshold, el test lo caza.
  const holdWithMargin = Duration(milliseconds: 1600);

  /// Etiqueta de la pastilla que pintaba el modo admin. Ya no existe; se
  /// conserva como sonda: si reaparece, el gesto volvió.
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

  /// Sostiene el sello. `tester.longPress` presiona `kLongPressTimeout` (500 ms),
  /// un tercio del umbral que tenía el gesto viejo, así que no probaría nada.
  Future<void> holdVersionStamp(
    WidgetTester tester, {
    Duration duration = holdWithMargin,
  }) async {
    final gesture = await tester.startGesture(tester.getCenter(versionStamp()));
    await tester.pump(duration);
    await gesture.up();
    await tester.pump();
  }

  testWidgets('sostener el sello de versión NO activa nada', (tester) async {
    await pumpLoginForm(tester);

    await holdVersionStamp(tester);
    await tester.pump();

    expect(
      find.text(badgeLabel),
      findsNothing,
      reason:
          'el acceso admin lo da el rol; si vuelve un interruptor manual aquí, '
          'el flujo de web y móvil se separa otra vez',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el sello es texto: ni botón ni superficie pulsable', (
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

    // Nada de ripple, hover ni cursor de mano: es el pie de la pantalla, no un
    // control.
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
  });

  // -------------------------------------------------------------------------
  // Botón de biometría
  // -------------------------------------------------------------------------

  const biometricLabel = 'Entrar con huella o rostro';

  /// Hace que secure storage responda como si la biometría estuviera activada y
  /// con refresh token guardado, que es lo único que `canSignIn()`
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
  /// prompt: `authenticate()` devuelve false y el boton queda como reintento.
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
    // El botón aparece tras los awaits de `canSignIn()`, no en el
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
    // del boton dependia de `canSignIn()` (activada Y con token), asi
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

  testWidgets('el botón de huella NO se esconde por sostener el sello', (
    tester,
  ) async {
    // Antes el modo admin manual lo ocultaba, porque la biometría es solo para
    // usuarios del portal y la pastilla era la única señal antes de autenticar.
    // Ya no hace falta: solo se enrola quien tiene acceso al portal, y un
    // enrolamiento viejo de una cuenta no-cliente se apaga al entrar.
    mockBiometricsEnabled(enabled: true);
    final prompts = mockBiometricPromptAlwaysRejected();
    await pumpLoginForm(tester);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text(biometricLabel), findsOneWidget);
    // El prompt automatico del montaje, el unico que debe existir.
    expect(prompts.value, 1);

    await holdVersionStamp(tester);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text(biometricLabel), findsOneWidget);
    expect(find.text(badgeLabel), findsNothing);
    expect(prompts.value, 1, reason: 'sostener el sello no pide la huella');
  });
}

/// Caja mutable para contar prompts desde el handler del canal.
class _PromptCounter {
  int value = 0;
}
