import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
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
    // dispara el aviso.
    const hayNueva = AppVersionInfo(latestVersion: '9.9.9');

    testWidgets('en iOS sin ios_store_url el aviso SIGUE teniendo accion', (
      tester,
    ) async {
      // Este es el caso real: `ios_store_url` esta vacio en la BD. Antes el
      // boton se ocultaba y el aviso quedaba sin manera de actuar.
      await conPlataforma(TargetPlatform.iOS, () async {
        await montar(tester, hayNueva);

        // `textContaining` y no `text`: mensaje y accion viven en UN solo
        // `Text.rich`, asi que el texto plano del widget es la frase completa.
        expect(
          find.textContaining('Nueva versión disponible.'),
          findsOneWidget,
        );
        expect(find.textContaining('Actualizar'), findsOneWidget);
      });
    });

    testWidgets('toda la franja es UN solo blanco de toque', (tester) async {
      // Con varios blancos hay que atinarle a uno; por eso no hay botones
      // anidados y el InkWell envuelve mensaje y llamada a la accion.
      await conPlataforma(TargetPlatform.android, () async {
        await montar(tester, hayNueva);

        final tocable = find.ancestor(
          of: find.textContaining('Actualizar'),
          matching: find.byType(InkWell),
        );
        expect(tocable, findsOneWidget, reason: 'sin InkWell sobre la franja');
        expect(tester.widget<InkWell>(tocable.first).onTap, isNotNull);

        // Un solo InkWell para toda la franja: si hubiera dos, serian dos
        // blancos distintos y volveria el problema de tener que atinarle.
        expect(find.byType(InkWell), findsOneWidget);

        // Y "Actualizar" es un TextSpan del mismo Text que el mensaje, no un
        // widget aparte: si alguien lo vuelve a sacar a su propio Text es que
        // le puso caja o gesto, que es justo lo que no debe tener.
        expect(find.text('Actualizar'), findsNothing);
      });
    });

    testWidgets('no se puede descartar: sin boton de cerrar', (tester) async {
      await conPlataforma(TargetPlatform.android, () async {
        await montar(tester, hayNueva);

        expect(find.byTooltip('Ahora no'), findsNothing);
        expect(find.byIcon(Icons.close_rounded), findsNothing);
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

        expect(find.textContaining('Ya salio'), findsOneWidget);
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
        // Lo que importa no es qué widget lo pinta, sino que el botón esté y
        // sea accionable: un forzado sin salida deja al usuario encerrado.
        final boton = find.widgetWithText(SButton, 'Actualizar');
        expect(boton, findsOneWidget);
        expect(tester.widget<SButton>(boton).onPressed, isNotNull);
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
        // Con la mayuscula del mensaje real: `textContaining` distingue
        // mayusculas, asi que en minuscula este aserto pasaba aunque la franja
        // estuviera ahi y no guardaba nada.
        expect(find.textContaining('Nueva versión'), findsNothing);
      });
    });
  });
}
