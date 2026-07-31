import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// El logo es UN solo PNG recoloreado en runtime. Estos tests fijan las dos
/// cosas que lo hacen posible y que un cambio de asset rompería en silencio:
/// que el recoloreo use `srcIn`, y que cada variante pida el color correcto.
void main() {
  /// Monta el logo igual que la app real: `theme` + `darkTheme` + `themeMode`.
  /// Pasar un ThemeData oscuro por `theme` no ejercita el camino de producción.
  Future<Image> pumpLogo(
    WidgetTester tester,
    Widget logo, {
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        darkTheme: sozuDarkTheme(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(body: logo),
      ),
    );
    return tester.widget<Image>(find.byType(Image));
  }

  testWidgets('recolorea con srcIn (conserva el alfa de la silueta)', (
    tester,
  ) async {
    final img = await pumpLogo(tester, const SLogo());
    expect(img.colorBlendMode, BlendMode.srcIn);
  });

  // Ojo: cada caso monta su propio árbol. Cambiar `themeMode` sobre un árbol ya
  // montado NO sirve para aserciones inmediatas - MaterialApp interpola el tema
  // con AnimatedTheme, así que en t=0 `Theme.of` sigue devolviendo el anterior
  // (nuestro SozuTheme.lerp hace exactamente eso). Haría falta pumpAndSettle.

  testWidgets('en tema claro usa el fg claro', (tester) async {
    final img = await pumpLogo(tester, const SLogo());
    expect(img.color, SozuColorRoles.light.fg);
    expect(img.color!.computeLuminance(), lessThan(0.2));
  });

  testWidgets('en tema oscuro se aclara solo', (tester) async {
    // Esto es lo que arregla el bug latente de los 4 usos que pintaban el PNG
    // negro crudo: eran invisibles sobre superficie oscura.
    final img = await pumpLogo(tester, const SLogo(), dark: true);
    expect(img.color, SozuColorRoles.dark.fg);
    expect(img.color!.computeLuminance(), greaterThan(0.5));
  });

  testWidgets('onBrand es blanco aunque el tema sea claro', (tester) async {
    final img = await pumpLogo(tester, const SLogo.onBrand());
    expect(img.color, SozuNeutral.n0);
  });

  testWidgets('onLight es oscuro aunque el tema sea oscuro', (tester) async {
    final img = await pumpLogo(tester, const SLogo.onLight(), dark: true);
    // Las cards del portal son blancas por definición: el logo debe seguir
    // siendo oscuro ahí incluso con tema oscuro activo.
    expect(img.color, SozuNeutral.n900);
    expect(img.color!.computeLuminance(), lessThan(0.2));
  });

  testWidgets('se dimensiona por alto y no fija ancho', (tester) async {
    final img = await pumpLogo(tester, const SLogo(height: 34));
    expect(img.height, 34);
    // Fijar ancho y alto a la vez deformaría el wordmark.
    expect(img.width, isNull);
    expect(img.fit, BoxFit.contain);
  });

  test('la proporción declarada coincide con el asset real (1043x300)', () {
    expect(SLogo.aspectRatio, closeTo(3.4767, 0.001));
  });
}
