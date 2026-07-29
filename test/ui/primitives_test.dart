import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/admin/client_filters.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: sozuLightTheme(),
      builder: (context, c) => SozuAdaptiveTokens(child: c ?? const SizedBox()),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('SSearchField', () {
    testWidgets('el boton de limpiar aparece solo con texto', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      await pump(tester, SSearchField(controller: ctrl));
      expect(find.byIcon(Icons.clear), findsNothing);

      await tester.enterText(find.byType(TextField), 'ana');
      await tester.pump();
      // Sin setState de la pantalla: el propio campo escucha al controller.
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('limpiar vacia el controller y notifica', (tester) async {
      final ctrl = TextEditingController(text: 'ana');
      addTearDown(ctrl.dispose);
      final cambios = <String>[];

      await pump(
        tester,
        SSearchField(controller: ctrl, onChanged: cambios.add),
      );
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(ctrl.text, isEmpty);
      // Notificar es obligatorio: si no, la pantalla sigue filtrando por el
      // texto viejo y la lista queda desincronizada del campo.
      expect(cambios, contains(''));
      expect(find.byIcon(Icons.clear), findsNothing);
    });
  });

  group('SEmptyState', () {
    testWidgets('por defecto se ancla arriba, no al centro', (tester) async {
      await pump(
        tester,
        const SEmptyState(icon: Icons.search, title: 'Busca algo'),
      );

      final y = tester.getTopLeft(find.text('Busca algo')).dy;
      // Regresión que motivó el default: centrado en 800 px de alto el bloque
      // caia cerca de la mitad y la pantalla se leia como si no hubiera cargado.
      expect(y, lessThan(300));
    });

    testWidgets('centered:true si lo centra', (tester) async {
      await pump(
        tester,
        const SEmptyState(
          icon: Icons.search,
          title: 'Busca algo',
          centered: true,
        ),
      );
      expect(tester.getTopLeft(find.text('Busca algo')).dy, greaterThan(300));
    });

    testWidgets('el mensaje es opcional', (tester) async {
      await pump(
        tester,
        const SEmptyState(icon: Icons.search, title: 'Solo titulo'),
      );
      expect(find.text('Solo titulo'), findsOneWidget);
    });
  });

  group('SSectionLabel', () {
    testWidgets('pone el texto en mayusculas', (tester) async {
      await pump(tester, const SSectionLabel(text: 'Todos los clientes'));
      expect(find.text('TODOS LOS CLIENTES'), findsOneWidget);
    });

    testWidgets('usa el token overline, no un TextStyle suelto', (
      tester,
    ) async {
      await pump(tester, const SSectionLabel(text: 'grupo'));
      final texto = tester.widget<Text>(find.text('GRUPO'));
      expect(texto.style?.fontSize, SozuType.overline.fontSize);
      expect(texto.style?.fontWeight, SozuType.overline.fontWeight);
    });
  });

  group('ClientFilters', () {
    Widget build({required List<CatalogoItem> projects}) {
      final unit = TextEditingController();
      return ClientFilters(
        projects: projects,
        projectId: null,
        onProjectChanged: (_) {},
        unitController: unit,
        onUnitChanged: (_) {},
        onUnitCleared: () {},
      );
    }

    // Proyecto dejo de ser un DropdownButtonFormField: ahora es
    // SAutocompleteField (se busca escribiendo). Los dos campos son TextField,
    // asi que se distinguen por su labelText.
    Offset topLeftOfField(WidgetTester tester, String label) =>
        tester.getTopLeft(
          find
              .ancestor(of: find.text(label), matching: find.byType(TextField))
              .first,
        );

    testWidgets('en desktop van en fila', (tester) async {
      await pump(
        tester,
        build(projects: const []),
        size: const Size(1280, 800),
      );
      expect(
        topLeftOfField(tester, 'Proyecto').dy,
        topLeftOfField(tester, 'Unidad').dy,
      );
    });

    testWidgets('en movil se apilan', (tester) async {
      await pump(tester, build(projects: const []), size: const Size(360, 800));
      // A 360 px, en fila el campo de proyecto quedaba con ~200 px y truncaba
      // cualquier nombre.
      expect(
        topLeftOfField(tester, 'Unidad').dy,
        greaterThan(topLeftOfField(tester, 'Proyecto').dy),
      );
    });
  });
}
