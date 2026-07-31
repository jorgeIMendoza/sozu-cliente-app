import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/features/admin/components/client_filters.dart';

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

    // La variante heading reemplaza al `SectionTitle` legacy (20 sitios de uso):
    // es un TÍTULO, no una etiqueta, y confundirlas cambiaría esos 20 sitios de
    // 16 px en caja normal a 11 px en mayúsculas.
    testWidgets('la variante heading NO pone el texto en mayusculas', (
      tester,
    ) async {
      await pump(tester, const SSectionLabel.heading(text: 'Mis pagos'));
      expect(find.text('Mis pagos'), findsOneWidget);
      expect(find.text('MIS PAGOS'), findsNothing);
    });

    testWidgets('heading usa bodyLarge w700 y label sigue en overline', (
      tester,
    ) async {
      await pump(tester, const SSectionLabel.heading(text: 'Mis pagos'));
      final titulo = tester.widget<Text>(find.text('Mis pagos'));
      expect(titulo.style?.fontSize, SozuType.bodyLarge.fontSize);
      expect(titulo.style?.fontWeight, FontWeight.w700);

      await pump(tester, const SSectionLabel(text: 'Mis pagos'));
      final etiqueta = tester.widget<Text>(find.text('MIS PAGOS'));
      expect(etiqueta.style?.fontSize, SozuType.overline.fontSize);
      expect(etiqueta.style?.fontSize, lessThan(titulo.style!.fontSize!));
    });

    testWidgets('el icono de heading usa el rol primary, no un verde cocido', (
      tester,
    ) async {
      await pump(
        tester,
        const SSectionLabel.heading(text: 'Mis pagos', icon: Icons.payments),
      );

      final icono = tester.widget<Icon>(find.byIcon(Icons.payments));
      expect(icono.color, SozuColorRoles.light.primary);
      expect(icono.size, 16);
    });

    testWidgets('heading respeta el trailing y su aire propio', (tester) async {
      await pump(
        tester,
        const SSectionLabel.heading(
          text: 'Mis pagos',
          trailing: Text('ver todo'),
        ),
      );

      expect(find.text('ver todo'), findsOneWidget);
      // 24 arriba (space.lg) contra los 4 de la etiqueta: el título abre bloque.
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.text('Mis pagos'),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.only(top: 24, bottom: 8));
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

    // Los dos campos son STextField y se distinguen por su etiqueta. Se busca el
    // STextField y NO el TextField interno: la etiqueta dejo de ser flotante, asi
    // que es un `Text` hermano del campo dentro de la Column del STextField, no
    // un descendiente del TextField.
    Offset topLeftOfField(WidgetTester tester, String label) =>
        tester.getTopLeft(
          find
              .ancestor(of: find.text(label), matching: find.byType(STextField))
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
