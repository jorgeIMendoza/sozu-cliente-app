import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/theme/density.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';
import 'package:sozu_cliente_app/ui/tokens/motion.dart';

/// Contrato de los tokens de movimiento.
///
/// El test que de verdad importa es el último: que la señal de "reducir
/// movimiento" del sistema llegue hasta `context.s.motion`. Es un requisito de
/// accesibilidad y se rompe en silencio (nadie nota que la app sigue animando
/// hasta que marea a alguien).
void main() {
  group('SozuMotion.full', () {
    test('las cuatro duraciones son estrictamente crecientes', () {
      const m = SozuMotion.full;
      expect(m.instant, lessThan(m.fast));
      expect(m.fast, lessThan(m.normal));
      expect(m.normal, lessThan(m.slow));
    });

    test('todas caen en el rango perceptible (90-400 ms)', () {
      const m = SozuMotion.full;
      // Por debajo de ~90 ms el ojo no percibe transición; por encima de
      // ~400 ms se siente lento. Un valor fuera de esta ventana no es un
      // ajuste, es un error.
      for (final d in <Duration>[m.instant, m.fast, m.normal, m.slow]) {
        expect(d.inMilliseconds, greaterThanOrEqualTo(90));
        expect(d.inMilliseconds, lessThanOrEqualTo(400));
      }
    });

    test('el press hunde poco: perceptible pero no exagerado', () {
      expect(SozuMotion.full.pressScale, lessThan(1.0));
      expect(SozuMotion.full.pressScale, greaterThan(0.95));
    });
  });

  group('SozuMotion.reduced', () {
    test('TODAS las duraciones son cero', () {
      const m = SozuMotion.reduced;
      expect(m.instant, Duration.zero);
      expect(m.fast, Duration.zero);
      expect(m.normal, Duration.zero);
      expect(m.slow, Duration.zero);
    });

    test('el press no escala', () {
      // Media reducción sigue siendo movimiento. Debe ser exactamente 1.0.
      expect(SozuMotion.reduced.pressScale, 1.0);
    });

    test('las curvas son lineales', () {
      const m = SozuMotion.reduced;
      expect(m.standard, Curves.linear);
      expect(m.emphasized, Curves.linear);
      expect(m.enter, Curves.linear);
      expect(m.exit, Curves.linear);
    });

    test('es distinta de full', () {
      expect(SozuMotion.reduced, isNot(SozuMotion.full));
    });
  });

  group('SozuMotion.lerp', () {
    test('respeta los extremos', () {
      expect(
        SozuMotion.lerp(SozuMotion.full, SozuMotion.reduced, 0.0),
        SozuMotion.full,
      );
      expect(
        SozuMotion.lerp(SozuMotion.full, SozuMotion.reduced, 1.0),
        SozuMotion.reduced,
      );
    });

    test('interpola duraciones y pressScale a la mitad', () {
      final mid = SozuMotion.lerp(SozuMotion.full, SozuMotion.reduced, 0.5);
      expect(mid.normal.inMilliseconds, 120); // 240 → 0
      expect(mid.slow.inMilliseconds, 190); // 380 → 0
      expect(mid.pressScale, closeTo(0.9875, 0.0001)); // 0.975 → 1.0
    });

    test('interpola en microsegundos, no en milisegundos', () {
      // 90 ms al 10% son 81 ms exactos. Si se interpolara redondeando a
      // milisegundo en cada paso, los valores chicos derivarían.
      final t = SozuMotion.lerp(SozuMotion.full, SozuMotion.reduced, 0.1);
      expect(t.instant.inMicroseconds, 81000);
    });

    test('las curvas son discretas: saltan en t = 0.5', () {
      final antes = SozuMotion.lerp(SozuMotion.full, SozuMotion.reduced, 0.49);
      final despues = SozuMotion.lerp(SozuMotion.full, SozuMotion.reduced, 0.5);
      expect(antes.standard, SozuMotion.full.standard);
      expect(despues.standard, SozuMotion.reduced.standard);
    });
  });

  group('SozuTheme.resolve', () {
    test('por defecto trae la escala completa', () {
      final t = SozuTheme.resolve(
        brightness: Brightness.light,
        density: SozuDensity.comfortable,
      );
      expect(t.motion, SozuMotion.full);
    });

    test('reduceMotion: true trae la escala anulada', () {
      final t = SozuTheme.resolve(
        brightness: Brightness.light,
        density: SozuDensity.compact,
        reduceMotion: true,
      );
      expect(t.motion, SozuMotion.reduced);
    });

    test('los getters light/dark siguen dando movimiento completo', () {
      expect(SozuTheme.light.motion, SozuMotion.full);
      expect(SozuTheme.dark.motion, SozuMotion.full);
    });

    test('lerp del tema completo no revienta con el movimiento adentro', () {
      final a = SozuTheme.light;
      final b = SozuTheme.resolve(
        brightness: Brightness.dark,
        density: SozuDensity.compact,
        reduceMotion: true,
      );
      expect(a.lerp(b, 0.0).motion, SozuMotion.full);
      expect(a.lerp(b, 1.0).motion, SozuMotion.reduced);
      expect(a.lerp(b, 0.5).motion.normal.inMilliseconds, 120);
    });

    test('copyWith reemplaza solo el movimiento', () {
      final t = SozuTheme.light.copyWith(motion: SozuMotion.reduced);
      expect(t.motion, SozuMotion.reduced);
      expect(t.color, SozuTheme.light.color);
      expect(t.density, SozuTheme.light.density);
    });
  });

  group('SozuAdaptiveTokens lee disableAnimations del sistema', () {
    Future<SozuMotion> pumpWith(
      WidgetTester tester, {
      required bool disableAnimations,
    }) async {
      SozuMotion? captured;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(1440, 900),
            disableAnimations: disableAnimations,
          ),
          child: MaterialApp(
            theme: sozuLightTheme(),
            builder: (context, child) =>
                SozuAdaptiveTokens(child: child ?? const SizedBox()),
            home: Builder(
              builder: (context) {
                captured = context.s.motion;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return captured!;
    }

    testWidgets('disableAnimations: true → SozuMotion.reduced', (tester) async {
      expect(
        await pumpWith(tester, disableAnimations: true),
        SozuMotion.reduced,
      );
    });

    testWidgets('disableAnimations: false → SozuMotion.full', (tester) async {
      expect(await pumpWith(tester, disableAnimations: false), SozuMotion.full);
    });
  });
}
