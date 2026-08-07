import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/client/facturacion/providers/documents_providers.dart';
import 'package:sozu_cliente_app/features/client/facturacion/screens/facturas_screen.dart';
import 'package:sozu_cliente_app/features/client/profile/providers/profile_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import '../client_test_support.dart';
import '../profile/fake_profile_port.dart';
import 'fake_documents_port.dart';

/// La pantalla agrupa por unidad las DOS listas que manda el backend: la
/// factura de compra y las de mantenimiento. La clave es `id_cuenta` (la cuenta
/// PADRE en ambas): agrupar por el nombre de la propiedad partiría la unidad en
/// dos, porque cada lista lo escribe distinto.
void main() {
  /// Dos unidades. La 301 ya se entregó (tiene mantenimiento); la 302 no.
  final dosUnidades = <String, dynamic>{
    'documentos': [],
    'total': 0,
    'facturas': [
      {
        'id_cuenta': 301,
        'propiedad': 'Margot 814',
        'pdf': 'a.pdf',
        'xml': 'a.xml',
      },
      {
        'id_cuenta': 302,
        'propiedad': 'Margot 1020',
        'pdf': 'b.pdf',
        'xml': 'b.xml',
      },
    ],
    'facturas_mantenimiento': [
      {
        'id_pago': 1,
        'id_cuenta': 301,
        'propiedad': 'Margot 814',
        'monto': 652.5,
        'fecha': '2026-07-01',
        'pdf': 'm1.pdf',
        'xml': 'm1.xml',
      },
      {
        'id_pago': 2,
        'id_cuenta': 301,
        'propiedad': 'Margot 814',
        'monto': 1305.0,
        'fecha': '2026-07-06',
        'pdf': 'm2.pdf',
        'xml': 'm2.xml',
      },
    ],
  };

  Future<void> pumpPantalla(
    WidgetTester tester, {
    Map<String, dynamic>? datos,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 3000);
    addTearDown(tester.view.reset);

    final port = FakeDocumentsPort()..documentsJson = datos ?? dosUnidades;

    await tester.pumpWidget(
      ProviderScope(
        // El perfil tambien: la tarjeta de datos fiscales muestra su esqueleto
        // mientras carga, y un shimmer eterno cuelga a pumpAndSettle.
        overrides: clientWidgetOverrides(
          overrides: [
            documentsPortProvider.overrideWithValue(port),
            profilePortProvider.overrideWithValue(FakeProfilePort()),
          ],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: const FacturasScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista las unidades con su conteo de facturas', (tester) async {
    await pumpPantalla(tester);

    expect(find.text('Tus unidades (2)'), findsOneWidget);
    // 301: compra + 2 de mantenimiento. 302: solo compra.
    expect(find.text('3 facturas'), findsOneWidget);
    expect(find.text('1 factura'), findsOneWidget);
  });

  testWidgets('al abrir una unidad salen las dos secciones', (tester) async {
    await pumpPantalla(tester);
    await tester.tap(find.text('Margot 814'));
    await tester.pumpAndSettle();

    expect(find.text('Factura de la unidad'), findsOneWidget);
    expect(find.text('Facturas de mantenimiento (2)'), findsOneWidget);
    // Las dos de julio salen las DOS: son pagos distintos y ambos facturables.
    expect(find.textContaining('01/07/2026'), findsOneWidget);
    expect(find.textContaining('06/07/2026'), findsOneWidget);
  });

  testWidgets('una unidad sin entregar dice por qué no hay mantenimiento', (
    tester,
  ) async {
    await pumpPantalla(tester);
    await tester.tap(find.text('Margot 1020'));
    await tester.pumpAndSettle();

    expect(find.text('Sin facturas de mantenimiento.'), findsOneWidget);
  });

  testWidgets('con una sola unidad entra directo, sin lista de un elemento', (
    tester,
  ) async {
    await pumpPantalla(
      tester,
      datos: {
        'documentos': [],
        'total': 0,
        'facturas': [
          {'id_cuenta': 301, 'propiedad': 'Margot 814', 'pdf': 'a.pdf'},
        ],
      },
    );

    expect(find.text('Tus unidades (1)'), findsNothing);
    expect(find.text('Factura de la unidad'), findsOneWidget);
  });

  testWidgets('sin id_cuenta la de mantenimiento no se pierde', (tester) async {
    // Es el estado ANTES de que el backend mande `id_cuenta`: la factura no se
    // puede atribuir, pero esconderla sería esconder un comprobante fiscal.
    await pumpPantalla(
      tester,
      datos: {
        'documentos': [],
        'total': 0,
        'facturas': [
          {'id_cuenta': 301, 'propiedad': 'Margot 814', 'pdf': 'a.pdf'},
        ],
        'facturas_mantenimiento': [
          {'id_pago': 1, 'fecha': '2026-07-01', 'pdf': 'm1.pdf'},
        ],
      },
    );

    expect(find.text('Sin unidad asignada'), findsOneWidget);
    expect(find.text('Tus unidades (2)'), findsOneWidget);
  });

  testWidgets('los datos de facturación van arriba', (tester) async {
    await pumpPantalla(tester);
    expect(find.text('Tus datos de facturación'), findsOneWidget);
  });

  testWidgets('el archivo que no llegó no es pulsable', (tester) async {
    await pumpPantalla(
      tester,
      datos: {
        'documentos': [],
        'total': 0,
        // Solo PDF: el XML no viene.
        'facturas': [
          {'id_cuenta': 301, 'propiedad': 'Margot 814', 'pdf': 'a.pdf'},
        ],
      },
    );

    // Las dos etiquetas se pintan: que falte uno se VE, no se esconde.
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('XML'), findsOneWidget);

    final pulsables = tester
        .widgetList<SPressable>(find.byType(SPressable))
        .where((p) => p.onTap != null)
        .length;
    final apagados = tester
        .widgetList<SPressable>(find.byType(SPressable))
        .where((p) => p.onTap == null)
        .length;
    expect(pulsables, greaterThan(0), reason: 'el PDF sí abre');
    expect(apagados, greaterThan(0), reason: 'el XML ausente queda apagado');
  });
}
