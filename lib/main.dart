import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/core/secure_session_storage.dart';
import 'package:sozu_cliente_app/core/url_strategy.dart';
import 'package:sozu_cliente_app/shared/providers/theme_provider.dart';
import 'package:sozu_cliente_app/router.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/features/auth/components/inactivity_watcher.dart';
import 'package:sozu_cliente_app/widgets/preview_banner.dart';
import 'package:sozu_cliente_app/widgets/push_registrar.dart';
import 'package:sozu_cliente_app/widgets/version_gate.dart';

/// SOZU - Portal del Cliente (Flutter).
/// Seguridad: SOLO anon key + JWT; sesión en secure storage; todo dato
/// sensible vía Edge Functions (ver CLAUDE.md).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // URLs limpias en web (/login, no /#/login). No-op en móvil.
  usarUrlSinHash();

  // Edge-to-edge (Android 15 / SDK 35): dibuja detrás de las barras del
  // sistema y las transparenta para que se vean sobre la UI de SOZU. Flutter
  // 3.29+ ya lo hace por defecto; esto lo deja explícito y fija el contraste
  // de los íconos (barras transparentes, íconos oscuros/claros según fondo).
  // Los insets los respetan Scaffold + SafeArea en cada pantalla.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await dotenv.load(fileName: 'assets/env');
  await initializeDateFormatting('es_MX');

  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
  if (url == null || anonKey == null) {
    throw StateError(
      'Faltan SUPABASE_URL o SUPABASE_ANON_KEY. Copia .env.example a .env.',
    );
  }

  await Supabase.initialize(
    url: url,
    // Key legacy "anon" (pública). Cuando SOZU migre a publishable key,
    // cambiar a `publishableKey`.
    // ignore: deprecated_member_use
    anonKey: anonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(),
      autoRefreshToken: true,
    ),
  );

  runApp(const ProviderScope(child: SozuApp()));
}

class SozuApp extends ConsumerWidget {
  const SozuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider).mode;

    return MaterialApp.router(
      title: 'SOZU - Portal del Cliente',
      debugShowCheckedModeBanner: false,
      theme: sozuLightTheme(),
      darkTheme: sozuDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      // SozuAdaptiveTokens resuelve la densidad del design system según el ancho
      // disponible y reinyecta los tokens. Va lo más arriba posible: el
      // ThemeData se construye sin saber cuánto mide la ventana, así que sin
      // esto `context.s` siempre devolvería la densidad `comfortable`. Por eso
      // envuelve a `VersionGate` y no al revés.
      builder: (context, child) => SozuAdaptiveTokens(
        child: PortalLightLock(
          child: VersionGate(
            child: InactivityWatcher(
              child: PushRegistrar(
                child: PreviewBanner(child: child ?? const SizedBox.shrink()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fuerza tema claro en el portal web ancho, donde el oscuro NO está listo.
///
/// El portal pinta con el shim `PortalColors`, cuyas constantes son claras y no
/// dependen del tema. En oscuro solo cambiaría lo ya migrado a `context.s`, y el
/// resultado es texto claro sobre fondos claros. En móvil/angosto no pasa: esas
/// pantallas ya leen los roles de color, así que ahí el selector sí manda.
///
/// El candado usa `isPortalMode` a propósito, aunque esté deprecado: tiene que
/// decidir con el MISMO criterio que las 22 pantallas que ramifican por él
/// (incluido su `kIsWeb`, que deja fuera a una tablet Android ancha). Si el
/// candado y las pantallas discrepan, salen temas mezclados. Migra cuando ellas
/// migren a `context.bp`, no antes.
class PortalLightLock extends StatelessWidget {
  final Widget child;

  const PortalLightLock({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use_from_same_package
    if (!isPortalMode(context)) return child;
    return Theme(data: sozuLightTheme(), child: child);
  }
}
