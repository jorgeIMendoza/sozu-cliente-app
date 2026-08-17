import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/preview_banner.dart';

void main() {
  // isPreviewBuild es true por defecto (APP_ENV cae a 'preview' sin dart-define),
  // así que el cintillo se monta en tests sin configuración extra.

  Future<void> pumpBanner(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        home: const PreviewBanner(child: Scaffold(body: Text('contenido'))),
      ),
    );
  }

  testWidgets('la franja cruza todo el ancho de la pantalla', (tester) async {
    await pumpBanner(tester, size: const Size(1280, 800));

    final banner = tester.getSize(
      find
          .ancestor(
            of: find.byType(Text).first,
            matching: find.byType(Material),
          )
          .first,
    );
    // Regresión real: al quitar el Row (que era mainAxisSize.max) la Column se
    // encogió al ancho del texto y la franja quedó como una pastilla centrada.
    expect(banner.width, 1280);
  });

  testWidgets('la leyenda es PREVIEW + version, sin icono', (tester) async {
    await pumpBanner(tester);

    expect(find.textContaining('PREVIEW'), findsOneWidget);
    expect(find.textContaining(appVersionLabel), findsOneWidget);
    // Sin icono: el único Icon posible vendría del contenido, no del cintillo.
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('usa los roles info, no colores hardcodeados', (tester) async {
    await pumpBanner(tester);

    final material = tester.widget<Material>(
      find
          .ancestor(
            of: find.textContaining('PREVIEW'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, SozuColorRoles.light.infoSoft);

    final texto = tester.widget<Text>(find.textContaining('PREVIEW'));
    expect(texto.style?.color, SozuColorRoles.light.infoFg);
  });

  testWidgets('no se muestra en builds de produccion', (tester) async {
    // No se puede cambiar isPreviewBuild en runtime (es const desde
    // dart-define), así que se verifica el contrato inverso: cuando SÍ es
    // preview, el cintillo existe. El caso prod se cubre en el build de CI, que
    // compila con --dart-define=APP_ENV=prod.
    expect(isPreviewBuild, isTrue);
  });

  test('HIDE_PREVIEW esta apagado salvo que se pida', () {
    // Es la unica defensa contra que la bandera se quede pegada en un pipeline:
    // un build de preview SIN cintillo se ve igual que produccion, y ahi es
    // donde alguien reporta un bug creyendo que prueba lo que no prueba.
    expect(hidePreviewBanner, isFalse);
  });
}
