import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/app_download/components/app_download.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// La franja de descarga del login resuelve la tienda EN LA APP. Lo que fija
/// este archivo: en un sistema sin tienda publicada no promete un toque que no
/// lleva a ningún lado, y en el que sí la tiene no compite con "Iniciar
/// sesión" (no es un botón primario).
void main() {
  Future<void> pumpBanner(
    WidgetTester tester,
    TargetPlatform plataforma, {
    String? androidStoreUrl,
    String? iosStoreUrl,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    // El override se limpia al FINAL del cuerpo de cada test, no en un
    // addTearDown: el binding valida las variables de debug antes de correrlos.
    debugDefaultTargetPlatformOverride = plataforma;

    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        builder: (context, child) =>
            SozuAdaptiveTokens(child: child ?? const SizedBox()),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppStoreDownloadButton(
              androidStoreUrl: androidStoreUrl,
              iosStoreUrl: iosStoreUrl,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('sin config: Android cae en la constante, iOS queda sin destino', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(appDownloadTarget(), contains('play.google.com'));
    // El referrer viaja con el respaldo: sin él, la instalación desde el login
    // no se atribuye igual que la del QR.
    expect(appDownloadTarget(), contains('utm_source'));

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(appDownloadTarget(), isNull);
    // Cadena vacía == "aún no publicada", que es lo que hoy guarda la BD en
    // `ios_store_url`. No debe leerse como una URL válida.
    expect(appDownloadTarget(iosStoreUrl: '  '), isNull);

    // Cualquier otro sistema cae en el redirector, que sigue siendo el comodín.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(appDownloadTarget(), contains('obtener-clientes-app'));

    debugDefaultTargetPlatformOverride = null;
  });

  test('con config del backend manda esa URL, no la constante', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      appDownloadTarget(androidStoreUrl: 'https://play.google.com/otra'),
      'https://play.google.com/otra',
    );

    // Lo que hace dinámico el lanzamiento de iOS: llenar la fila de la BD basta.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      appDownloadTarget(iosStoreUrl: 'https://apps.apple.com/mx/app/id1'),
      'https://apps.apple.com/mx/app/id1',
    );

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('en Android invita a descargar y es pulsable', (tester) async {
    await pumpBanner(tester, TargetPlatform.android);

    expect(find.text('Descarga la app'), findsOneWidget);
    expect(find.byType(SPressable), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('en iOS avisa que no está y NO es pulsable', (tester) async {
    await pumpBanner(tester, TargetPlatform.iOS);

    expect(find.text('App para iPhone'), findsOneWidget);
    expect(find.text('Muy pronto en el App Store'), findsOneWidget);
    expect(
      find.byType(SPressable),
      findsNothing,
      reason: 'sin tienda no hay a dónde ir: la franja informa, no navega',
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('nunca es un botón primario: no le quita jerarquía al login', (
    tester,
  ) async {
    await pumpBanner(tester, TargetPlatform.android);

    expect(
      find.byType(SButton),
      findsNothing,
      reason:
          'dos botones llenos del mismo verde se leen como dos caminos igual '
          'de válidos y el cliente con cuenta duda cuál tocar',
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('con la URL de iOS en la config, la franja invita a descargar', (
    tester,
  ) async {
    await pumpBanner(
      tester,
      TargetPlatform.iOS,
      iosStoreUrl: 'https://apps.apple.com/mx/app/id1',
    );

    expect(find.text('Descarga la app'), findsOneWidget);
    expect(find.text('App para iPhone'), findsNothing);
    expect(find.byType(SPressable), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
