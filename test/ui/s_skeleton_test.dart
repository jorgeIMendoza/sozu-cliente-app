import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/primitives/s_skeleton.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';
import 'package:sozu_cliente_app/ui/tokens/radii.dart';
import 'package:sozu_cliente_app/widgets/common.dart' show Skeleton;
import 'package:sozu_cliente_app/widgets/portal_widgets.dart'
    show PortalSkeletonBox;

/// Contrato de [SSkeleton].
///
/// Los tests que de verdad importan son dos: que los colores salgan de los roles
/// `skeletonBase`/`skeletonHighlight` (si un día alguien vuelve a hardcodear un
/// gris, el tema oscuro se rompe en silencio) y que con "reducir movimiento" NO
/// haya animación (se rompe sin que nadie lo note, hasta que marea a alguien).
///
/// El resto asegura que la delegación de los dos widgets legacy no cambió las
/// medidas de los 81 sitios de uso que todavía los nombran.

/// Tema compartido por todos los tests, creado UNA vez.
///
/// No es una optimización: `SozuTheme` no implementa `==`, así que dos
/// `ThemeData` con extensiones equivalentes se comparan por identidad y el
/// `AnimatedTheme` interno de `MaterialApp` arranca una transición de 200 ms cada
/// vez que se vuelve a montar con un tema nuevo. Esa transición contaba como
/// animación corriendo y tapaba lo que estos tests miden.
final ThemeData _theme = sozuLightTheme();

/// Monta [child] con los tokens resueltos, dentro de un ancho acotado de 200 px.
///
/// Por defecto la restricción es LOOSE (0..200): con un `SizedBox` pegado al
/// skeleton la restricción es tight y un bloque de 40 px reportaría 200, así que
/// las medidas dejarían de significar algo. Con [tight] se pega, que es lo que
/// necesita un bloque de renglones sin ancho propio para poder estirarse.
Future<void> pump(
  WidgetTester tester,
  Widget child, {
  bool disableAnimations = false,
  double width = 200,
  bool tight = false,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(1440, 900),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp(
        theme: _theme,
        builder: (context, c) =>
            SozuAdaptiveTokens(child: c ?? const SizedBox()),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: tight
                  ? child
                  : Align(alignment: Alignment.topLeft, child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Los bloques pintados que hay dentro del skeleton, en orden de arriba a abajo.
Finder blocks() => find.descendant(
  of: find.byType(SSkeleton),
  matching: find.byType(Container),
);

BoxDecoration decorationAt(WidgetTester tester, [int index = 0]) =>
    tester.widget<Container>(blocks().at(index)).decoration as BoxDecoration;

/// Matriz de traslación del gradiente para un bloque de 100 px de ancho. Es el
/// único observable de "en qué punto del barrido va el shimmer".
Matrix4 shimmerAt(WidgetTester tester) {
  final gradient = decorationAt(tester).gradient!;
  return gradient.transform!.transform(const Rect.fromLTWH(0, 0, 100, 20))!;
}

void main() {
  const light = SozuColorRoles.light;

  group('colores', () {
    testWidgets('el shimmer usa los roles skeletonBase y skeletonHighlight', (
      tester,
    ) async {
      await pump(tester, const SSkeleton(width: 120, height: 100));

      final gradient = decorationAt(tester).gradient! as LinearGradient;
      // base → highlight → base: el brillo va en medio para que entre y salga
      // del bloque sin cortes.
      expect(gradient.colors, <Color>[
        light.skeletonBase,
        light.skeletonHighlight,
        light.skeletonBase,
      ]);
      // Con gradiente no debe haber además un color de relleno: sería un color
      // crudo pintado debajo.
      expect(decorationAt(tester).color, isNull);
    });

    testWidgets('los colores NO son los grises crudos que usaba el legacy', (
      tester,
    ) async {
      await pump(tester, const SSkeleton(width: 120));

      final gradient = decorationAt(tester).gradient! as LinearGradient;
      // El viejo `Skeleton` barría n200 → n100 y el viejo `PortalSkeletonBox`
      // pintaba `PortalColors.muted`. Si alguno reaparece aquí, la delegación se
      // deshizo.
      expect(gradient.colors.first, light.skeletonBase);
      expect(gradient.colors[1], light.skeletonHighlight);
    });
  });

  group('reducir movimiento', () {
    testWidgets('disableAnimations: true no anima y pinta skeletonBase plano', (
      tester,
    ) async {
      await pump(
        tester,
        const SSkeleton(width: 120, height: 100),
        disableAnimations: true,
      );

      final d = decorationAt(tester);
      // Plano y en el extremo OSCURO del gradiente: el highlight dejaría un
      // bloque casi blanco, invisible sobre la card.
      expect(d.gradient, isNull);
      expect(d.color, light.skeletonBase);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('con movimiento reducido el widget no cambia entre frames', (
      tester,
    ) async {
      await pump(
        tester,
        const SSkeleton(width: 120, height: 100),
        disableAnimations: true,
      );

      final antes = decorationAt(tester);
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 650));

      expect(decorationAt(tester), antes);
    });

    testWidgets('sin movimiento reducido SÍ cambia entre frames', (
      tester,
    ) async {
      await pump(tester, const SSkeleton(width: 120, height: 100));

      expect(tester.hasRunningAnimations, isTrue);
      final antes = shimmerAt(tester);
      // Un tercio del ciclo: suficiente para que el barrido se haya movido de
      // forma inequívoca.
      await tester.pump(const Duration(milliseconds: 430));

      expect(shimmerAt(tester), isNot(antes));
    });
  });

  group('SSkeleton.text', () {
    testWidgets('lines: 3 renderiza 3 bloques y el último es más angosto', (
      tester,
    ) async {
      await pump(tester, const SSkeleton.text(width: 200));

      expect(blocks(), findsNWidgets(3));
      final primero = tester.getSize(blocks().at(0));
      final ultimo = tester.getSize(blocks().at(2));

      expect(primero.width, 200);
      // 60% del ancho: un párrafo real no termina justo en el borde.
      expect(ultimo.width, closeTo(120, 0.01));
      expect(ultimo.width, lessThan(primero.width));
    });

    testWidgets('lastLineFactor manda sobre el ancho del último renglón', (
      tester,
    ) async {
      await pump(
        tester,
        const SSkeleton.text(lines: 2, lastLineFactor: 0.25, width: 200),
      );

      expect(tester.getSize(blocks().at(1)).width, closeTo(50, 0.01));
    });

    testWidgets('lines: 1 no mete separación sobrante', (tester) async {
      // Sin ancho propio y con restricción tight: los renglones se estiran al
      // ancho del padre, que es el caso de un skeleton dentro de una card.
      await pump(tester, const SSkeleton.text(lines: 1), tight: true);

      expect(blocks(), findsOneWidget);
      expect(tester.getSize(blocks().first).width, 200);
      // Exactamente el alto de un renglón: ni un pixel de hueco que
      // desalinearía el bloque respecto a lo que va debajo.
      expect(
        tester.getSize(find.byType(SSkeleton)).height,
        SSkeleton.defaultHeight,
      );
      // Y ningún separador construido "por si acaso".
      expect(
        find.descendant(
          of: find.byType(SSkeleton),
          matching: find.byType(SizedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('el alto total son los renglones más las separaciones', (
      tester,
    ) async {
      await pump(tester, const SSkeleton.text(), tight: true);

      // 3 renglones de 16 + 2 separaciones de space.xs (8) = 64.
      expect(tester.getSize(find.byType(SSkeleton)).height, 64);
    });

    testWidgets('un solo shimmer para todos los renglones: van en fase', (
      tester,
    ) async {
      await pump(tester, const SSkeleton.text(width: 200));

      final primero = decorationAt(
        tester,
        0,
      ).gradient!.transform!.transform(const Rect.fromLTWH(0, 0, 100, 20));
      final segundo = decorationAt(
        tester,
        1,
      ).gradient!.transform!.transform(const Rect.fromLTWH(0, 0, 100, 20));
      expect(primero, segundo);
    });
  });

  group('SSkeleton.circle', () {
    testWidgets('mide size x size y es redondo', (tester) async {
      await pump(tester, const SSkeleton.circle(size: 40));

      expect(tester.getSize(find.byType(SSkeleton)), const Size(40, 40));
      final d = decorationAt(tester);
      expect(d.shape, BoxShape.circle);
      // Un círculo no lleva borderRadius: los dos juntos revientan en tiempo de
      // ejecución.
      expect(d.borderRadius, isNull);
    });
  });

  group('formas y radio', () {
    testWidgets('box sin radio explícito usa el radio md del token', (
      tester,
    ) async {
      await pump(tester, const SSkeleton(width: 100));

      // Del token, no de un literal: si `md` cambia, el skeleton lo sigue.
      expect(
        decorationAt(tester).borderRadius,
        BorderRadius.circular(SozuRadii.standard.md),
      );
    });

    testWidgets('un renglón de texto usa el radio sm (no parece un chip)', (
      tester,
    ) async {
      await pump(tester, const SSkeleton.text(lines: 1), tight: true);

      expect(
        decorationAt(tester).borderRadius,
        BorderRadius.circular(SozuRadii.standard.sm),
      );
    });

    testWidgets('el radio explícito manda', (tester) async {
      await pump(tester, const SSkeleton(width: 120, height: 100, radius: 12));

      expect(decorationAt(tester).borderRadius, BorderRadius.circular(12));
    });
  });

  group('delegación de los widgets legacy', () {
    testWidgets('Skeleton(width: 200, height: 14) sigue midiendo 200x14', (
      tester,
    ) async {
      await pump(tester, const Skeleton(width: 200, height: 14));

      // La garantía de que los sitios de uso no se movieron un pixel.
      expect(tester.getSize(find.byType(Skeleton)), const Size(200, 14));
      expect(find.byType(SSkeleton), findsOneWidget);
    });

    testWidgets('Skeleton respeta su radio por defecto de 8', (tester) async {
      await pump(tester, const Skeleton(width: 200, height: 14));

      // Aquí el 8 SÍ es un literal a propósito: es el default de la API vieja y
      // el contrato es que no se mueva ni un pixel en los sitios de uso.
      expect(decorationAt(tester).borderRadius, BorderRadius.circular(8));
    });

    testWidgets('PortalSkeletonBox conserva medidas y forma', (tester) async {
      await pump(
        tester,
        const PortalSkeletonBox(width: 120, height: 100, radius: 12),
      );

      expect(
        tester.getSize(find.byType(PortalSkeletonBox)),
        const Size(120, 100),
      );
      expect(decorationAt(tester).borderRadius, BorderRadius.circular(12));
    });

    testWidgets('PortalSkeletonBox(circle: true) delega en la forma círculo', (
      tester,
    ) async {
      await pump(
        tester,
        const PortalSkeletonBox(width: 36, height: 36, circle: true),
      );

      expect(decorationAt(tester).shape, BoxShape.circle);
      expect(
        tester.getSize(find.byType(PortalSkeletonBox)),
        const Size(36, 36),
      );
    });

    testWidgets('los dos legacy ahora comparten el mismo shimmer', (
      tester,
    ) async {
      await pump(
        tester,
        const Column(
          children: [
            Skeleton(width: 100, height: 20),
            PortalSkeletonBox(width: 100, height: 20),
          ],
        ),
      );

      // El punto de todo el ejercicio: móvil y portal cargan igual: mismos
      // colores, mismos stops y el mismo punto del barrido.
      expect(
        decorationAt(tester, 0).gradient,
        decorationAt(tester, 1).gradient,
      );
    });
  });

  group('ciclo de vida', () {
    testWidgets('reemplazar el árbol no fuga el AnimationController', (
      tester,
    ) async {
      await pump(tester, const SSkeleton.text(width: 200));
      await tester.pump(const Duration(milliseconds: 400));

      // Si el controller no se libera en dispose, el ticker sigue vivo y el
      // binding lo denuncia al terminar el test.
      await pump(tester, const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('apagar el movimiento en caliente detiene el ticker', (
      tester,
    ) async {
      await pump(tester, const SSkeleton(width: 120, height: 100));
      expect(tester.hasRunningAnimations, isTrue);

      // El usuario activa "reducir movimiento" con la app abierta: los tokens
      // cambian y el widget tiene que apagarse, no quedarse animando con el
      // valor con el que arrancó.
      await pump(
        tester,
        const SSkeleton(width: 120, height: 100),
        disableAnimations: true,
      );

      // `pumpAndSettle` es la prueba: solo devuelve cuando no queda ninguna
      // animación corriendo. Si el shimmer siguiera repitiéndose, este await no
      // terminaría nunca. (Hace falta dejar correr el tiempo porque reinyectar
      // los tokens dispara además las animaciones implícitas de Material.)
      await tester.pumpAndSettle();

      expect(tester.hasRunningAnimations, isFalse);
      expect(decorationAt(tester).gradient, isNull);
    });
  });
}
