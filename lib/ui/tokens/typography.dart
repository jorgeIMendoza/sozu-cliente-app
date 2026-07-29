import 'package:flutter/material.dart';

/// Sistema tipográfico de SOZU — **fuente de verdad única** de tamaños, pesos e
/// interlineados de toda la plataforma (web, Android e iOS).
///
/// Dos familias con papeles distintos:
///
/// * **Poppins** (geométrica redondeada) en títulos y botones. Es donde se ve el
///   carácter de la marca y donde el tamaño grande la favorece.
/// * **Inter** (tipografía de interfaz) en texto corrido, etiquetas de campo y
///   texto chico. A 12-13 px es sensiblemente más legible que Poppins, que se
///   ensancha y pierde definición.
///
/// **Regla de uso:** no escribir `TextStyle(fontSize: …)` suelto en las
/// pantallas. Usar un token de [SozuType], o `Theme.of(context).textTheme.*`
/// (los roles de Material están mapeados en [sozuTextTheme]). Si hace falta un
/// tamaño que no existe, se agrega aquí — no en la pantalla.
///
/// **Sobre `fontFamilyFallback`:** no usarlo para pedir fuentes del sistema
/// (`-apple-system`, `Segoe UI`). En web, CanvasKit rasteriza el texto él mismo y
/// solo reconoce las familias declaradas en `pubspec.yaml`, así que un fallback a
/// fuentes del sistema es código muerto — y en móvil produce render distinto al
/// de web, que es exactamente lo que este archivo evita.
///
/// Escala (proporción ~1.25, redondeada a valores cómodos):
///
/// | Token       | Rol Material   | Fuente  | px | Peso | Uso                        |
/// |-------------|----------------|---------|----|------|----------------------------|
/// | `display`   | displayLarge   | Poppins | 44 | 800  | Hero del panel de marca    |
/// | `h1`        | headlineLarge  | Poppins | 30 | 700  | Título de pantalla         |
/// | `h2`        | headlineSmall  | Poppins | 22 | 600  | Título de sección          |
/// | `h3`        | titleLarge     | Poppins | 17 | 600  | Título de card / subsección|
/// | `bodyLarge` | bodyLarge      | Inter   | 16 | 400  | Texto destacado            |
/// | `bodyText`  | bodyMedium     | Inter   | 14 | 400  | Texto por defecto          |
/// | `bodySmall` | bodySmall      | Inter   | 13 | 400  | Texto secundario           |
/// | `label`     | labelLarge     | Inter   | 14 | 600  | Etiqueta de campo          |
/// | `button`    | —              | Poppins | 15 | 600  | Texto de botón             |
/// | `caption`   | labelSmall     | Inter   | 12 | 400  | Pies, ayudas, metadatos    |
/// | `overline`  | labelMedium    | Inter   | 11 | 600  | Chips, separadores         |
class SozuType {
  SozuType._();

  static const String heading = 'Poppins';
  static const String body = 'Inter';

  // --- Títulos (Poppins) ---------------------------------------------------
  // El tracking negativo crece con el tamaño: en display los espacios entre
  // letras se ven enormes si no se cierran.

  static const TextStyle display = TextStyle(
    fontFamily: heading,
    fontSize: 44,
    fontWeight: FontWeight.w800,
    height: 1.08,
    letterSpacing: -1.2,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: heading,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.6,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: heading,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.28,
    letterSpacing: -0.3,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: heading,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.1,
  );

  static const TextStyle button = TextStyle(
    fontFamily: heading,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
  );

  // --- Texto (Inter) -------------------------------------------------------

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: body,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  static const TextStyle bodyText = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: body,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle label = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: body,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: body,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.4,
  );

  /// Cifras tabulares: para columnas de montos y fechas que deben alinearse.
  /// Inter trae `tnum`, así que basta pedir la feature.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

/// Familia por defecto de todo lo que no pida un estilo explícito.
///
/// Inter es lo más cercano al `system-ui` del navegador —comparte métrica y aire
/// con Segoe UI / SF Pro / Roboto— pero al ir empaquetada se ve idéntica en las
/// tres plataformas.
const String kSozuFontFamily = SozuType.body;

/// Mapea [SozuType] a los roles de Material para que
/// `Theme.of(context).textTheme.headlineLarge` y los widgets del framework
/// (AppBar, ListTile, SnackBar, diálogos) hereden la misma escala sin que cada
/// pantalla la pida a mano.
///
/// [color] es el color de texto primario del tema: Material exige que los
/// estilos del TextTheme traigan color, o los widgets del framework caen a
/// negro sobre fondo oscuro.
TextTheme sozuTextTheme({required Color color, required Color colorSuave}) {
  return TextTheme(
    displayLarge: SozuType.display.copyWith(color: color),
    displayMedium: SozuType.h1.copyWith(fontSize: 36, color: color),
    displaySmall: SozuType.h1.copyWith(color: color),
    headlineLarge: SozuType.h1.copyWith(color: color),
    headlineMedium: SozuType.h2.copyWith(fontSize: 25, color: color),
    headlineSmall: SozuType.h2.copyWith(color: color),
    titleLarge: SozuType.h3.copyWith(color: color),
    titleMedium: SozuType.label.copyWith(color: color),
    titleSmall: SozuType.bodySmall.copyWith(
      fontWeight: FontWeight.w600,
      color: color,
    ),
    bodyLarge: SozuType.bodyLarge.copyWith(color: color),
    bodyMedium: SozuType.bodyText.copyWith(color: color),
    bodySmall: SozuType.bodySmall.copyWith(color: colorSuave),
    labelLarge: SozuType.button.copyWith(color: color),
    labelMedium: SozuType.overline.copyWith(color: colorSuave),
    labelSmall: SozuType.caption.copyWith(color: colorSuave),
  );
}

/// Escala tipográfica como token del tema, para que la densidad pueda ajustarla.
///
/// En escritorio los títulos pueden respirar; en un móvil de 360 px un `h1` de
/// 30 px parte las palabras. [compact] baja solo los títulos: el texto corrido
/// NO se escala (14 px es 14 px en todas partes, o se vuelve ilegible).
@immutable
class SozuTypeScale {
  final TextStyle display;
  final TextStyle h1;
  final TextStyle h2;
  final TextStyle h3;
  final TextStyle bodyLarge;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle label;
  final TextStyle button;
  final TextStyle caption;
  final TextStyle overline;

  const SozuTypeScale({
    required this.display,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.bodyLarge,
    required this.body,
    required this.bodySmall,
    required this.label,
    required this.button,
    required this.caption,
    required this.overline,
  });

  static const SozuTypeScale standard = SozuTypeScale(
    display: SozuType.display,
    h1: SozuType.h1,
    h2: SozuType.h2,
    h3: SozuType.h3,
    bodyLarge: SozuType.bodyLarge,
    body: SozuType.bodyText,
    bodySmall: SozuType.bodySmall,
    label: SozuType.label,
    button: SozuType.button,
    caption: SozuType.caption,
    overline: SozuType.overline,
  );

  /// Títulos un paso más chicos. Texto corrido intacto.
  static final SozuTypeScale compact = SozuTypeScale(
    display: SozuType.display.copyWith(fontSize: 34, letterSpacing: -0.9),
    h1: SozuType.h1.copyWith(fontSize: 25, letterSpacing: -0.5),
    h2: SozuType.h2.copyWith(fontSize: 19),
    h3: SozuType.h3.copyWith(fontSize: 16),
    bodyLarge: SozuType.bodyLarge,
    body: SozuType.bodyText,
    bodySmall: SozuType.bodySmall,
    label: SozuType.label,
    button: SozuType.button,
    caption: SozuType.caption,
    overline: SozuType.overline,
  );

  static SozuTypeScale lerp(SozuTypeScale a, SozuTypeScale b, double t) =>
      SozuTypeScale(
        display: TextStyle.lerp(a.display, b.display, t)!,
        h1: TextStyle.lerp(a.h1, b.h1, t)!,
        h2: TextStyle.lerp(a.h2, b.h2, t)!,
        h3: TextStyle.lerp(a.h3, b.h3, t)!,
        bodyLarge: TextStyle.lerp(a.bodyLarge, b.bodyLarge, t)!,
        body: TextStyle.lerp(a.body, b.body, t)!,
        bodySmall: TextStyle.lerp(a.bodySmall, b.bodySmall, t)!,
        label: TextStyle.lerp(a.label, b.label, t)!,
        button: TextStyle.lerp(a.button, b.button, t)!,
        caption: TextStyle.lerp(a.caption, b.caption, t)!,
        overline: TextStyle.lerp(a.overline, b.overline, t)!,
      );
}
