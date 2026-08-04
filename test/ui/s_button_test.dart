import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/primitives/s_button.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';

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
      // Alineado arriba y con ancho acotado: centrado, un botón fullWidth ocupa
      // los 1280 px y las medidas de alto se vuelven ilegibles.
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            // Align interno: afloja el ancho a 0..320. Con el SizedBox pegado al
            // botón la restricción es TIGHT, y entonces `fullWidth: false` no
            // puede encogerse - la medición decía 320 siempre.
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    ),
  );
}

/// Decoración de la caja del botón. Es donde viven fondo y borde resueltos.
BoxDecoration decorationOf(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration
        as BoxDecoration;

Color? labelColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style?.color;

/// Deja el puntero de mouse encima del botón.
///
/// Hace falta un puntero real (`createGesture`) y no un evento sintético: el
/// `MouseTracker` solo reporta hover para punteros que dio de alta.
Future<void> hover(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(find.byType(SButton)));
  await tester.pumpAndSettle();
}

void main() {
  const light = SozuColorRoles.light;

  group('estado deshabilitado', () {
    testWidgets('onPressed null deshabilita el gesto', (tester) async {
      await pump(tester, const SButton(label: 'Entrar', onPressed: null));
      await tester.tap(find.byType(SButton));
      await tester.pump();

      // `null` no solo apaga el callback: el InkWell queda sin onTap, así que
      // tampoco toma foco ni pinta hover. Un botón muerto que igual reacciona al
      // puntero es peor que uno que no se ve deshabilitado.
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    });

    testWidgets('loading ignora el onPressed y muestra loadingLabel', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        SButton(
          label: 'Entrar',
          loading: true,
          loadingLabel: 'Entrando…',
          onPressed: () => taps++,
        ),
      );

      // El texto de carga sustituye al normal: si se vieran los dos, el botón
      // cambiaría de ancho a media petición.
      expect(find.text('Entrando…'), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(SButton));
      await tester.pump();
      // Regresión clásica: doble envío del formulario por tocar dos veces
      // mientras la primera petición está en vuelo.
      expect(taps, 0);
    });

    testWidgets('loading sin loadingLabel conserva el label', (tester) async {
      await pump(
        tester,
        SButton(label: 'Entrar', loading: true, onPressed: () {}),
      );
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('deshabilitado baja la opacidad', (tester) async {
      await pump(tester, const SButton(label: 'Entrar', onPressed: null));
      await tester.pumpAndSettle();
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(opacity.opacity, lessThan(1));
    });

    testWidgets('habilitado sí dispara', (tester) async {
      var taps = 0;
      await pump(tester, SButton(label: 'Entrar', onPressed: () => taps++));
      await tester.tap(find.byType(SButton));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('variantes: roles de color', () {
    testWidgets('primary usa primary / onPrimary', (tester) async {
      await pump(tester, SButton(label: 'Entrar', onPressed: () {}));
      expect(decorationOf(tester).color, light.primary);
      expect(labelColor(tester, 'Entrar'), light.onPrimary);
    });

    testWidgets('primary en hover pasa a primaryHover', (tester) async {
      await pump(tester, SButton(label: 'Entrar', onPressed: () {}));
      await hover(tester);
      // Rol y no un negro al 10% encima: en tema oscuro el hover tiene que
      // aclarar, y solo el rol sabe eso.
      expect(decorationOf(tester).color, light.primaryHover);
    });

    testWidgets('secondary es transparente con borde border y texto fg', (
      tester,
    ) async {
      await pump(
        tester,
        SButton.secondary(label: 'Cancelar', onPressed: () {}),
      );
      final d = decorationOf(tester);
      expect(d.color, Colors.transparent);
      expect(d.border?.top.color, light.border);
      expect(labelColor(tester, 'Cancelar'), light.fg);
    });

    testWidgets('secondary en hover tiñe borde y fondo de marca', (
      tester,
    ) async {
      await pump(
        tester,
        SButton.secondary(label: 'Cancelar', onPressed: () {}),
      );
      await hover(tester);
      final d = decorationOf(tester);
      // `primarySoftStrong` (10%) y no `primarySoft` (6%): al 6% el hover apenas
      // se distinguia del reposo. Mismo criterio que los badges y el overlay de
      // "Cerrar sesion".
      expect(d.color, light.primarySoftStrong);
      expect(d.border?.top.color, light.primary);
      expect(labelColor(tester, 'Cancelar'), light.primary);
    });

    testWidgets('ghost no tiene borde y en hover usa surfaceAlt', (
      tester,
    ) async {
      await pump(tester, SButton.ghost(label: 'Ver más', onPressed: () {}));
      expect(decorationOf(tester).border, isNull);
      expect(decorationOf(tester).color, Colors.transparent);
      await hover(tester);
      expect(decorationOf(tester).color, light.surfaceAlt);
    });

    testWidgets('danger usa danger / onPrimary', (tester) async {
      await pump(tester, SButton.danger(label: 'Eliminar', onPressed: () {}));
      expect(decorationOf(tester).color, light.danger);
      expect(labelColor(tester, 'Eliminar'), light.onPrimary);
    });

    testWidgets('link usa primaryHover, no primary', (tester) async {
      await pump(tester, SButton.link(label: 'Recuperar', onPressed: () {}));
      // primary sobre superficie clara no alcanza AA para texto chico.
      expect(labelColor(tester, 'Recuperar'), light.primaryHover);
    });

    testWidgets('color override reemplaza el fondo del primary', (
      tester,
    ) async {
      await pump(
        tester,
        SButton(label: 'Pagar', onPressed: () {}, color: light.positive),
      );
      expect(decorationOf(tester).color, light.positive);
    });
  });

  group('link no se lee como un tercer botón', () {
    testWidgets('no pinta fondo ni en reposo ni en hover', (tester) async {
      await pump(tester, SButton.link(label: 'Recuperar', onPressed: () {}));
      final reposo = decorationOf(tester);
      expect(reposo.color, Colors.transparent);
      expect(reposo.border, isNull);

      await hover(tester);
      final conHover = decorationOf(tester);
      expect(conHover.color, Colors.transparent);
      expect(conHover.border, isNull);
    });

    testWidgets('su feedback de hover es el subrayado', (tester) async {
      await pump(tester, SButton.link(label: 'Recuperar', onPressed: () {}));
      expect(
        tester.widget<Text>(find.text('Recuperar')).style?.decoration,
        isNot(TextDecoration.underline),
      );

      await hover(tester);
      expect(
        tester.widget<Text>(find.text('Recuperar')).style?.decoration,
        TextDecoration.underline,
      );
    });

    testWidgets('los botones con caja NO se subrayan en hover', (tester) async {
      await pump(
        tester,
        SButton.secondary(label: 'Cancelar', onPressed: () {}),
      );
      await hover(tester);
      expect(
        tester.widget<Text>(find.text('Cancelar')).style?.decoration,
        isNot(TextDecoration.underline),
      );
    });
  });

  group('alturas', () {
    Future<double> heightOf(WidgetTester tester, SButtonSize size) async {
      await pump(tester, SButton(label: 'X', onPressed: () {}, size: size));
      return tester.getSize(find.byType(SButton)).height;
    }

    testWidgets('md llega al mínimo táctil de 44', (tester) async {
      expect(await heightOf(tester, SButtonSize.md), greaterThanOrEqualTo(44));
    });

    testWidgets('lg llega al mínimo táctil de 44', (tester) async {
      expect(await heightOf(tester, SButtonSize.lg), greaterThanOrEqualTo(44));
    });

    testWidgets('lg es más alto que md y md más que sm', (tester) async {
      final sm = await heightOf(tester, SButtonSize.sm);
      final md = await heightOf(tester, SButtonSize.md);
      final lg = await heightOf(tester, SButtonSize.lg);
      expect(sm, lessThan(md));
      expect(md, lessThan(lg));
    });

    testWidgets('el enlace también es un destino táctil de 44', (tester) async {
      await pump(tester, SButton.link(label: 'Recuperar', onPressed: () {}));
      // Medía ~26 px cuando era solo texto: fallaba el mínimo de Apple/Material.
      expect(
        tester.getSize(find.byType(SButton)).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('teclado', () {
    testWidgets('Enter activa el botón enfocado', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var taps = 0;

      await pump(
        tester,
        SButton(label: 'Entrar', onPressed: () => taps++, focusNode: node),
      );

      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Esta es la razón de usar InkWell y no GestureDetector: con el gesture
      // detector el botón no era enfocable y el formulario solo se podía enviar
      // desde el último campo.
      expect(taps, 1);
    });

    testWidgets('deshabilitado no toma foco', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await pump(
        tester,
        SButton(label: 'Entrar', onPressed: null, focusNode: node),
      );
      node.requestFocus();
      await tester.pumpAndSettle();

      expect(node.hasFocus, isFalse);
    });

    testWidgets('el foco resalta igual que el hover', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await pump(
        tester,
        SButton.secondary(label: 'Cancelar', onPressed: () {}, focusNode: node),
      );
      expect(decorationOf(tester).border?.top.color, light.border);

      node.requestFocus();
      await tester.pumpAndSettle();

      // Quien navega con teclado ve el mismo lenguaje visual que quien usa
      // mouse; no hay un segundo idioma de estados.
      expect(decorationOf(tester).border?.top.color, light.primary);
    });
  });

  group('semántica', () {
    testWidgets('se anuncia como botón habilitado, una sola vez', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, SButton(label: 'Entrar', onPressed: () {}));

      final flags = tester.getSemantics(find.byType(SButton)).flagsCollection;
      expect(flags.isButton, isTrue);
      expect(flags.isEnabled, Tristate.isTrue);
      // La etiqueta va UNA vez: el nodo del botón y el del texto se fusionan, y
      // sin excluir la semántica del contenido el lector decía "Entrar Entrar".
      expect(tester.getSemantics(find.byType(SButton)).label, 'Entrar');
      handle.dispose();
    });

    testWidgets('deshabilitado se anuncia deshabilitado', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const SButton(label: 'Entrar', onPressed: null));

      final flags = tester.getSemantics(find.byType(SButton)).flagsCollection;
      // Deshabilitado sigue siendo un botón: si se anuncia como texto, quien usa
      // lector de pantalla no se entera de que hay una acción ahí bloqueada.
      expect(flags.isButton, isTrue);
      expect(flags.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('en carga anuncia el loadingLabel', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        SButton(
          label: 'Entrar',
          loading: true,
          loadingLabel: 'Entrando…',
          onPressed: () {},
        ),
      );
      expect(tester.getSemantics(find.byType(SButton)).label, 'Entrando…');
      handle.dispose();
    });
  });

  group('layout', () {
    testWidgets('fullWidth toma todo el ancho disponible', (tester) async {
      await pump(tester, SButton(label: 'Entrar', onPressed: () {}));
      expect(tester.getSize(find.byType(SButton)).width, 320);
    });

    testWidgets('fullWidth false se ajusta al contenido', (tester) async {
      await pump(
        tester,
        SButton(label: 'Entrar', onPressed: () {}, fullWidth: false),
      );
      expect(tester.getSize(find.byType(SButton)).width, lessThan(320));
    });

    testWidgets('los iconos van a los lados del texto', (tester) async {
      await pump(
        tester,
        SButton(
          label: 'Continuar',
          onPressed: () {},
          icon: Icons.lock_outline,
          trailingIcon: Icons.arrow_forward,
        ),
      );

      final izq = tester.getCenter(find.byIcon(Icons.lock_outline)).dx;
      final texto = tester.getCenter(find.text('Continuar')).dx;
      final der = tester.getCenter(find.byIcon(Icons.arrow_forward)).dx;
      expect(izq, lessThan(texto));
      expect(texto, lessThan(der));
    });

    testWidgets('en carga el icono izquierdo cede su lugar al spinner', (
      tester,
    ) async {
      await pump(
        tester,
        SButton(
          label: 'Entrar',
          onPressed: () {},
          icon: Icons.lock_outline,
          loading: true,
        ),
      );
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('semantica de navegacion', () {
    testWidgets('por defecto se anuncia como boton, no como enlace', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, SButton(label: 'Entrar', onPressed: () {}));

      expect(
        tester.getSemantics(find.text('Entrar')),
        matchesSemantics(
          label: 'Entrar',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('isNavigation lo anuncia como ENLACE', (tester) async {
      // Los lectores de pantalla listan los enlaces de la pantalla aparte y hay
      // usuarios que navegan solo por esa lista: un destino de navegacion
      // anunciado como boton desaparece de ahi.
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        SButton.link(
          label: 'Volver al inicio de sesion',
          isNavigation: true,
          onPressed: () {},
        ),
      );

      expect(
        tester.getSemantics(find.text('Volver al inicio de sesion')),
        matchesSemantics(
          label: 'Volver al inicio de sesion',
          isLink: true,
          isButton: false,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('la variante link NO implica navegacion', (tester) async {
      // "Cerrar sesion" se ve como enlace pero es una accion: variante y
      // semantica son ejes distintos.
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        SButton.link(label: 'Cerrar sesion', onPressed: () {}),
      );
      // matchesSemantics en vez de hasFlag: hasFlag esta deprecado desde
      // Flutter 3.32 en favor de flagsCollection.
      expect(
        tester.getSemantics(find.text('Cerrar sesion')),
        matchesSemantics(
          label: 'Cerrar sesion',
          isButton: true,
          isLink: false,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });
  });
}
