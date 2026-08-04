import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/primitives/s_choice_chip.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';

/// Contrato de la pastilla seleccionable.
///
/// Lo que se fija aquí es lo que un refactor rompe en silencio: que seleccionada
/// y sin seleccionar NO se pinten igual (el bug que motivó la primitiva era un
/// `FilterChip` verde sobre verde), que el callback reciba el valor invertido,
/// que deshabilitada no dispare, y que el área tocable llegue a 44 px aunque la
/// pastilla se vea más baja.
void main() {
  const light = SozuColorRoles.light;
  const dark = SozuColorRoles.dark;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark
            ? sozuDarkTheme()
            : sozuLightTheme(),
        builder: (context, c) =>
            SozuAdaptiveTokens(child: c ?? const SizedBox()),
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
    // Hasta el final: `AnimatedContainer` interpola color, borde y constraints,
    // y en el segundo `pumpWidget` de un test el estado se reusa, así que un
    // solo frame devuelve los valores del pump anterior.
    await tester.pumpAndSettle();
  }

  /// La pastilla. `.last` porque el `AnimatedContainer` de SPressable (el que
  /// pinta su fondo de hover) la envuelve y aparece primero.
  ///
  /// Es una función y no una constante: un `Finder` cachea lo que encontró, así
  /// que reusarlo entre dos `pumpWidget` devuelve el widget del primero.
  Finder pastilla() => find
      .descendant(
        of: find.byType(SChoiceChip),
        matching: find.byType(AnimatedContainer),
      )
      .last;

  /// Decoración de la pastilla: fondo y borde ya resueltos.
  BoxDecoration decorationOf(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(pastilla()).decoration as BoxDecoration;

  Color? labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  /// Deja el puntero encima de la pastilla. Hace falta un puntero real: el
  /// `MouseTracker` solo reporta hover para punteros que dio de alta.
  Future<void> hover(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(SChoiceChip)));
    await tester.pumpAndSettle();
  }

  Widget chip({
    bool selected = false,
    ValueChanged<bool>? onSelected,
    bool enabled = true,
    IconData? icon,
    SChoiceChipSize size = SChoiceChipSize.md,
    String label = 'Pagados',
  }) => SChoiceChip(
    label: label,
    selected: selected,
    onSelected: onSelected ?? (_) {},
    enabled: enabled,
    icon: icon,
    size: size,
  );

  group('seleccionado vs sin seleccionar', () {
    testWidgets('difieren en fondo, texto Y borde en tema claro', (
      tester,
    ) async {
      await pump(tester, chip(selected: false));
      final apagado = decorationOf(tester);
      final textoApagado = labelColor(tester, 'Pagados');

      await pump(tester, chip(selected: true));
      final prendido = decorationOf(tester);
      final textoPrendido = labelColor(tester, 'Pagados');

      // Los tres a la vez: con solo uno, un refactor puede colapsar los otros
      // dos y dejar el chip casi indistinguible.
      expect(prendido.color, isNot(apagado.color));
      expect(textoPrendido, isNot(textoApagado));
      expect(prendido.border, isNot(apagado.border));
    });

    testWidgets('difieren en fondo Y texto en tema oscuro', (tester) async {
      await pump(tester, chip(selected: false), brightness: Brightness.dark);
      final apagado = decorationOf(tester).color;
      final textoApagado = labelColor(tester, 'Pagados');

      await pump(tester, chip(selected: true), brightness: Brightness.dark);
      expect(decorationOf(tester).color, isNot(apagado));
      expect(labelColor(tester, 'Pagados'), isNot(textoApagado));
    });

    testWidgets('seleccionado usa el par de marca de SBadge.positive', (
      tester,
    ) async {
      await pump(tester, chip(selected: true));
      // El bug original: el chip tomaba `secondaryContainer` del ColorScheme
      // (verde sólido) con el label en gris. Aquí el fondo es el tinte y el
      // texto el verde oscuro, que es el par que ya usa la insignia.
      expect(decorationOf(tester).color, light.primarySoftStrong);
      expect(labelColor(tester, 'Pagados'), light.primaryHover);
      expect(decorationOf(tester).border?.top.color, light.primaryBorder);
    });

    testWidgets('en oscuro son los roles del set oscuro, no los del claro', (
      tester,
    ) async {
      await pump(tester, chip(selected: true), brightness: Brightness.dark);
      expect(decorationOf(tester).color, dark.primarySoftStrong);
      expect(labelColor(tester, 'Pagados'), dark.primaryHover);
      // Si el widget resolviera contra el set claro esto pasaría igual y el
      // chip se vería lavado sobre superficie oscura.
      expect(dark.primarySoftStrong, isNot(light.primarySoftStrong));
      expect(dark.primaryHover, isNot(light.primaryHover));
    });

    testWidgets('sin seleccionar no se tiñe de marca', (tester) async {
      await pump(tester, chip(selected: false));
      expect(decorationOf(tester).color, light.surface);
      expect(labelColor(tester, 'Pagados'), light.fgMuted);
      expect(decorationOf(tester).border?.top.color, light.border);
    });

    testWidgets('el fondo es OPACO en los dos estados', (tester) async {
      // Un tinte translúcido se ve bien sobre blanco y se ensucia sobre
      // `surfaceAlt`.
      for (final sel in [false, true]) {
        await pump(tester, chip(selected: sel));
        expect(decorationOf(tester).color!.a, 1.0);
      }
    });
  });

  group('callback', () {
    testWidgets('sin seleccionar, al pulsar manda true', (tester) async {
      final valores = <bool>[];
      await pump(tester, chip(selected: false, onSelected: valores.add));
      await tester.tap(find.byType(SChoiceChip));
      await tester.pump();
      expect(valores, [true]);
    });

    testWidgets('seleccionado, al pulsar manda false', (tester) async {
      final valores = <bool>[];
      await pump(tester, chip(selected: true, onSelected: valores.add));
      await tester.tap(find.byType(SChoiceChip));
      await tester.pump();
      // El valor va INVERTIDO: mandar siempre `true` deja al filtro sin apagar.
      expect(valores, [false]);
    });

    testWidgets('el chip no guarda estado: sigue el valor que le pasan', (
      tester,
    ) async {
      await pump(tester, chip(selected: false, onSelected: (_) {}));
      await tester.tap(find.byType(SChoiceChip));
      await tester.pumpAndSettle();
      // Quien manda es el padre. Si el chip se pintara seleccionado solo, la
      // pantalla y el chip se desincronizan cuando el filtro se limpia desde
      // otro botón.
      expect(decorationOf(tester).color, light.surface);
    });
  });

  group('deshabilitado', () {
    testWidgets('no dispara onSelected', (tester) async {
      final valores = <bool>[];
      await pump(tester, chip(enabled: false, onSelected: valores.add));
      await tester.tap(find.byType(SChoiceChip));
      await tester.pump();
      expect(valores, isEmpty);
      // El gesto queda apagado de raíz, no solo el callback: un chip muerto que
      // igual pinta hover es peor que uno que no se ve deshabilitado.
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    });

    testWidgets('no toma foco de teclado', (tester) async {
      await pump(tester, chip(enabled: false));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(decorationOf(tester).border?.top.color, light.borderSoft);
    });

    testWidgets('pierde el verde pero conserva cuál estaba elegida', (
      tester,
    ) async {
      await pump(tester, chip(enabled: false, selected: false));
      final apagado = decorationOf(tester).color;

      await pump(tester, chip(enabled: false, selected: true));
      expect(labelColor(tester, 'Pagados'), light.fgSubtle);
      expect(decorationOf(tester).color, isNot(apagado));
      expect(decorationOf(tester).color, isNot(light.primarySoftStrong));
    });
  });

  group('hover y foco', () {
    testWidgets('el hover tiñe el borde de marca y sube el texto a fg', (
      tester,
    ) async {
      await pump(tester, chip(selected: false));
      expect(labelColor(tester, 'Pagados'), light.fgMuted);

      await hover(tester);
      expect(decorationOf(tester).border?.top.color, light.primaryBorder);
      expect(labelColor(tester, 'Pagados'), light.fg);
      expect(decorationOf(tester).color, light.surfaceAlt);
    });

    testWidgets('el foco de teclado resalta igual que el hover', (
      tester,
    ) async {
      await pump(tester, chip(selected: false));
      expect(decorationOf(tester).border?.top.color, light.border);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Quien navega con teclado ve el mismo lenguaje visual que quien usa
      // mouse; no hay un segundo idioma de estados.
      expect(decorationOf(tester).border?.top.color, light.primaryBorder);
      expect(labelColor(tester, 'Pagados'), light.fg);
    });

    testWidgets('Enter activa la pastilla enfocada', (tester) async {
      final valores = <bool>[];
      await pump(tester, chip(selected: false, onSelected: valores.add));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(valores, [true]);
    });

    testWidgets('el hover de la seleccionada sube el borde a primary', (
      tester,
    ) async {
      await pump(tester, chip(selected: true));
      expect(decorationOf(tester).border?.top.color, light.primaryBorder);
      await hover(tester);
      expect(decorationOf(tester).border?.top.color, light.primary);
    });
  });

  group('área tocable', () {
    testWidgets('mide 44 px en los dos ejes aunque la pastilla sea más baja', (
      tester,
    ) async {
      await pump(tester, chip(size: SChoiceChipSize.sm, label: 'Sí'));

      final tocable = tester.getSize(find.byType(SChoiceChip));
      expect(tocable.height, greaterThanOrEqualTo(44));
      expect(tocable.width, greaterThanOrEqualTo(44));

      // Y la pastilla sigue viéndose baja: si el piso táctil se hubiera
      // implementado engordando la pastilla, esto valdría 44.
      expect(tester.getSize(pastilla()).height, lessThan(44));
    });

    testWidgets('un toque ARRIBA de la pastilla, dentro de los 44 px, cuenta', (
      tester,
    ) async {
      final valores = <bool>[];
      await pump(
        tester,
        chip(size: SChoiceChipSize.sm, label: 'Sí', onSelected: valores.add),
      );

      final caja = tester.getRect(find.byType(SChoiceChip));
      final visible = tester.getRect(pastilla());
      // Punto en el aire de arriba: fuera de la pastilla, dentro del área.
      final punto = Offset(caja.center.dx, (caja.top + visible.top) / 2);
      expect(punto.dy, lessThan(visible.top));

      await tester.tapAt(punto);
      await tester.pump();
      expect(valores, [true]);
    });
  });

  group('forma y tamaños', () {
    testWidgets('es una pill: radio full', (tester) async {
      await pump(tester, chip());
      expect(
        decorationOf(tester).borderRadius,
        SozuTheme.light.radius.fullBorder,
      );
    });

    testWidgets('sm es más baja y más angosta que md', (tester) async {
      await pump(
        tester,
        chip(size: SChoiceChipSize.sm, label: 'Mantenimiento'),
      );
      final sm = tester.getSize(pastilla());

      await pump(
        tester,
        chip(size: SChoiceChipSize.md, label: 'Mantenimiento'),
      );
      final md = tester.getSize(pastilla());

      expect(sm.height, lessThan(md.height));
      expect(sm.width, lessThan(md.width));
    });

    testWidgets('el tamaño por defecto es md', (tester) async {
      expect(
        SChoiceChip(label: 'X', selected: false, onSelected: (_) {}).size,
        SChoiceChipSize.md,
      );
    });

    testWidgets('se ajusta al contenido, no al ancho disponible', (
      tester,
    ) async {
      await pump(tester, chip(label: 'Todos'));
      expect(tester.getSize(find.byType(SChoiceChip)).width, lessThan(200));
    });
  });

  group('icono', () {
    testWidgets('sin icono no monta ninguno', (tester) async {
      await pump(tester, chip());
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('va a la izquierda del texto y en su mismo color', (
      tester,
    ) async {
      await pump(tester, chip(selected: true, icon: Icons.mail_outline));
      expect(
        tester.getCenter(find.byIcon(Icons.mail_outline)).dx,
        lessThan(tester.getCenter(find.text('Pagados')).dx),
      );
      // Un icono de otro color rompe la lectura del chip como una sola pieza.
      expect(
        tester.widget<Icon>(find.byType(Icon)).color,
        labelColor(tester, 'Pagados'),
      );
    });
  });

  group('semántica', () {
    testWidgets('se anuncia como botón seleccionado, una sola vez', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, chip(selected: true));

      // `getSemanticsData()` y no el nodo pelón: el nodo de arriba fusiona a los
      // descendientes, así que su `label` propio va vacío.
      final data = tester
          .getSemantics(find.byType(SChoiceChip))
          .getSemanticsData();
      expect(data.label, 'Pagados');
      // Sin la bandera, un lector de pantalla lee los cinco filtros igual y no
      // hay forma de saber cuál está aplicado.
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      expect(data.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('sin seleccionar no lleva la bandera', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, chip(selected: false));
      expect(
        tester
            .getSemantics(find.byType(SChoiceChip))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      handle.dispose();
    });
  });

  // El bug que motivó la primitiva era de TEMA, no del sitio de uso: un
  // `FilterChip` pelón se rellenaba con `secondaryContainer` (el verde de marca)
  // y dejaba el label en el gris fijo de `chipTheme.labelStyle` - 1.01:1 en
  // claro y 1.34:1 en oscuro. Se fija aquí para que el próximo chip de Material
  // que alguien suelte no repita el verde sobre verde.
  group('chipTheme de Material', () {
    /// Relleno del chip: un `Ink` con `ShapeDecoration`, no el `Material`.
    Color fillOf(WidgetTester tester) =>
        (tester
                    .widget<Ink>(
                      find.descendant(
                        of: find.byType(FilterChip),
                        matching: find.byType(Ink),
                      ),
                    )
                    .decoration
                as ShapeDecoration)
            .color!;

    /// El label de un chip de Material no trae `style`: el color lo pone el
    /// `DefaultTextStyle` de dentro, así que hay que leer el párrafo ya pintado.
    Color? chipLabelColor(WidgetTester tester) => tester
        .renderObject<RenderParagraph>(find.text('Correo'))
        .text
        .style
        ?.color;

    Future<void> pumpChip(
      WidgetTester tester, {
      required bool selected,
      Brightness brightness = Brightness.light,
    }) => pump(
      tester,
      FilterChip(
        selected: selected,
        label: const Text('Correo'),
        onSelected: (_) {},
      ),
      brightness: brightness,
    );

    for (final (nombre, brillo, roles) in [
      ('claro', Brightness.light, light),
      ('oscuro', Brightness.dark, dark),
    ]) {
      testWidgets('en tema $nombre el label cambia al seleccionar', (
        tester,
      ) async {
        await pumpChip(tester, selected: false, brightness: brillo);
        expect(chipLabelColor(tester), roles.fgMuted);
        expect(fillOf(tester), roles.surface);

        await pumpChip(tester, selected: true, brightness: brillo);
        // Con `labelStyle.color` plano esto seguiría en `fgMuted` sobre verde.
        expect(chipLabelColor(tester), roles.primaryHover);
        expect(fillOf(tester), roles.primarySoftStrong);
      });
    }

    testWidgets('los mismos roles que SChoiceChip', (tester) async {
      await pumpChip(tester, selected: true);
      final material = fillOf(tester);
      final materialLabel = chipLabelColor(tester);

      await pump(tester, chip(selected: true));
      expect(decorationOf(tester).color, material);
      expect(labelColor(tester, 'Pagados'), materialLabel);
    });
  });
}
