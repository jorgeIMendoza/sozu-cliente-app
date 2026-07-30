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
/// `ThemeExtension`: un solo objeto del que desciende toda la apariencia,
/// resuelto por (brillo × densidad). Acceso: `context.s`.
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
/// pantalla: si el valor no está aquí, se agrega aquí.
@immutable
class SozuTheme extends ThemeExtension<SozuTheme> {
  /// Roles semánticos de color. La única fuente de color de la app.
  final SozuColorRoles color;

  /// Radios de borde.
  final SozuRadii radius;

  /// Escala de espaciado (base 4).
  final SozuSpacing space;

  /// Escala tipográfica. Se llama `text` y NO `type` porque
  /// `ThemeExtension.type` es la CLAVE del mapa de extensiones de Material:
  /// pisarla deja `extension<SozuTheme>()` en `null` para siempre, sin error.
  /// No renombrar.
  final SozuTypeScale text;

  /// Escala de sombras.
  final SozuElevation shadow;

  /// Duraciones, curvas y factor de press. Trae [SozuMotion.reduced] cuando el
  /// sistema pide reducir movimiento, así que las animaciones que lean
  /// `context.s.motion` se apagan solas.
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

  /// Tokens vigentes. Si el `ThemeData` no trae la extensión (tests con
  /// `MaterialApp` pelón) cae al set del brillo actual en vez de reventar.
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
      // La densidad es discreta: salta a mitad de la transición.
      density: t < 0.5 ? density : other.density,
    );
  }
}

/// Atajo de acceso a los tokens: `context.s.color.fgMuted` en vez de
/// `SozuTheme.of(context).color.fgMuted`.
///
/// OJO: `context.s` NO puede ir dentro de una expresión `const` (leer un campo
/// de un objeto const no es constante en Dart).
extension SozuThemeContextX on BuildContext {
  SozuTheme get s => SozuTheme.of(this);
}

/// Ajusta la densidad de los tokens según el ancho disponible.
///
/// Se coloca una sola vez en el `builder` del `MaterialApp` y reinyecta la
/// extensión ya resuelta. Sin esto `context.s` siempre devuelve `comfortable`.
class SozuAdaptiveTokens extends StatelessWidget {
  final Widget child;

  /// Fuerza una densidad concreta ignorando el ancho. Solo para golden tests.
  final SozuDensity? forceDensity;

  const SozuAdaptiveTokens({super.key, required this.child, this.forceDensity});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final density = forceDensity ?? SozuDensity.fromBreakpoint(context.bp);

    // Señal de "reducir movimiento" del SO (Reduce Motion, "Quitar
    // animaciones", `prefers-reduced-motion`). Se lee aquí y no en cada widget
    // para que se apague una sola vez, en el token.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final tokens = SozuTheme.resolve(
      brightness: base.brightness,
      density: density,
      reduceMotion: reduceMotion,
    );

    // Si ya está resuelto con esta densidad Y este movimiento, no re-inyectar.
    // El movimiento entra en la comparación porque `disableAnimations` puede
    // cambiar en caliente y el tema se quedaría pegado.
    final current = base.extension<SozuTheme>();
    if (current != null &&
        current.density == density &&
        current.motion == tokens.motion) {
      return child;
    }

    // Se preservan las demás extensiones: `copyWith` reemplaza el mapa completo
    // y sin esto se borrarían en silencio.
    final extensions =
        base.extensions.values.where((e) => e is! SozuTheme).toList()
          ..add(tokens);

    return Theme(
      data: base.copyWith(
        extensions: extensions,
        // El TextTheme de Material tiene que seguir la densidad o los widgets
        // del framework (AppBar, ListTile) se desincronizan de los nuestros.
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
