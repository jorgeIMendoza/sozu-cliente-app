import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_cliente_app/main.dart' show PortalLightLock;
import 'package:sozu_cliente_app/ui/ui.dart';

/// Brillo del tema que recibe el hijo del candado, al ancho dado.
Future<Brightness> _brilloBajoElCandado(
  WidgetTester tester, {
  required double ancho,
  required ThemeMode modo,
}) async {
  late Brightness visto;
  tester.view.physicalSize = Size(ancho, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: sozuLightTheme(),
      darkTheme: sozuDarkTheme(),
      themeMode: modo,
      home: PortalLightLock(
        child: Builder(
          builder: (context) {
            visto = Theme.of(context).brightness;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return visto;
}

void main() {
  group('PortalLightLock', () {
    testWidgets('en movil/angosto el modo oscuro SI llega', (tester) async {
      expect(
        await _brilloBajoElCandado(tester, ancho: 420, modo: ThemeMode.dark),
        Brightness.dark,
      );
    });

    testWidgets('en movil/angosto el modo claro llega claro', (tester) async {
      expect(
        await _brilloBajoElCandado(tester, ancho: 420, modo: ThemeMode.light),
        Brightness.light,
      );
    });

    testWidgets('ancho + oscuro: el candado depende de la plataforma', (
      tester,
    ) async {
      final brillo = await _brilloBajoElCandado(
        tester,
        ancho: 1440,
        modo: ThemeMode.dark,
      );
      // isPortalMode() exige kIsWeb. En la VM (flutter test) es false, asi que
      // un ancho grande NO es modo portal y el oscuro pasa. En navegador
      // (flutter test --platform chrome) si es portal y el candado lo fuerza a
      // claro. Se afirman los dos casos para que la prueba diga la verdad en
      // ambos objetivos en vez de pasar por accidente en uno.
      expect(brillo, kIsWeb ? Brightness.light : Brightness.dark);
    });
  });
}
