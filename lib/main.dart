import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/secure_session_storage.dart';
import 'core/theme.dart';
import 'providers/theme_provider.dart';
import 'router.dart';
import 'widgets/inactivity_watcher.dart';

/// SOZU — Portal del Cliente (Flutter).
/// Seguridad: SOLO anon key + JWT; sesión en secure storage; todo dato
/// sensible vía Edge Functions (ver CLAUDE.md).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    final themeMode = ref.watch(themeProvider).mode;
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SOZU — Portal del Cliente',
      debugShowCheckedModeBanner: false,
      theme: sozuLightTheme(),
      darkTheme: sozuDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) =>
          InactivityWatcher(child: child ?? const SizedBox.shrink()),
    );
  }
}
