import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';
import 'package:sozu_cliente_app/shared/providers/update_prompt_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/version_gate.dart';

/// Los dos niveles del gate son deliberadamente distintos:
///
/// * FORZADO: pantalla completa, sin salida. Es la palanca de negocio.
/// * SUAVE: sale una vez, se pospone, y se calla hasta el dia siguiente o hasta
///   que salga una version posterior.
///
/// Antes el suave era una franja fija en todas las pantallas sin manera de
/// descartarla: molestaba siempre y aun asi no obligaba a nada.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> montar(WidgetTester tester, AppVersionInfo? info) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionGateProvider.overrideWith((ref) async => info),
          updatePromptStoreProvider.overrideWithValue(UpdatePromptStore(prefs)),
        ],
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: const VersionGate(child: Scaffold(body: Text('contenido'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// El reset va aqui y no en un `tearDown` porque Flutter verifica que no
  /// queden overrides ANTES de ejecutarlo, y el test falla aunque el aserto sea
  /// correcto.
  Future<void> conPlataforma(
    TargetPlatform plataforma,
    Future<void> Function() cuerpo,
  ) async {
    debugDefaultTargetPlatformOverride = plataforma;
    try {
      await cuerpo();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  group('aviso suave (hay version nueva)', () {
    const hayNueva = AppVersionInfo(latestVersion: '9.9.9');

    testWidgets('sale como aviso con salida, no como franja fija', (
      tester,
    ) async {
      await conPlataforma(TargetPlatform.android, () async {
        await montar(tester, hayNueva);

        expect(find.text('Hay una versión nueva'), findsOneWidget);
        expect(find.widgetWithText(SButton, 'Actualizar'), findsOneWidget);
        expect(find.widgetWithText(SButton, 'Ahora no'), findsOneWidget);
      });
    });

    testWidgets('bloquea el toque al fondo mientras esta abierto', (
      tester,
    ) async {
      // Sin el velo se puede seguir usando la app por debajo del aviso.
      await conPlataforma(TargetPlatform.android, () async {
        await montar(tester, hayNueva);
        expect(find.byType(ModalBarrier), findsWidgets);
      });
    });

    testWidgets('"Ahora no" lo cierra y NO vuelve a salir el mismo dia', (
      tester,
    ) async {
      await conPlataforma(TargetPlatform.android, () async {
        await montar(tester, hayNueva);
        await tester.tap(find.widgetWithText(SButton, 'Ahora no'));
        await tester.pumpAndSettle();

        expect(find.text('Hay una versión nueva'), findsNothing);
        expect(find.text('contenido'), findsOneWidget);

        // Reabrir la app: sigue callado.
        await montar(tester, hayNueva);
        expect(find.text('Hay una versión nueva'), findsNothing);
      });
    });

    testWidgets('una version MAS nueva vuelve a preguntar aunque se pospuso', (
      tester,
    ) async {
      // Si no, posponer 9.9.9 callaba tambien a 9.9.10 y el aviso dejaba de
      // servir para lo unico que sirve.
      //
      // El `StateProvider` es lo que hace real el caso: la app sigue ABIERTA y
      // el backend publica una version posterior. Volver a llamar a `montar`
      // no servia -Riverpod reusa el override y el valor no cambiaba.
      final infoProvider = StateProvider<AppVersionInfo?>((ref) => hayNueva);

      await conPlataforma(TargetPlatform.android, () async {
        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appVersionGateProvider.overrideWith(
                (ref) async => ref.watch(infoProvider),
              ),
              updatePromptStoreProvider.overrideWithValue(
                UpdatePromptStore(prefs),
              ),
            ],
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: sozuLightTheme(),
                  builder: (context, child) =>
                      SozuAdaptiveTokens(child: child ?? const SizedBox()),
                  home: const VersionGate(
                    child: Scaffold(body: Text('contenido')),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(SButton, 'Ahora no'));
        await tester.pumpAndSettle();
        expect(find.text('Hay una versión nueva'), findsNothing);

        container.read(infoProvider.notifier).state = const AppVersionInfo(
          latestVersion: '9.9.10',
        );
        await tester.pumpAndSettle();

        expect(find.text('Hay una versión nueva'), findsOneWidget);
      });
    });

    testWidgets('usa el update_message del backend cuando viene', (
      tester,
    ) async {
      await conPlataforma(TargetPlatform.android, () async {
        await montar(
          tester,
          const AppVersionInfo(
            latestVersion: '9.9.9',
            updateMessage: 'Ya salio',
          ),
        );
        expect(find.text('Ya salio'), findsOneWidget);
      });
    });
  });

  group('forzado', () {
    testWidgets('sin URL de tienda el boton Actualizar existe igual', (
      tester,
    ) async {
      await conPlataforma(TargetPlatform.iOS, () async {
        await montar(tester, const AppVersionInfo(forceUpdate: true));

        expect(find.text('Actualización requerida'), findsOneWidget);
        final boton = find.widgetWithText(SButton, 'Actualizar');
        expect(boton, findsOneWidget);
        expect(tester.widget<SButton>(boton).onPressed, isNotNull);
        expect(find.text('contenido'), findsNothing);
      });
    });

    testWidgets('NO se puede posponer: no hay "Ahora no"', (tester) async {
      // Es lo que lo separa del aviso suave. Un forzado con salida no fuerza.
      await conPlataforma(TargetPlatform.iOS, () async {
        await montar(tester, const AppVersionInfo(forceUpdate: true));
        expect(find.text('Ahora no'), findsNothing);
      });
    });

    testWidgets('min_version mayor que la instalada tambien fuerza', (
      tester,
    ) async {
      await conPlataforma(TargetPlatform.android, () async {
        await montar(tester, const AppVersionInfo(minVersion: '9.9.9'));
        expect(find.text('Actualización requerida'), findsOneWidget);
      });
    });
  });

  group('no gatea', () {
    testWidgets('sin info (error o carga) deja pasar', (tester) async {
      await montar(tester, null);
      expect(find.text('contenido'), findsOneWidget);
    });

    testWidgets('al dia: ni aviso ni bloqueo', (tester) async {
      await conPlataforma(TargetPlatform.android, () async {
        await montar(
          tester,
          const AppVersionInfo(minVersion: '1.0.0', latestVersion: '1.0.0'),
        );
        expect(find.text('contenido'), findsOneWidget);
        expect(find.text('Hay una versión nueva'), findsNothing);
      });
    });
  });
}
