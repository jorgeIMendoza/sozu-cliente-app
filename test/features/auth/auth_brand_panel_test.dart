import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/app_download/components/app_download.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_brand_image.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// El QR de descarga vive en el panel de marca y no en cada pantalla: lo
/// pintaba solo el login con una clase privada, y recuperar contraseña se
/// quedaba sin él. Ahora lo hereda cualquier pantalla de acceso.
void main() {
  Future<void> pumpPanel(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        builder: (context, child) =>
            SozuAdaptiveTokens(child: child ?? const SizedBox()),
        home: const Scaffold(body: AuthBrandImage()),
      ),
    );
    await tester.pump();
  }

  testWidgets('en app nativa no hay QR: no se escanea la propia pantalla', (
    tester,
  ) async {
    // En la VM `kIsWeb` es false, o sea "app nativa", ancho de escritorio.
    await pumpPanel(tester, const Size(1400, 900));

    expect(find.byType(AppQrCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en pantalla angosta tampoco', (tester) async {
    await pumpPanel(tester, const Size(390, 800));

    expect(find.byType(AppQrCard), findsNothing);
  });
}
