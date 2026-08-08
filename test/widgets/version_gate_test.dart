import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';
import 'package:sozu_cliente_app/widgets/version_gate.dart';

/// Monta el gate con la config que devolveria `cliente-app-version`.
Future<void> montar(WidgetTester tester, AppVersionInfo? info) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appVersionGateProvider.overrideWith((ref) async => info)],
      child: const MaterialApp(
        home: VersionGate(child: Scaffold(body: Text('contenido'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Corre el cuerpo simulando una plataforma. El reset va aqui y no en un
/// `tearDown` porque Flutter verifica que no queden overrides ANTES de
/// ejecutarlo, y el test falla aunque el aserto sea correcto.
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

void main() {
  // El gate no aplica en web; los tests corren en la VM, donde kIsWeb es false.

  group('aviso soft (hay version nueva)', () {
    // La version compilada es 1.0.0 (appVersionBase), asi que un latest mayor
    // dispara el aviso descartable.
    const hayNueva = AppVersionInfo(latestVersion: '9.9.9');

    testWidgets('en iOS sin ios_store_url el aviso SIGUE teniendo accion', (
      tester,
    ) async {
      // Este es el caso real: `ios_store_url` esta vacio en la BD. Antes el
      // boton se ocultaba y el aviso quedaba sin manera de actuar.
      await conPlataforma(TargetPlatform.iOS, () async {
        await montar(tester, hayNueva);

        expect(find.text('Hay una nueva versión disponible.'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Actualizar'), findsOneWidget);
      });
    });

    testWidgets('el mensaje completo es tocable, no solo el boton', (
      tester,
    ) async {
      await conPlataforma(TargetPlatform.android, () async {
        await montar(tester, hayNueva);

        final tocable = find.ancestor(
          of: find.text('Hay una nueva versión disponible.'),
          matching: find.byType(InkWell),
        );
        expect(tocable, findsWidgets);
        expect(tester.widget<InkWell>(tocable.first).onTap, isNotNull);
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

    testWidgets('"Ahora no" lo descarta y deja ver el contenido', (
      tester,
    ) async {
      await conPlataforma(TargetPlatform.android, () async {
        await montar(tester, hayNueva);

        await tester.tap(find.byTooltip('Ahora no'));
        await tester.pumpAndSettle();

        expect(find.text('Hay una nueva versión disponible.'), findsNothing);
        expect(find.text('contenido'), findsOneWidget);
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
        expect(find.widgetWithText(FilledButton, 'Actualizar'), findsOneWidget);
        // Bloqueante: el contenido de la app no se ve.
        expect(find.text('contenido'), findsNothing);
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
        expect(find.textContaining('nueva versión'), findsNothing);
      });
    });
  });
}
