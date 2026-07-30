import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/features/auth/components/login_form.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Montar `LoginForm` exige dos cosas del entorno, y las dos son mínimas a
  /// propósito:
  ///
  /// 1. **Supabase inicializado.** `AuthController` toma
  ///    `Supabase.instance.client` en un inicializador de campo, así que ni
  ///    siquiera un `overrideWith` con una subclase lo evita: el constructor
  ///    base corre igual. Se inicializa con `EmptyLocalStorage` para que no
  ///    toque plugins ni intente recuperar sesión; sin credenciales reales no
  ///    hay red que golpear.
  /// 2. **El canal de flutter_secure_storage respondiendo `null`.** En un test
  ///    `defaultTargetPlatform` es Android, así que `BiometricService` sí entra
  ///    a leer el flag de biometría; sin handler eso lanza
  ///    `MissingPluginException` dentro del fire-and-forget de `initState` y el
  ///    test muere por un error asíncrono ajeno al gesto. Devolver `null` es la
  ///    respuesta honesta: "no hay biometría guardada".
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        // El almacén de PKCE es aparte de `localStorage` y por defecto es
        // SharedPreferences, o sea otro plugin que no existe en un test.
        pkceAsyncStorage: _InMemoryPkceStorage(),
        // Sin observador de deep links: arrastraría el plugin app_links y esta
        // pantalla no llega por URL en un test.
        detectSessionInUri: false,
      ),
      debug: false,
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
}

/// Almacén de PKCE en memoria: 12 líneas contra mockear el canal de
/// SharedPreferences. Nunca se escribe nada porque el test no autentica; existe
/// solo para que `Supabase.initialize` no busque un plugin.
class _InMemoryPkceStorage implements GotrueAsyncStorage {
  const _InMemoryPkceStorage();

  @override
  Future<String?> getItem({required String key}) async => null;

  @override
  Future<void> setItem({required String key, required String value}) async {}

  @override
  Future<void> removeItem({required String key}) async {}
}
