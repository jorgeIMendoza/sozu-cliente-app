import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/core/backend_env.dart';
import 'package:sozu_cliente_app/core/secure_session_storage.dart';
import 'package:sozu_cliente_app/core/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sozu_cliente_app/app/light_theme_lock.dart';
import 'package:sozu_cliente_app/shared/providers/theme_provider.dart';
import 'package:sozu_cliente_app/shared/providers/update_prompt_provider.dart';
import 'package:sozu_cliente_app/router.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/features/auth/components/inactivity_watcher.dart';
import 'package:sozu_cliente_app/app/preview_banner.dart';
import 'package:sozu_cliente_app/app/push_registrar.dart';
import 'package:sozu_cliente_app/app/version_gate.dart';

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
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await dotenv.load(fileName: 'assets/env');
  await initializeDateFormatting('es_MX');

  final url = backendUrl;
  final anonKey = backendAnonKey;
  if (url.isEmpty || anonKey.isEmpty) {
    throw StateError(
      'Faltan SUPABASE_URL o SUPABASE_ANON_KEY. Copia .env.example a assets/env.',
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

  // Se resuelve ANTES de arrancar: el aviso de actualización decide si sale en
  // el primer frame, y leerlo asíncrono ahí dentro lo haría parpadear.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        updatePromptStoreProvider.overrideWithValue(UpdatePromptStore(prefs)),
      ],
      child: const SozuApp(),
    ),
  );
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
        child: LightThemeLock(
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
