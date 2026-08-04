import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/primitives/s_avatar.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';

/// Contrato del avatar de iniciales.
///
/// Lo que se fija aquí: que `size` sea de verdad el diámetro (los sitios de uso
/// lo alinean con textos y con el header, así que 44 tiene que medir 44), que la
/// letra escale con el diámetro y que el color venga de los roles de marca.
void main() {
  const light = SozuColorRoles.light;

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
  }

  double fontSizeOf(WidgetTester tester, String initials) =>
      tester.widget<Text>(find.text(initials)).style!.fontSize!;

  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<Container>(
                find.descendant(
                  of: find.byType(SAvatar),
                  matching: find.byType(Container),
                ),
              )
              .decoration
          as BoxDecoration;

  testWidgets('el tamaño por defecto es 44 y es cuadrado', (tester) async {
    await pump(tester, const SAvatar(initials: 'EA'));
    // 44 = mínimo táctil; es también el alto con el que están alineados los
    // headers que lo usan.
    expect(tester.getSize(find.byType(SAvatar)), const Size(44, 44));
  });

  testWidgets('size es el diámetro exacto', (tester) async {
    await pump(tester, const SAvatar(initials: 'EA', size: 52));
    expect(tester.getSize(find.byType(SAvatar)), const Size(52, 52));

    await pump(tester, const SAvatar(initials: 'EA', size: 24));
    expect(tester.getSize(find.byType(SAvatar)), const Size(24, 24));
  });

  testWidgets('la letra escala en proporción al diámetro', (tester) async {
    await pump(tester, const SAvatar(initials: 'EA', size: 32));
    final chico = fontSizeOf(tester, 'EA');

    await pump(tester, const SAvatar(initials: 'EA', size: 64));
    final grande = fontSizeOf(tester, 'EA');

    // Proporción y no un tamaño fijo: con fontSize constante, un avatar de 24
    // queda con la letra desbordada y uno de 64 con la letra perdida al centro.
    expect(grande, greaterThan(chico));
    expect(grande / 64, closeTo(chico / 32, 0.001));
    // Y la letra tiene que caber en el círculo.
    expect(grande, lessThan(64));
  });

  testWidgets('es un círculo con el color de marca y texto onPrimary', (
    tester,
  ) async {
    await pump(tester, const SAvatar(initials: 'EA'));
    final d = decorationOf(tester);

    expect(d.shape, BoxShape.circle);
    expect(d.color, light.primary);
    expect(tester.widget<Text>(find.text('EA')).style?.color, light.onPrimary);
  });

  testWidgets('en tema oscuro sigue saliendo de los roles', (tester) async {
    await pump(
      tester,
      const SAvatar(initials: 'EA'),
      brightness: Brightness.dark,
    );
    expect(decorationOf(tester).color, SozuColorRoles.dark.primary);
    expect(
      tester.widget<Text>(find.text('EA')).style?.color,
      SozuColorRoles.dark.onPrimary,
    );
  });

  testWidgets('pinta las iniciales que recibe, sin transformarlas', (
    tester,
  ) async {
    await pump(tester, const SAvatar(initials: '··'));
    // Los sitios de uso pasan '··' mientras carga el perfil.
    expect(find.text('··'), findsOneWidget);
  });

  testWidgets('iniciales largas no revientan el layout', (tester) async {
    await pump(tester, const SAvatar(initials: 'EAB', size: 24));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SAvatar)), const Size(24, 24));
  });
}
