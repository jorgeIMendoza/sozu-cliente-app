// Genera, a partir del ícono SOZU (web/icons/Icon-512.png = cuadro negro con
// el pin blanco), el ícono de NOTIFICACIÓN:
//
//   android/app/src/main/res/drawable-*/ic_stat_sozu.png
//   Status bar de Android: silueta MONOCROMA blanca sobre transparente en cada
//   densidad (mdpi 24, hdpi 36, xhdpi 48, xxhdpi 72, xxxhdpi 96 px). Android
//   enmascara a blanco usando el alpha, por eso el fondo negro se vuelve
//   transparente y el pin blanco puro.
//
// Sigue siendo el PIN y no el wordmark de la app a propósito: a 24 px "sozu
// CLIENTES" es una mancha ilegible, y Android exige una silueta de un solo
// color.
//
// Este script YA NO genera assets/icon/ic_launcher_foreground.png. Ese archivo
// es el wordmark de marca y viene de `assets/icon/brand_source.png` (ver
// assets/icon/README.md); si esta herramienta lo siguiera escribiendo, correrla
// devolvería el ícono del launcher al pin y desharía la diferencia entre la app
// de clientes y la de agentes.
//
// No requiere ImageMagick: usa el paquete `image`. Correr con:
//   dart run tool/gen_icons.dart
import 'dart:io';

import 'package:image/image.dart' as img;

const _fuente = 'web/icons/Icon-512.png';

void main() {
  final bytes = File(_fuente).readAsBytesSync();
  final src = img.decodePng(bytes);
  if (src == null) {
    stderr.writeln('No se pudo decodificar $_fuente');
    exit(1);
  }

  // Máscara del pin a resolución alta: pixeles claros (el pin blanco) -> blanco
  // opaco; el resto (el cuadro negro) -> transparente. Umbral por luminancia.
  final mask = _siluetaBlanca(src);

  _generarNotificacion(mask);

  stdout.writeln('Íconos de notificación generados OK.');
}

/// Devuelve una copia del [src] convertida a "pin blanco sobre transparente".
img.Image _siluetaBlanca(img.Image src) {
  final rgba = src.convert(numChannels: 4);
  const umbral = 128; // 0..255 sobre la luminancia
  for (final p in rgba) {
    final lum = img.getLuminance(p);
    if (lum >= umbral) {
      p
        ..r = 255
        ..g = 255
        ..b = 255
        ..a = 255;
    } else {
      p
        ..r = 255
        ..g = 255
        ..b = 255
        ..a = 0; // transparente
    }
  }
  return rgba;
}

/// ic_stat_sozu en cada densidad de drawable.
void _generarNotificacion(img.Image mask) {
  const densidades = <String, int>{
    'drawable-mdpi': 24,
    'drawable-hdpi': 36,
    'drawable-xhdpi': 48,
    'drawable-xxhdpi': 72,
    'drawable-xxxhdpi': 96,
  };
  const base = 'android/app/src/main/res';
  densidades.forEach((carpeta, tam) {
    // Un poco de padding interno para que el pin no toque los bordes del ícono
    // de notificación (Android recomienda contenido dentro de ~90%).
    final contenido = (tam * 0.86).round();
    final pin = img.copyResize(
      mask,
      width: contenido,
      height: contenido,
      interpolation: img.Interpolation.cubic,
    );
    final lienzo = img.Image(width: tam, height: tam, numChannels: 4);
    img.fill(lienzo, color: img.ColorRgba8(0, 0, 0, 0));
    final offset = (tam - contenido) ~/ 2;
    img.compositeImage(lienzo, pin, dstX: offset, dstY: offset);

    final dir = Directory('$base/$carpeta');
    dir.createSync(recursive: true);
    final out = File('${dir.path}/ic_stat_sozu.png');
    out.writeAsBytesSync(img.encodePng(lienzo));
    stdout.writeln('  - ${out.path} (${tam}x$tam)');
  });
}
