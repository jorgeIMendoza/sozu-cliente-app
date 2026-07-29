import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Contrato del design system. Estos tests existen para que el barrido de
/// tokens (fases 2-3 del ADR 0001) no se haga a ciegas sobre 44k LOC.
void main() {
  group('SozuTheme como ThemeExtension', () {
    testWidgets('se resuelve desde el ThemeData', (tester) async {
      SozuTheme? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: sozuLightTheme(),
          home: Builder(
            builder: (context) {
              captured = context.s;
              return const SizedBox();
            },
          ),
        ),
      );

      // Si esto falla, `extension<SozuTheme>()` devolvió null y toda la app
      // estaría corriendo con el tema por defecto en silencio. Es exactamente lo
      // que pasaba cuando el campo se llamaba `type` y pisaba
      // `ThemeExtension.type`, que Material usa como clave del mapa.
      expect(captured, isNotNull);
      expect(captured!.color.primary, SozuBrand.green);
      expect(captured!.color, same(SozuColorRoles.light));
    });

    testWidgets('la clave del mapa de extensiones es el Type', (tester) async {
      final theme = sozuLightTheme();
      expect(theme.extension<SozuTheme>(), isNotNull);
      expect(theme.extensions.containsKey(SozuTheme), isTrue);
    });

    testWidgets('el tema oscuro resuelve los roles oscuros', (tester) async {
      SozuTheme? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: sozuLightTheme(),
          darkTheme: sozuDarkTheme(),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              captured = context.s;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(captured!.color, same(SozuColorRoles.dark));
    });

    testWidgets('sin extensión cae al set claro en vez de reventar', (
      tester,
    ) async {
      SozuTheme? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context.s;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(captured, isNotNull);
      expect(captured!.color, same(SozuColorRoles.light));
    });
  });

  group('SozuAdaptiveTokens resuelve la densidad por ancho', () {
    Future<SozuTheme> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SozuTheme? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: Builder(
            builder: (context) {
              captured = context.s;
              return const SizedBox();
            },
          ),
        ),
      );
      return captured!;
    }

    testWidgets('360 px → compact', (tester) async {
      final t = await pumpAt(tester, const Size(360, 800));
      expect(t.density, SozuDensity.compact);
      expect(t.text.h1.fontSize, lessThan(SozuType.h1.fontSize!));
    });

    testWidgets('1440 px → comfortable', (tester) async {
      final t = await pumpAt(tester, const Size(1440, 900));
      expect(t.density, SozuDensity.comfortable);
      expect(t.text.h1.fontSize, SozuType.h1.fontSize);
    });

    testWidgets('768 px (tablet) → comfortable', (tester) async {
      final t = await pumpAt(tester, const Size(768, 1024));
      expect(t.density, SozuDensity.comfortable);
    });
  });

  group('Breakpoints', () {
    test('fronteras exactas', () {
      expect(SozuBreakpoint.fromWidth(767), SozuBreakpoint.mobile);
      expect(SozuBreakpoint.fromWidth(768), SozuBreakpoint.tablet);
      expect(SozuBreakpoint.fromWidth(1023), SozuBreakpoint.tablet);
      expect(SozuBreakpoint.fromWidth(1024), SozuBreakpoint.desktop);
    });

    test('hasSidebar solo en desktop', () {
      expect(SozuBreakpoint.mobile.hasSidebar, isFalse);
      expect(SozuBreakpoint.tablet.hasSidebar, isFalse);
      expect(SozuBreakpoint.desktop.hasSidebar, isTrue);
    });

    testWidgets('responsive cae hacia abajo cuando falta un valor', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600); // tablet
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      int? cols;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // tablet no está definido → debe caer a mobile.
              cols = context.responsive(mobile: 1, desktop: 3);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(cols, 1);
    });
  });

  group('PortalColors (unico legacy vivo) apunta a la rampa unificada', () {
    // SozuTone y SozuColors fueron ELIMINADOS: no hay capa de alias. Lo que
    // sigue vivo es PortalColors, porque sus ~137 usos dentro de expresiones
    // `const` no se pueden migrar sin quitar el `const` caso por caso.
    //
    // Mientras exista, estos tests garantizan que NO sea una paleta paralela:
    // cada constante tiene que resolver al mismo valor que su rol semantico.
    test('las bases coinciden con los roles claros', () {
      const c = SozuColorRoles.light;
      expect(PortalColors.primary, c.primary);
      expect(PortalColors.primaryHover, c.primaryHover);
      expect(PortalColors.mutedForeground, c.fgMuted);
      expect(PortalColors.foreground, c.fg);
      expect(PortalColors.border, c.border);
      expect(PortalColors.borderSoft, c.borderSoft);
      expect(PortalColors.destructive, c.danger);
      expect(PortalColors.muted, c.muted);
      expect(PortalColors.textMuted, c.fgSubtle);
      expect(PortalColors.background, c.background);
      expect(PortalColors.surface, c.surface);
      expect(PortalColors.warning, c.warning);
    });

    test('la escalera de tintes quedo colapsada a dos niveles', () {
      expect(PortalColors.primarySoft5, PortalColors.primarySoft6);
      expect(PortalColors.primarySoft10, PortalColors.primarySoft15);
      expect(PortalColors.mutedSoft20, PortalColors.mutedSoft30);
    });

    test('kPortalFontFallback quedo sin efecto', () {
      // 19 llamadas lo siguen pasando; una lista vacia no altera el render.
      expect(kPortalFontFallback, isEmpty);
    });

    test('las medidas de layout reenvian a los breakpoints nuevos', () {
      expect(kPortalBreakpoint, kSozuDesktopMin);
      expect(kTwoColBreakpoint, kSozuTabletMin);
      expect(kPortalSidebarWidth, kSozuSidebarWidth);
      expect(kPortalTopBarHeight, kSozuTopBarHeight);
    });
  });

  group('Invariantes de la paleta', () {
    test('todo rol claro tiene contraparte oscura distinta de fondo', () {
      const l = SozuColorRoles.light;
      const d = SozuColorRoles.dark;
      // El texto principal debe contrastar con su superficie en ambos temas.
      expect(l.fg, isNot(l.surface));
      expect(d.fg, isNot(d.surface));
      // Y el tema oscuro debe realmente invertir: fondo oscuro, texto claro.
      expect(d.surface.computeLuminance(), lessThan(0.2));
      expect(d.fg.computeLuminance(), greaterThan(0.7));
    });

    test('warningFg contrasta mejor que warning sobre fondo claro', () {
      const c = SozuColorRoles.light;
      // Es la razón de existir del rol: #F59E0B no alcanza AA como texto.
      expect(
        c.warningFg.computeLuminance(),
        lessThan(c.warning.computeLuminance()),
      );
    });

    test('lerp de roles no revienta en los extremos', () {
      final mid = SozuColorRoles.lerp(
        SozuColorRoles.light,
        SozuColorRoles.dark,
        0.5,
      );
      expect(mid.fg, isNotNull);
      expect(
        SozuColorRoles.lerp(SozuColorRoles.light, SozuColorRoles.dark, 0).fg,
        SozuColorRoles.light.fg,
      );
      expect(
        SozuColorRoles.lerp(SozuColorRoles.light, SozuColorRoles.dark, 1).fg,
        SozuColorRoles.dark.fg,
      );
    });

    test('la densidad compacta solo encoge títulos, no texto corrido', () {
      expect(
        SozuTypeScale.compact.h1.fontSize,
        lessThan(SozuTypeScale.standard.h1.fontSize!),
      );
      expect(
        SozuTypeScale.compact.body.fontSize,
        SozuTypeScale.standard.body.fontSize,
      );
      expect(
        SozuTypeScale.compact.caption.fontSize,
        SozuTypeScale.standard.caption.fontSize,
      );
    });
  });
}
