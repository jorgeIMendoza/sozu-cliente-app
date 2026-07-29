import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';
import 'package:sozu_cliente_app/ui/tokens/elevation.dart';
import 'package:sozu_cliente_app/ui/tokens/motion.dart';
import 'package:sozu_cliente_app/ui/tokens/radii.dart';
import 'package:sozu_cliente_app/ui/tokens/spacing.dart';
import 'package:sozu_cliente_app/ui/tokens/typography.dart';
import 'package:sozu_cliente_app/ui/theme/breakpoints.dart';
import 'package:sozu_cliente_app/ui/theme/density.dart';

/// Todos los tokens de diseño de SOZU, colgados del `ThemeData` como
/// `ThemeExtension`.
///
/// Es el equivalente Dart de las CSS custom properties de shadcn/ui: un solo
/// objeto del que desciende toda la apariencia, resuelto por
/// (brillo × densidad).
///
/// Acceso: `context.s`
///
/// ```dart
/// Container(
///   padding: EdgeInsets.all(context.s.space.md),
///   decoration: BoxDecoration(
///     color: context.s.color.surface,
///     borderRadius: context.s.radius.cardBorder,
///     border: Border.all(color: context.s.color.border),
///     boxShadow: context.s.shadow.md,
///   ),
///   child: Text('Hola', style: context.s.text.body),
/// )
/// ```
///
/// Nunca escribir `Color(0x…)`, `circular(16)` ni `fontSize: 14` en una
/// pantalla: si el valor que necesitas no está aquí, se agrega aquí.
@immutable
class SozuTheme extends ThemeExtension<SozuTheme> {
  /// Roles semánticos de color. La única fuente de color de la app.
  final SozuColorRoles color;

  /// Radios de borde.
  final SozuRadii radius;

  /// Escala de espaciado (base 4).
  final SozuSpacing space;

  /// Escala tipográfica.
  ///
  /// Se llama `text` y no `type` porque `ThemeExtension` ya declara
  /// `Object get type` y la usa como CLAVE del mapa de extensiones del
  /// `ThemeData`. Sobrescribirla compila sin error pero rompe
  /// `Theme.of(context).extension<SozuTheme>()`, que devolvería `null` para
  /// siempre: `context.s` caería al tema por defecto en toda la app sin dar un
  /// solo mensaje. No renombrar.
  final SozuTypeScale text;

  /// Escala de sombras.
  final SozuElevation shadow;

  /// Duraciones, curvas y factor de press.
  ///
  /// Se resuelve, no se elige en la pantalla: cuando el sistema pide reducir
  /// movimiento este campo trae [SozuMotion.reduced] y toda animación que lea
  /// `context.s.motion` se apaga sola, sin que cada widget tenga que
  /// preguntarlo.
  final SozuMotion motion;

  /// Densidad con la que se resolvió este tema. Expuesta para los pocos casos
  /// que necesitan saberlo (p. ej. decidir si un botón va a ancho completo).
  final SozuDensity density;

  const SozuTheme({
    required this.color,
    required this.radius,
    required this.space,
    required this.text,
    required this.shadow,
    required this.motion,
    required this.density,
  });

  /// Resuelve el set completo de tokens para un brillo y una densidad.
  ///
  /// [reduceMotion] va al final y con valor por defecto a propósito: es una
  /// preferencia del entorno, no una dimensión del diseño, y así las llamadas
  /// que solo piden brillo + densidad siguen compilando.
  factory SozuTheme.resolve({
    required Brightness brightness,
    required SozuDensity density,
    bool reduceMotion = false,
  }) {
    final compact = density.isCompact;
    return SozuTheme(
      color: SozuColorRoles.forBrightness(brightness),
      radius: compact ? SozuRadii.compact : SozuRadii.standard,
      space: compact ? SozuSpacing.compact : SozuSpacing.standard,
      text: compact ? SozuTypeScale.compact : SozuTypeScale.standard,
      shadow: SozuElevation.forBrightness(brightness),
      motion: reduceMotion ? SozuMotion.reduced : SozuMotion.full,
      density: density,
    );
  }

  static SozuTheme get light => SozuTheme.resolve(
    brightness: Brightness.light,
    density: SozuDensity.comfortable,
  );

  static SozuTheme get dark => SozuTheme.resolve(
    brightness: Brightness.dark,
    density: SozuDensity.comfortable,
  );

  /// Tokens vigentes.
  ///
  /// Si el `ThemeData` no trae la extensión (tests con `MaterialApp` pelón,
  /// widgets aislados en un `WidgetTester`), cae al set claro en vez de reventar:
  /// un token faltante nunca debe tirar la pantalla.
  static SozuTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<SozuTheme>() ??
        SozuTheme.resolve(
          brightness: theme.brightness,
          density: SozuDensity.comfortable,
        );
  }

  @override
  SozuTheme copyWith({
    SozuColorRoles? color,
    SozuRadii? radius,
    SozuSpacing? space,
    SozuTypeScale? text,
    SozuElevation? shadow,
    SozuMotion? motion,
    SozuDensity? density,
  }) => SozuTheme(
    color: color ?? this.color,
    radius: radius ?? this.radius,
    space: space ?? this.space,
    text: text ?? this.text,
    shadow: shadow ?? this.shadow,
    motion: motion ?? this.motion,
    density: density ?? this.density,
  );

  @override
  SozuTheme lerp(covariant SozuTheme? other, double t) {
    if (other == null) return this;
    return SozuTheme(
      color: SozuColorRoles.lerp(color, other.color, t),
      radius: SozuRadii.lerp(radius, other.radius, t),
      space: SozuSpacing.lerp(space, other.space, t),
      text: SozuTypeScale.lerp(text, other.text, t),
      shadow: SozuElevation.lerp(shadow, other.shadow, t),
      motion: SozuMotion.lerp(motion, other.motion, t),
      // La densidad es discreta: no tiene sentido interpolarla. Salta a mitad
      // de la transición.
      density: t < 0.5 ? density : other.density,
    );
  }
}

/// Atajo de acceso a los tokens.
///
/// `context.s.color.fgMuted` en vez de `SozuTheme.of(context).color.fgMuted`.
/// El nombre es corto a propósito: se escribe cientos de veces y un nombre largo
/// empuja a la gente a hardcodear el valor.
extension SozuThemeContextX on BuildContext {
  SozuTheme get s => SozuTheme.of(this);
}

/// Ajusta la densidad de los tokens según el ancho disponible.
///
/// El `ThemeData` se construye una vez y no sabe cuánto mide la ventana, así que
/// la densidad no puede resolverse ahí. Este widget se coloca una sola vez, en
/// el `builder` del `MaterialApp`, y reinyecta la extensión con la densidad
/// correcta para que `context.s` la traiga resuelta en toda la app.
///
/// Sin esto, `context.s` siempre devuelve `comfortable`.
class SozuAdaptiveTokens extends StatelessWidget {
  final Widget child;

  /// Fuerza una densidad concreta ignorando el ancho. Solo para golden tests.
  final SozuDensity? forceDensity;

  const SozuAdaptiveTokens({super.key, required this.child, this.forceDensity});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final density = forceDensity ?? SozuDensity.fromBreakpoint(context.bp);

    // Señal de "reducir movimiento" del sistema operativo: Reduce Motion en
    // iOS/macOS, "Quitar animaciones" en Android, `prefers-reduced-motion` en
    // web. No es una preferencia estética: a quien tiene un trastorno
    // vestibular (vértigo, migraña vestibular, mareo por movimiento) una
    // interfaz que se desliza y escala le produce náusea real. La persona ya
    // pidió que el sistema no se mueva; ignorarlo aquí es sobrescribir esa
    // petición.
    //
    // Se lee aquí y no en cada widget porque así se apaga una sola vez, en el
    // token, y ningún componente puede olvidarse de preguntar.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final tokens = SozuTheme.resolve(
      brightness: base.brightness,
      density: density,
      reduceMotion: reduceMotion,
    );

    // Si ya está resuelto con esta densidad Y este movimiento, no re-inyectar:
    // evita reconstruir el subárbol en cada rebuild del MaterialApp. El
    // movimiento entra en la comparación porque `disableAnimations` puede
    // cambiar en caliente (el usuario activa el ajuste con la app abierta) y sin
    // esto el tema se quedaría pegado en el valor con el que arrancó.
    final current = base.extension<SozuTheme>();
    if (current != null &&
        current.density == density &&
        current.motion == tokens.motion) {
      return child;
    }

    // Se preservan las demás extensiones (hoy no hay ninguna, pero copyWith
    // reemplaza el mapa completo: sin esto, agregar una en el futuro la borraría
    // en silencio al pasar por aquí).
    final extensions =
        base.extensions.values.where((e) => e is! SozuTheme).toList()
          ..add(tokens);

    return Theme(
      data: base.copyWith(
        extensions: extensions,
        // La escala tipográfica también cambia con la densidad, así que el
        // TextTheme de Material tiene que seguirla o los widgets del framework
        // (AppBar, ListTile) se desincronizan de los nuestros.
        textTheme: sozuTextThemeFrom(tokens),
      ),
      child: child,
    );
  }
}

/// Construye el `TextTheme` de Material a partir de los tokens resueltos.
TextTheme sozuTextThemeFrom(SozuTheme t) {
  final c = t.color;
  final ty = t.text;
  return TextTheme(
    displayLarge: ty.display.copyWith(color: c.fg),
    displayMedium: ty.h1.copyWith(fontSize: ty.h1.fontSize! * 1.2, color: c.fg),
    displaySmall: ty.h1.copyWith(color: c.fg),
    headlineLarge: ty.h1.copyWith(color: c.fg),
    headlineMedium: ty.h2.copyWith(
      fontSize: ty.h2.fontSize! * 1.14,
      color: c.fg,
    ),
    headlineSmall: ty.h2.copyWith(color: c.fg),
    titleLarge: ty.h3.copyWith(color: c.fg),
    titleMedium: ty.label.copyWith(color: c.fg),
    titleSmall: ty.bodySmall.copyWith(fontWeight: FontWeight.w600, color: c.fg),
    bodyLarge: ty.bodyLarge.copyWith(color: c.fg),
    bodyMedium: ty.body.copyWith(color: c.fg),
    bodySmall: ty.bodySmall.copyWith(color: c.fgMuted),
    labelLarge: ty.button.copyWith(color: c.fg),
    labelMedium: ty.overline.copyWith(color: c.fgMuted),
    labelSmall: ty.caption.copyWith(color: c.fgMuted),
  );
}
